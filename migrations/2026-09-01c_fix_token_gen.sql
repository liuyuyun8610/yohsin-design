-- ============================================================
-- 修正 token 產生失敗 + 收緊 payment_settings
-- （ys-interior / vqxxaame）— 2026-09-01 補丁 c
--
-- 【問題 1】換 token 時 DB 回 42883：
--   function gen_random_bytes(integer) does not exist
--   pgcrypto 在 Supabase 裝在 extensions schema，而函式寫了
--   set search_path = public，所以找不到。主檔那句
--   create extension if not exists pgcrypto 因為「已存在」而沒有作用。
--   → 改用 gen_random_uuid()：PostgreSQL 13+ 內建於 pg_catalog，
--     不依賴任何 extension，search_path 怎麼設都找得到。
--
-- 【問題 2】payment_settings 有 ys_project_id 但 projects 沒有，
--   主檔因此降級成「任何登入者都讀得到整張表」（含請款排程、設計費）。
--   客戶端讀它的程式碼用 p.ys_project_id，該欄位不存在、值恆為 undefined，
--   這條路本來就拿不到資料（真正在運作的是 work-system 那個庫），
--   所以收成 admin only 不會壞掉任何正在運作的功能。
--
-- 在【ys-interior（vqxxaame）】Supabase > SQL Editor 執行。可重複執行。
-- ============================================================

-- ── 1. 重建發 token 的兩支函式（不依賴 pgcrypto）──────────
create or replace function public.ys_issue_client_token(p_username text, p_password text)
returns text language plpgsql security definer set search_path = public as $$
declare j jsonb; t text;
begin
  select to_jsonb(x) into j from public.verify_client(p_username, p_password) x limit 1;
  if j is null or (j->>'id') is null then return null; end if;
  delete from public.ys_sessions where expires_at < now();
  -- 兩個 uuid 串接 = 64 個十六進位字元；gen_random_uuid() 是 pg_catalog 內建
  t := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.ys_sessions(token, kind, client_id, project_id)
  values (t, 'client', (j->>'id')::bigint, nullif(j->>'project_id','')::bigint);
  return t;
end $$;

create or replace function public.ys_issue_admin_token(p_password text)
returns text language plpgsql security definer set search_path = public as $$
declare t text;
begin
  if public.verify_admin(p_password) is not true then return null; end if;
  delete from public.ys_sessions where expires_at < now();
  t := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.ys_sessions(token, kind) values (t, 'admin');
  return t;
end $$;

grant execute on function public.ys_issue_client_token(text, text) to anon;
grant execute on function public.ys_issue_admin_token(text)        to anon;

-- ── 2. 收緊 payment_settings ─────────────────────────────
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

-- ── 3. 立即自我檢查：直接在 DB 裡發一把 token 看看成不成 ──
-- 用測試帳號 ys001 驗證整條路；成功會看到一串 64 字元的 token。
select case
         when public.ys_issue_client_token('ys001','123456') is null
           then '❌ 仍然發不出 token（帳密不符或 verify_client 有異常）'
         else '✅ token 產生成功（長度 ' ||
              length(public.ys_issue_client_token('ys001','123456'))::text || '）'
       end as 檢查結果;
