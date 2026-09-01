-- ============================================================
-- 收緊 payment_settings（ys-interior / vqxxaame）— 2026-09-01 補丁
--
-- 主檔跑完後偵測到：payment_settings 有 ys_project_id，但 projects 沒有，
-- 所以無法依專案隔離，主檔降級成了「任何登入者都讀得到整張表」。
--
-- 但客戶端讀這張表的程式碼是：
--   sbClient.from('payment_settings').eq('ys_project_id', p.ys_project_id)
-- 而 p.ys_project_id 來自 projects 表——那個欄位不存在，值永遠是 undefined，
-- 這條路本來就拿不到資料。真正在運作的是 wsClient（work-system 那個庫）。
--
-- 因此收成 admin only，不會壞掉任何正在運作的功能，
-- 也不會讓客戶 A 讀到客戶 B 的請款排程與設計費。
--
-- 在【ys-interior（vqxxaame）】Supabase > SQL Editor 執行。可重複執行。
-- ============================================================

do $$
begin
  if to_regclass('public.payment_settings') is null then
    raise notice '略過：payment_settings 不存在'; return;
  end if;
  drop policy if exists "sess_read"  on public.payment_settings;
  drop policy if exists "client_own" on public.payment_settings;
  drop policy if exists "admin_all"  on public.payment_settings;
  create policy "admin_all" on public.payment_settings
    for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin());
  raise notice 'payment_settings 已收緊為 admin only';
end $$;

notify pgrst, 'reload schema';

select policyname, cmd, roles::text
from pg_policies
where schemaname='public' and tablename='payment_settings'
order by policyname;
