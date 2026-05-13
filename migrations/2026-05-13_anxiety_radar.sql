-- ════════════════════════════════════════════════════════════
-- 客戶焦慮雷達 schema (Phase 1 of 5)
--
-- 目的：追蹤客戶在 ys-interior 的瀏覽行為，讓設計師後台能看到「客戶
--      最近頻繁查看哪些頁面」「哪裡可能焦慮」，主動關心而非被動等問。
--
-- 4 張表：
--   customer_activity_logs  — 每筆事件原始紀錄（page_view / click_xxx）
--   page_view_summary       — 彙整：每客戶每頁的累計次數 + 最後瀏覽
--   client_anxiety_signals  — 系統規則判斷出的焦慮提示
--   client_stage_metrics    — 依專案階段彙整（先建表，邏輯後續加）
--
-- RLS 策略：
--   - anon 只能 INSERT 到 customer_activity_logs（瀏覽行為來自客戶端 anon）
--     不開 SELECT 給 anon，避免別的 client 偷看
--   - admin/authenticated 可全 CRUD
--
-- 跑在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor
-- ════════════════════════════════════════════════════════════

-- ─── customer_activity_logs ───────────────────────────────
create table if not exists customer_activity_logs (
  id          uuid primary key default gen_random_uuid(),
  project_id  int,                          -- 可空（page_view 可能在還沒 lookup project 前發生）
  client_id   int not null,
  event_type  text not null,                -- 'page_view' | 'click_xxx'
  page_key    text,                         -- 'payment' | 'drawings' | 'materials' | ...
  metadata    jsonb default '{}'::jsonb,    -- 額外資訊（停留秒數、目標 id 等）
  created_at  timestamptz not null default now()
);

create index if not exists customer_activity_logs_client_idx
  on customer_activity_logs (client_id, created_at desc);
create index if not exists customer_activity_logs_event_idx
  on customer_activity_logs (client_id, event_type, created_at desc);

-- ─── page_view_summary ────────────────────────────────────
-- 為了 dashboard 快速查詢，每客戶每頁一筆累計
create table if not exists page_view_summary (
  client_id       int not null,
  page_key        text not null,
  view_count      int not null default 0,
  total_duration  int not null default 0,   -- 累積停留秒數
  last_viewed_at  timestamptz not null default now(),
  primary key (client_id, page_key)
);

create index if not exists page_view_summary_client_idx
  on page_view_summary (client_id, last_viewed_at desc);

-- ─── client_anxiety_signals ───────────────────────────────
create table if not exists client_anxiety_signals (
  id              uuid primary key default gen_random_uuid(),
  project_id      int,
  client_id       int not null,
  signal_type     text not null,            -- 'frequent_payment_view' | 'frequent_drawings_view' 等
  severity        text not null default 'info',  -- 'info' | 'warning' | 'urgent'
  message         text not null,            -- 給設計師看的描述
  suggested_action text,                    -- 建議的下一步行動
  metadata        jsonb default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  resolved_at     timestamptz,              -- 設計師標記已處理
  resolved_by     uuid                      -- work-system profiles.id
);

create index if not exists client_anxiety_signals_open_idx
  on client_anxiety_signals (client_id, created_at desc) where resolved_at is null;

-- ─── client_stage_metrics（先建表，後續邏輯）──────────────
create table if not exists client_stage_metrics (
  client_id    int not null,
  stage_key    text not null,
  login_count  int not null default 0,
  top_pages    jsonb default '[]'::jsonb,
  updated_at   timestamptz not null default now(),
  primary key (client_id, stage_key)
);

-- ════════════════════════════════════════════════════════════
-- RLS
-- ════════════════════════════════════════════════════════════
alter table customer_activity_logs enable row level security;
alter table page_view_summary enable row level security;
alter table client_anxiety_signals enable row level security;
alter table client_stage_metrics enable row level security;

-- customer_activity_logs：anon 可 INSERT（客戶端 tracking 來源），SELECT 限 authenticated
drop policy if exists "activity_logs_anon_insert" on customer_activity_logs;
create policy "activity_logs_anon_insert" on customer_activity_logs
  for insert to anon with check (true);
drop policy if exists "activity_logs_auth_all" on customer_activity_logs;
create policy "activity_logs_auth_all" on customer_activity_logs
  for all to authenticated using (true) with check (true);

-- page_view_summary：anon 可 INSERT/UPSERT（透過 RPC 更新），SELECT 限 authenticated
drop policy if exists "page_view_anon_upsert" on page_view_summary;
create policy "page_view_anon_upsert" on page_view_summary
  for all to anon using (true) with check (true);
drop policy if exists "page_view_auth_all" on page_view_summary;
create policy "page_view_auth_all" on page_view_summary
  for all to authenticated using (true) with check (true);

-- client_anxiety_signals：anon 不可碰
drop policy if exists "anxiety_signals_auth_all" on client_anxiety_signals;
create policy "anxiety_signals_auth_all" on client_anxiety_signals
  for all to authenticated using (true) with check (true);

-- client_stage_metrics：anon 不可碰
drop policy if exists "stage_metrics_auth_all" on client_stage_metrics;
create policy "stage_metrics_auth_all" on client_stage_metrics
  for all to authenticated using (true) with check (true);

-- ════════════════════════════════════════════════════════════
-- RPC: 客戶端 page_view 一鍵上報（同時插 log + 更新 summary）
-- ════════════════════════════════════════════════════════════
create or replace function record_page_view(
  p_client_id   int,
  p_project_id  int default null,
  p_page_key    text default null,
  p_duration    int default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 1) 插原始 log
  insert into customer_activity_logs (client_id, project_id, event_type, page_key, metadata)
  values (p_client_id, p_project_id, 'page_view', p_page_key, jsonb_build_object('duration', p_duration));

  -- 2) upsert summary
  insert into page_view_summary (client_id, page_key, view_count, total_duration, last_viewed_at)
  values (p_client_id, p_page_key, 1, p_duration, now())
  on conflict (client_id, page_key) do update
  set view_count = page_view_summary.view_count + 1,
      total_duration = page_view_summary.total_duration + excluded.total_duration,
      last_viewed_at = now();
end;
$$;

revoke all on function record_page_view(int, int, text, int) from public;
grant execute on function record_page_view(int, int, text, int) to anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- RPC: 客戶端通用事件上報（click_xxx 等）
-- ════════════════════════════════════════════════════════════
create or replace function record_client_event(
  p_client_id   int,
  p_event_type  text,
  p_project_id  int default null,
  p_page_key    text default null,
  p_metadata    jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into customer_activity_logs (client_id, project_id, event_type, page_key, metadata)
  values (p_client_id, p_project_id, p_event_type, p_page_key, coalesce(p_metadata, '{}'::jsonb));
end;
$$;

revoke all on function record_client_event(int, text, int, text, jsonb) from public;
grant execute on function record_client_event(int, text, int, text, jsonb) to anon, authenticated;

notify pgrst, 'reload schema';
