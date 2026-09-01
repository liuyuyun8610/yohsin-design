-- ============================================================
-- 🟢 修復客戶專區（ys-interior / vqxxaame）— 2026-09-01
--
-- 【為什麼要有這份】
-- 昨天的 rls_lockdown v1/v2/v3 把表鎖成「只給 authenticated」。
-- 但 yohsin-design 這個站【沒有任何 Supabase authenticated 使用者】：
--   客戶登入 = verify_client RPC（自建帳密比對）
--   管理員登入 = verify_admin RPC
-- 兩者都是 anon 身分在打 API。所以「只給 authenticated」在這個庫
-- 等於「誰都不給」——客戶端與 admin 後台同時全空。
--
-- 而 PostgREST 遇到「RLS 開著但沒有符合的 policy」不會報錯，
-- 是安靜回 []，所以前端沒有任何錯誤訊息，直接渲染成空白頁。
--
-- 【修法】不回頭開放 anon，而是補上這個庫缺的那層身分：
--   登入成功 → 發一把 token 存進 ys_sessions
--   前端之後每個請求帶 x-ys-token
--   RLS 依 token 判斷：admin → 全部；client → 只有自己的專案／自己的資料
--
-- 結果：
--   沒有 token 的路人（= 昨天要擋的破口）→ 仍然什麼都讀不到
--   客戶 → 只讀得到自己那一案，讀不到別的客戶
--   admin → 照常
--
-- 在【ys-interior（vqxxaame）】Supabase > SQL Editor 執行。可重複執行。
-- ============================================================

create extension if not exists pgcrypto;

-- ── 1. session 表 ────────────────────────────────────────────
create table if not exists public.ys_sessions (
  token       text primary key,
  kind        text not null check (kind in ('client','admin')),
  client_id   bigint,
  project_id  bigint,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default (now() + interval '30 days')
);
create index if not exists ys_sessions_exp on public.ys_sessions(expires_at);

-- session 表本身完全不對外：只有底下的 SECURITY DEFINER 函式碰得到。
alter table public.ys_sessions enable row level security;
do $$ declare pol record; begin
  for pol in select policyname from pg_policies
             where schemaname='public' and tablename='ys_sessions' loop
    execute format('drop policy if exists %I on public.ys_sessions', pol.policyname);
  end loop;
end $$;
revoke all on public.ys_sessions from anon, authenticated;

-- ── 2. 讀 token 的 helper ────────────────────────────────────
-- ⚠ 這幾支一律 STABLE + SECURITY DEFINER：
--    SECURITY DEFINER 才能繞過 ys_sessions 的 RLS 去查 token，
--    否則 policy 呼叫它時會查不到自己要的那一列。
create or replace function public.ys_token() returns text
language sql stable as $$
  select nullif(current_setting('request.headers', true)::json ->> 'x-ys-token', '')
$$;

create or replace function public.ys_kind() returns text
language sql stable security definer set search_path = public as $$
  select s.kind from public.ys_sessions s
   where s.token = public.ys_token() and s.expires_at > now() limit 1
$$;

create or replace function public.ys_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.ys_kind() = 'admin', false)
$$;

create or replace function public.ys_is_client() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.ys_kind() = 'client', false)
$$;

create or replace function public.ys_cid() returns bigint
language sql stable security definer set search_path = public as $$
  select s.client_id from public.ys_sessions s
   where s.token = public.ys_token() and s.expires_at > now() limit 1
$$;

create or replace function public.ys_pid() returns bigint
language sql stable security definer set search_path = public as $$
  select s.project_id from public.ys_sessions s
   where s.token = public.ys_token() and s.expires_at > now() limit 1
$$;

-- payment_settings 可能用文字編號（ys_project_id）而不是 id 關聯。
-- ⚠ 用動態 SQL：projects 不一定有這個欄位，寫死的話 create function 當場就會失敗
--   （2026-09-01 第一次執行就是踩到這點）。欄位不存在就回 null，讓 policy 自然不成立。
-- SECURITY DEFINER 是為了避免 policy 內子查詢 projects 造成 RLS 遞迴。
create or replace function public.ys_pcode() returns text
language plpgsql stable security definer set search_path = public as $$
declare v text;
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='projects'
                   and column_name='ys_project_id') then
    return null;
  end if;
  execute 'select p.ys_project_id from public.projects p where p.id = public.ys_pid() limit 1'
    into v;
  return v;
exception when others then return null;
end $$;

