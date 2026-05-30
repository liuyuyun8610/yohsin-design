-- ============================================================
-- storage_items：客戶區「收納規劃工具」資料表
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行
-- (project ref: vqxxaameifyvezvozvnf)
--
-- 一張表涵蓋三個工具，用 kind 區分：
--   have  = A 我有哪些東西
--   large = B 大尺寸 / 特殊物品
--   hide  = C 我不想看到什麼
-- 各工具的欄位放在 data jsonb，未來要加欄位不用改 schema。
-- 後台欄位（status / designer_note / is_important）給設計師用，不顯示給客戶。
-- 安全姿態比照既有的 client_signatures（anon 可讀寫，前端以 client_id 過濾）。
-- ============================================================

create table if not exists storage_items (
  id bigserial primary key,
  client_id bigint not null references clients(id) on delete cascade,
  kind text not null,                       -- have | large | hide
  data jsonb not null default '{}'::jsonb,  -- 各工具自己的欄位
  status text default 'new',                -- new 未處理 | discuss 需討論 | included 已納入設計 | need_more 需客戶補充
  designer_note text,                       -- 設計師內部備註，不顯示給客戶
  is_important boolean default false,        -- 設計師標記「一定要留位置 / 需插座 / 尺寸待確認」
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_storage_items_client on storage_items(client_id);

-- 通知 PostgREST 重載 schema cache
notify pgrst, 'reload schema';
