-- ════════════════════════════════════════════════════════════
-- vr-panoramas Storage：開放 anon INSERT
--
-- 為什麼：
-- Vercel server actions body 上限 4.5MB（所有 plan），但 4K 全景圖
-- 通常 5-15MB，無法走 server side 上傳。改成 client 用 anon key 直連
-- Supabase Storage（不走 Vercel function），就沒有 4.5MB 限制。
--
-- 風險評估：
-- vr-panoramas 是 public bucket（公開讀），開放 anon insert 等於任何
-- 拿到 anon key 的人都能上傳。anon key 本身就是 client side 必然曝露
-- 的 public key，所以 risk 可控。設計師後台 Admin 才會真正觸發上傳。
-- 之後若擔心垃圾上傳，可改用 signed upload URL（需重構）。
--
-- 跑在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor
-- ════════════════════════════════════════════════════════════

-- Storage policies 在 storage.objects 表
-- 既存 policies 不動（authenticated insert / select 還在）
-- 加 anon insert：限定 bucket = 'vr-panoramas'
drop policy if exists "vr_panoramas_anon_insert" on storage.objects;
create policy "vr_panoramas_anon_insert" on storage.objects
  for insert to anon
  with check (bucket_id = 'vr-panoramas');

-- 也順便確認 anon 可以 SELECT public bucket（理論上 public bucket 自動 OK，但保險加一條）
drop policy if exists "vr_panoramas_anon_select" on storage.objects;
create policy "vr_panoramas_anon_select" on storage.objects
  for select to anon
  using (bucket_id = 'vr-panoramas');
