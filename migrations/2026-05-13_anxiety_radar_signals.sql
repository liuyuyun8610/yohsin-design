-- ════════════════════════════════════════════════════════════
-- 焦慮雷達 Phase 3：判斷規則 RPC
--
-- compute_anxiety_signals(client_id) — 根據規格 6 條規則跑一次，
--   產出當下的 client_anxiety_signals row（不重複插同類訊號 if 已開啟）
--
-- 6 條規則：
--   1. 7 天內查看 payment 頁 ≥ 5 次          → 主動說明下一期款項
--   2. drawings 多次 + 停留長                → 補充圖面說明
--   3. 反覆查看 change_orders                → 整理追加減摘要
--   4. materials 多次但未確認                → 主動詢問替代方案（未確認的判斷比較複雜，先用次數）
--   5. 登入頻率突然增加（近 3 天 ≥ 5 次）    → 客戶關注升高
--   6. 很久沒登入（last_login > 14 天前）    → 客戶可能脫離節奏
--
-- 跑在 ys-interior Supabase
-- ════════════════════════════════════════════════════════════

create or replace function compute_anxiety_signals(p_client_id int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_proj_id int;
  v_pv_payment int;
  v_pv_drawings int;
  v_pv_changes int;
  v_pv_materials int;
  v_drawings_dur int;
  v_login_count_3d int;
  v_last_login timestamptz;
  v_days_since_login int;
begin
  -- 取對應 project_id
  select project_id into v_proj_id from clients where id = p_client_id;

  -- ── 規則 1：7 天內查 payment ≥ 5 次 ──
  select count(*) into v_pv_payment
  from customer_activity_logs
  where client_id = p_client_id
    and event_type = 'page_view'
    and page_key = 'payment'
    and created_at >= now() - interval '7 days';
  if v_pv_payment >= 5 then
    perform _emit_signal(p_client_id, v_proj_id, 'frequent_payment_view', 'warning',
      format('客戶近 7 天查看付款資訊 %s 次', v_pv_payment),
      '建議主動說明下一期款項與對應工程內容。');
  end if;

  -- ── 規則 2：drawings 多次 + 停留長 ──
  select count(*), coalesce(sum((metadata->>'duration')::int), 0) into v_pv_drawings, v_drawings_dur
  from customer_activity_logs
  where client_id = p_client_id
    and event_type = 'page_view' and page_key = 'drawings'
    and created_at >= now() - interval '7 days';
  if v_pv_drawings >= 4 and v_drawings_dur >= 60 then
    perform _emit_signal(p_client_id, v_proj_id, 'frequent_drawings_view', 'info',
      format('客戶近 7 天查看圖面 %s 次，累積停留 %s 秒', v_pv_drawings, v_drawings_dur),
      '客戶可能在確認圖面或尺寸，建議補充圖面說明。');
  end if;

  -- ── 規則 3：反覆查 change_orders ──
  select count(*) into v_pv_changes
  from customer_activity_logs
  where client_id = p_client_id
    and event_type = 'page_view' and page_key = 'change_orders'
    and created_at >= now() - interval '7 days';
  if v_pv_changes >= 3 then
    perform _emit_signal(p_client_id, v_proj_id, 'frequent_changes_view', 'warning',
      format('客戶近 7 天查看追加減 %s 次', v_pv_changes),
      '客戶可能對費用變動敏感，建議整理追加減摘要主動說明。');
  end if;

  -- ── 規則 4：materials 多次（未確認的判斷待 Phase 5）──
  select count(*) into v_pv_materials
  from customer_activity_logs
  where client_id = p_client_id
    and event_type = 'page_view' and page_key = 'materials'
    and created_at >= now() - interval '7 days';
  if v_pv_materials >= 5 then
    perform _emit_signal(p_client_id, v_proj_id, 'frequent_materials_view', 'info',
      format('客戶近 7 天查看選材 %s 次', v_pv_materials),
      '客戶可能猶豫定案，建議主動詢問是否需要替代方案。');
  end if;

  -- ── 規則 5：登入頻率升高（近 3 天 ≥ 5 次）──
  -- 用 clients.last_login_at 不夠細，改數 page_view 的 distinct day
  select count(distinct date_trunc('day', created_at)) into v_login_count_3d
  from customer_activity_logs
  where client_id = p_client_id
    and created_at >= now() - interval '3 days';
  if v_login_count_3d >= 3 then
    perform _emit_signal(p_client_id, v_proj_id, 'login_surge', 'warning',
      format('客戶近 3 天登入 %s 天', v_login_count_3d),
      '客戶關注度突然升高，建議主動確認是否有疑問或決策壓力。');
  end if;

  -- ── 規則 6：很久沒登入（> 14 天）──
  select last_login_at into v_last_login from clients where id = p_client_id;
  if v_last_login is not null then
    v_days_since_login := extract(day from now() - v_last_login)::int;
    if v_days_since_login >= 14 then
      perform _emit_signal(p_client_id, v_proj_id, 'long_absence', 'info',
        format('客戶已 %s 天未登入', v_days_since_login),
        '客戶可能脫離專案節奏，建議主動更新本週進度。');
    end if;
  end if;
end;
$$;

-- helper：插 signal 但避免重複（同 client + 同 type 還沒 resolved 就跳過）
create or replace function _emit_signal(
  p_client_id int, p_project_id int, p_signal_type text,
  p_severity text, p_message text, p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from client_anxiety_signals
    where client_id = p_client_id and signal_type = p_signal_type and resolved_at is null
  ) then
    return;
  end if;
  insert into client_anxiety_signals (client_id, project_id, signal_type, severity, message, suggested_action)
  values (p_client_id, p_project_id, p_signal_type, p_severity, p_message, p_action);
end;
$$;

revoke all on function compute_anxiety_signals(int) from public;
grant execute on function compute_anxiety_signals(int) to authenticated;
revoke all on function _emit_signal(int, int, text, text, text, text) from public;

-- ════════════════════════════════════════════════════════════
-- compute_all_anxiety_signals() — 跑全部 active client 一輪
-- ════════════════════════════════════════════════════════════
create or replace function compute_all_anxiety_signals()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_client int;
begin
  for v_client in
    select id from clients
    where coalesce(status, '') != '已結案' and coalesce(is_boss, false) = false
  loop
    perform compute_anxiety_signals(v_client);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function compute_all_anxiety_signals() from public;
grant execute on function compute_all_anxiety_signals() to authenticated;

notify pgrst, 'reload schema';