-- ── 3. 發 token（不動既有的 verify_client / verify_admin）────
create or replace function public.ys_issue_client_token(p_username text, p_password text)
returns text language plpgsql security definer set search_path = public as $$
declare j jsonb; t text;
begin
  -- 轉成 jsonb 再取欄位：verify_client 不論回傳 TABLE 或單一 json 都吃得下，
  -- 不用先知道它的確切簽名（這支既有函式不動它）。
  select to_jsonb(x) into j from public.verify_client(p_username, p_password) x limit 1;
  if j is null or (j->>'id') is null then return null; end if;
  delete from public.ys_sessions where expires_at < now();          -- 順手清過期
  t := encode(gen_random_bytes(32), 'hex');
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
  t := encode(gen_random_bytes(32), 'hex');
  insert into public.ys_sessions(token, kind) values (t, 'admin');
  return t;
end $$;

create or replace function public.ys_logout() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.ys_sessions where token = public.ys_token();
end $$;

grant execute on function public.ys_issue_client_token(text, text) to anon;
grant execute on function public.ys_issue_admin_token(text)        to anon;
grant execute on function public.ys_logout()                       to anon;

-- ── 4. Policies ──────────────────────────────────────────────
-- 四種存取樣式：
--   content  全站共用內容 —— 有效 session 就能讀，只有 admin 能寫
--   proj     依 project_id 隔離 —— client 只碰自己那一案
--   pcode    依 ys_project_id 隔離（payment_settings 專用）
--   cli      依 client_id 隔離 —— client 只碰自己的
--   admin    純內部 —— 只有 admin，client 完全看不到
do $$
declare
  t text; pol record;
  content_tbls text[] := array['articles','materials','vr_scenes','vr_tours','vr_hotspots','power_items'];
  proj_tbls    text[] := array['project_docs','meetings','progress_items','pending_items',
                               'checklist_items','change_orders','construction_logs'];
  cli_tbls     text[] := array['client_signatures','storage_items','client_article_notes','client_drawing_views'];
  admin_tbls   text[] := array['profit_items','procurement_costs','page_view_summary'];
  all_tbls     text[];
begin
  all_tbls := content_tbls || proj_tbls || cli_tbls || admin_tbls
              || array['projects','system_settings','payment_settings','journey_surprises'];

  -- 先清掉每張表上的舊 policy（含昨天那條 authed_all），再重建
  -- ⚠ 只處理真正的資料表：view 不能 enable RLS，碰到就整份 migration 中止
  foreach t in array all_tbls loop
    if to_regclass('public.'||t) is null then
      raise notice '略過（表不存在）: %', t; continue;
    end if;
    if (select c.relkind from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
         where ns.nspname='public' and c.relname=t) <> 'r' then
      raise notice '略過（不是資料表，可能是 view）: %', t; continue;
    end if;
    for pol in select policyname from pg_policies
               where schemaname='public' and tablename=t loop
      execute format('drop policy if exists %I on public.%I', pol.policyname, t);
    end loop;
    execute format('alter table public.%I enable row level security', t);
    -- 昨天 authenticated 那條也一併保留，未來真的接 Supabase Auth 時仍可用
    execute format($f$create policy "authed_all" on public.%I
      for all to authenticated using (true) with check (true)$f$, t);
  end loop;

  -- content：有效 session 可讀，admin 可寫
  foreach t in array content_tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    if (select c.relkind from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
         where ns.nspname='public' and c.relname=t) <> 'r' then continue; end if;
    execute format($f$create policy "sess_read" on public.%I
      for select to anon using (public.ys_kind() is not null)$f$, t);
    execute format($f$create policy "admin_write" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);
  end loop;

  -- proj：admin 全部；client 只有自己那一案（讀寫都限定）
  foreach t in array proj_tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    if (select c.relkind from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
         where ns.nspname='public' and c.relname=t) <> 'r' then continue; end if;
    execute format($f$create policy "admin_all" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);
    -- 沒有 project_id 欄位的話不能照 project 隔離，降級成「登入者可讀」，
    -- 至少不會因為建 policy 失敗而讓整份 migration 中止、把站留在半修狀態。
    if exists (select 1 from information_schema.columns
               where table_schema='public' and table_name=t and column_name='project_id') then
      execute format($f$create policy "client_own" on public.%I
        for all to anon
        using (public.ys_is_client() and project_id = public.ys_pid())
        with check (public.ys_is_client() and project_id = public.ys_pid())$f$, t);
    else
      raise notice '⚠ %：沒有 project_id 欄位，降級為登入者可讀（請事後確認是否需要更嚴）', t;
      execute format($f$create policy "sess_read" on public.%I
        for select to anon using (public.ys_kind() is not null)$f$, t);
    end if;
  end loop;

  -- cli：admin 全部；client 只有自己的
  foreach t in array cli_tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    if (select c.relkind from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
         where ns.nspname='public' and c.relname=t) <> 'r' then continue; end if;
    execute format($f$create policy "admin_all" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);
    if exists (select 1 from information_schema.columns
               where table_schema='public' and table_name=t and column_name='client_id') then
      execute format($f$create policy "client_own" on public.%I
        for all to anon
        using (public.ys_is_client() and client_id = public.ys_cid())
        with check (public.ys_is_client() and client_id = public.ys_cid())$f$, t);
    else
      raise notice '⚠ %：沒有 client_id 欄位，降級為登入者可讀', t;
      execute format($f$create policy "sess_read" on public.%I
        for select to anon using (public.ys_kind() is not null)$f$, t);
    end if;
  end loop;

  -- admin_tbls：利潤、採購成本、瀏覽統計 —— client 完全看不到
  foreach t in array admin_tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    if (select c.relkind from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
         where ns.nspname='public' and c.relname=t) <> 'r' then continue; end if;
    execute format($f$create policy "admin_only" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);
  end loop;
