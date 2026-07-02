-- 在 ys-interior Supabase SQL Editor 執行（vqxxaameifyvezvozvnf）
-- 修 Supabase 資安警告 rls_disabled_in_public：client_signatures 沒開 RLS，任何人拿 URL 就能讀寫刪。
-- 比照 storage_items / client_article_notes 的「客戶端 anon 存取」模式補上 policy。
-- ⚠️ 這只解掉 linter + 統一模式；真正的「每個客戶只看自己簽名」需要客戶端改走 Supabase Auth（見 auth 強化計畫）。
-- 可重複執行。

alter table client_signatures enable row level security;

-- 客戶端（anon）：可讀取/簽署（upsert）自己的簽名。前端已用 client_id 過濾。
drop policy if exists client_signatures_anon_all on client_signatures;
create policy client_signatures_anon_all on client_signatures
  for all to anon using (true) with check (true);

-- 後台（authenticated，設計師）：完整讀寫刪。
drop policy if exists client_signatures_auth_all on client_signatures;
create policy client_signatures_auth_all on client_signatures
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
