-- ============================================================
-- Phase B Step 4b：鎖死 clients 表的 anon 存取
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行
-- (project ref: vqxxaameifyvezvozvnf)
--
-- 執行後：
--   - anon 完全無法 SELECT / INSERT / UPDATE / DELETE clients 表
--   - 客戶登入仍可（走 verify_client RPC，SECURITY DEFINER 繞過 RLS）
--   - admin 登入仍可（用 Supabase Auth session = authenticated 身份）
-- ============================================================

-- 1. 確保 RLS 開啟（已開的話無害）
alter table public.clients enable row level security;

-- 2. 撤銷 anon 對 clients 表的所有 SQL 權限
--    這是最徹底的鎖定方式：anon 連嘗試都不能，比 RLS policy 更前置
revoke all on public.clients from anon;

-- 3. 確保 authenticated 仍有完整權限（admin 透過 Supabase Auth 用）
grant select, insert, update, delete on public.clients to authenticated;

-- 4. 建立 authenticated 的 RLS policy（如果還沒有）
do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'clients' and policyname = 'clients_authenticated_all'
  ) then
    execute 'create policy "clients_authenticated_all" on public.clients
      for all to authenticated
      using (true) with check (true)';
  end if;
end $$;

-- 5. 驗證（可選，跑完看 result 確認）
--    應該看到：
--      - anon 行：沒有任何 privilege
--      - authenticated 行：有 SELECT/INSERT/UPDATE/DELETE
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'clients'
  and grantee in ('anon', 'authenticated')
order by grantee, privilege_type;
