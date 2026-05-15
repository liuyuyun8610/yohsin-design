-- ============================================================
-- Phase B 補完：鎖 system_settings 表的敏感 key（admin_password / anthropic_api_key）
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行
-- (project ref: vqxxaameifyvezvozvnf)
--
-- 執行後：
--   - anon 仍可 SELECT 公開 key（site_title / *_icon_url / bank_* / receipt_logo
--     / survey_resp_<token>），保證客戶端 + 公開問卷頁可正常運作
--   - anon 完全拿不到 admin_password (hash) 跟 anthropic_api_key
--   - authenticated（admin 登入後）仍全開
--   - 寫入路徑（upsert）只開給 authenticated；anon 不能改任何 setting
-- ============================================================

-- 1. 開 RLS（已開無害）
alter table public.system_settings enable row level security;

-- 2. 撤銷 anon 原本的 table 權限，重發只給 SELECT
revoke all on public.system_settings from anon;
grant select on public.system_settings to anon;

-- 3. anon SELECT policy：黑名單擋掉敏感 key
do $$ begin
  if exists (
    select 1 from pg_policies where tablename = 'system_settings' and policyname = 'system_settings_anon_safe_select'
  ) then
    drop policy "system_settings_anon_safe_select" on public.system_settings;
  end if;
end $$;

create policy "system_settings_anon_safe_select" on public.system_settings
  for select to anon
  using (
    key not in ('admin_password', 'anthropic_api_key')
  );

-- 4. authenticated：所有操作全開
grant select, insert, update, delete on public.system_settings to authenticated;

do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'system_settings' and policyname = 'system_settings_authenticated_all'
  ) then
    execute 'create policy "system_settings_authenticated_all" on public.system_settings
      for all to authenticated
      using (true) with check (true)';
  end if;
end $$;

-- 5. 驗證
--    應該看到：
--      - anon → 只有 SELECT
--      - authenticated → SELECT/INSERT/UPDATE/DELETE
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'system_settings'
  and grantee in ('anon', 'authenticated')
order by grantee, privilege_type;

-- 跑完後，可在 SQL Editor 跑下面這條檢查 anon 真的拿不到敏感 key：
-- 結果應該是 0 row
-- set role anon;
-- select key from public.system_settings where key in ('admin_password','anthropic_api_key');
-- reset role;
