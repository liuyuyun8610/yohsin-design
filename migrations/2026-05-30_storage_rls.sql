-- ============================================================
-- 補 RLS policies：storage_items / client_article_notes
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行
-- (project ref: vqxxaameifyvezvozvnf)
--
-- 背景：前兩個 migration 建表時沒給 policy，而這專案的表預設啟用 RLS，
--      導致客戶端（anon）連 INSERT 都被擋（測試時抓到）。
--      比照既有 vr_* 表的「務實寬鬆」策略補上 policy。
--
-- storage_items：客戶（anon）要能直接新增/編輯/刪除自己的收納項目。
--   DB 端無法驗證 anon 客戶身分（身分在前端 session），故採 anon 全開，
--   風險等級與既有 vr_panoramas anon insert 相同（anon key 本就公開）。
-- client_article_notes：只有設計師（authenticated）會寫，客戶（anon）只讀。
-- ============================================================

-- ── storage_items ──
alter table storage_items enable row level security;

drop policy if exists storage_items_anon_all on storage_items;
create policy storage_items_anon_all on storage_items
  for all to anon using (true) with check (true);

drop policy if exists storage_items_auth_all on storage_items;
create policy storage_items_auth_all on storage_items
  for all to authenticated using (true) with check (true);

-- ── client_article_notes ──
alter table client_article_notes enable row level security;

drop policy if exists client_article_notes_anon_read on client_article_notes;
create policy client_article_notes_anon_read on client_article_notes
  for select to anon using (true);

drop policy if exists client_article_notes_auth_all on client_article_notes;
create policy client_article_notes_auth_all on client_article_notes
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