end $$;

-- projects：client 只看得到自己那一筆
drop policy if exists "admin_all"   on public.projects;
drop policy if exists "client_own"  on public.projects;
create policy "admin_all" on public.projects
  for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin());
create policy "client_own" on public.projects
  for select to anon using (public.ys_is_client() and id = public.ys_pid());

-- payment_settings：關聯欄位不確定，偵測後決定怎麼隔離。
-- 這張表在 work-system 那個庫也有一份，兩邊欄位不見得一樣，所以不寫死。
do $$
declare has_pid boolean; has_code boolean; proj_has_code boolean;
begin
  if to_regclass('public.payment_settings') is null then
    raise notice '略過：payment_settings 不存在'; return;
  end if;
  select exists(select 1 from information_schema.columns where table_schema='public'
                and table_name='payment_settings' and column_name='project_id') into has_pid;
  select exists(select 1 from information_schema.columns where table_schema='public'
                and table_name='payment_settings' and column_name='ys_project_id') into has_code;
  select exists(select 1 from information_schema.columns where table_schema='public'
                and table_name='projects' and column_name='ys_project_id') into proj_has_code;

  drop policy if exists "admin_all"  on public.payment_settings;
  drop policy if exists "client_own" on public.payment_settings;
  drop policy if exists "sess_read"  on public.payment_settings;
  create policy "admin_all" on public.payment_settings
    for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin());

  if has_pid then
    create policy "client_own" on public.payment_settings
      for select to anon
      using (public.ys_is_client() and project_id = public.ys_pid());
    raise notice 'payment_settings：依 project_id 隔離';
  elsif has_code and proj_has_code then
    create policy "client_own" on public.payment_settings
      for select to anon
      using (public.ys_is_client() and ys_project_id = public.ys_pcode());
    raise notice 'payment_settings：依 ys_project_id 隔離';
  else
    -- 找不到可用的關聯欄位：寧可讓客戶讀得到（付款頁要用），但記下來請你確認
    create policy "sess_read" on public.payment_settings
      for select to anon using (public.ys_kind() is not null);
    raise notice '⚠ payment_settings：找不到 project_id / ys_project_id，降級為登入者可讀，請確認這張表是否含跨客戶資料';
  end if;
end $$;

-- journey_surprises：客戶要能把驚喜標成已兌換，所以給 select + update
drop policy if exists "admin_all"    on public.journey_surprises;
drop policy if exists "client_read"  on public.journey_surprises;
drop policy if exists "client_claim" on public.journey_surprises;
create policy "admin_all" on public.journey_surprises
  for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin());
create policy "client_read" on public.journey_surprises
  for select to anon using (public.ys_kind() is not null);
create policy "client_claim" on public.journey_surprises
  for update to anon using (public.ys_is_client()) with check (public.ys_is_client());

-- system_settings：站名、logo、匯款帳戶要讀得到，
-- 但金鑰類的 key 一律不出去（前端本來就不該拿 anthropic_api_key）。
drop policy if exists "admin_all"   on public.system_settings;
drop policy if exists "sess_read"   on public.system_settings;
create policy "admin_all" on public.system_settings
  for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin());
create policy "sess_read" on public.system_settings
  for select to anon
  using (
    public.ys_kind() is not null
    and key !~* '(key|password|secret|token|api)'
  );

notify pgrst, 'reload schema';

-- ── 5. 自我檢查 ──────────────────────────────────────────────
-- 跑完應該看到每張表都有 policy；沒有 token 的 anon 仍讀不到任何東西。
select tablename, count(*) as policies
from pg_policies where schemaname='public'
  and tablename in ('projects','articles','system_settings','payment_settings',
                    'project_docs','client_signatures','profit_items','journey_surprises')
group by tablename order by tablename;

-- 順便把關聯欄位印出來，之後要再調 policy 不用猜
select table_name, string_agg(column_name, ', ' order by column_name) as 關聯欄位
from information_schema.columns
where table_schema='public'
  and column_name in ('id','project_id','ys_project_id','client_id')
  and table_name in ('projects','payment_settings','project_docs','meetings','progress_items',
                     'pending_items','checklist_items','change_orders','construction_logs',
                     'client_signatures','storage_items','client_article_notes','materials')
group by table_name order by table_name;
