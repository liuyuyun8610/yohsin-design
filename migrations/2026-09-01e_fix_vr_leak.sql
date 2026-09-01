-- ============================================================
-- 🔴 緊急修正：客戶讀得到別人的 VR 漫遊（ys-interior / vqxxaame）
--
-- 我在 2026-09-01d 把 vr_tours / vr_scenes / vr_hotspots / materials / power_items
-- 歸類為「全站共用內容」，給了「有 session 就能讀」的 policy。
-- 但 vr_tours 有 project_id 與 client_id——實測 ys003（合雄新站／專案5）
-- 讀得到「漾時光」（專案7）與「雙城街」（專案4）的漫遊。這是跨客戶外洩，必須立刻關掉。
--
-- 修法：凡是有 project_id / client_id 的，一律改成依該欄位隔離；
--       vr_scenes / vr_hotspots 沒有 project_id，透過 tour_id 回查 vr_tours 判斷。
--       只有真正全站共用的（articles）維持「登入者可讀」。
--
-- 在【ys-interior（vqxxaame）】Supabase > SQL Editor 執行。可重複執行。
-- ============================================================

-- ── 1. tour → project 的換算（SECURITY DEFINER 以免 policy 內查 vr_tours 造成遞迴）──
create or replace function public.ys_tour_pid(p_tour uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select t.project_id from public.vr_tours t where t.id = p_tour limit 1
$$;

-- ── 2. 有 project_id / client_id 的表：一律依欄位隔離 ──────
do $$
declare
  t text;
  tbls text[] := array['vr_tours','materials','power_items','journey_surprises'];
  has_p boolean; has_c boolean;
begin
  foreach t in array tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    if (select c.relkind from pg_class c join pg_namespace n on n.oid=c.relnamespace
         where n.nspname='public' and c.relname=t) <> 'r' then continue; end if;

    select exists(select 1 from information_schema.columns where table_schema='public'
                  and table_name=t and column_name='project_id') into has_p;
    select exists(select 1 from information_schema.columns where table_schema='public'
                  and table_name=t and column_name='client_id') into has_c;

    -- 清掉先前那條過寬的 sess_read / client_read / client_claim
    execute format('drop policy if exists "sess_read"    on public.%I', t);
    execute format('drop policy if exists "client_read"  on public.%I', t);
    execute format('drop policy if exists "client_claim" on public.%I', t);
    execute format('drop policy if exists "admin_write"  on public.%I', t);
    execute format('drop policy if exists "admin_all"    on public.%I', t);
    execute format('drop policy if exists "client_own"   on public.%I', t);

    execute format($f$create policy "admin_all" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);

    if has_p then
      execute format($f$create policy "client_own" on public.%I
        for all to anon
        using (public.ys_is_client() and project_id = public.ys_pid())
        with check (public.ys_is_client() and project_id = public.ys_pid())$f$, t);
      raise notice '✅ %：改為依 project_id 隔離', t;
    elsif has_c then
      execute format($f$create policy "client_own" on public.%I
        for all to anon
        using (public.ys_is_client() and client_id = public.ys_cid())
        with check (public.ys_is_client() and client_id = public.ys_cid())$f$, t);
      raise notice '✅ %：改為依 client_id 隔離', t;
    else
      execute format($f$create policy "sess_read" on public.%I
        for select to anon using (public.ys_kind() is not null)$f$, t);
      raise notice 'ℹ %：沒有 project_id／client_id，維持登入者可讀', t;
    end if;
  end loop;
end $$;

-- ── 3. vr_scenes / vr_hotspots：透過 tour_id 回查所屬專案 ──
do $$
declare t text; tbls text[] := array['vr_scenes','vr_hotspots'];
begin
  foreach t in array tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    execute format('drop policy if exists "sess_read"   on public.%I', t);
    execute format('drop policy if exists "admin_write" on public.%I', t);
    execute format('drop policy if exists "admin_all"   on public.%I', t);
    execute format('drop policy if exists "client_own"  on public.%I', t);
    execute format($f$create policy "admin_all" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);
    if exists (select 1 from information_schema.columns where table_schema='public'
               and table_name=t and column_name='tour_id') then
      execute format($f$create policy "client_own" on public.%I
        for select to anon
        using (public.ys_is_client() and public.ys_tour_pid(tour_id) = public.ys_pid())$f$, t);
      raise notice '✅ %：改為依 tour_id → 專案 隔離', t;
    elsif exists (select 1 from information_schema.columns where table_schema='public'
                  and table_name=t and column_name='scene_id') then
      -- hotspot 可能掛在 scene 底下，再往上一層回查
      execute format($f$create policy "client_own" on public.%I
        for select to anon
        using (public.ys_is_client() and exists (
          select 1 from public.vr_scenes s
           where s.id = %I.scene_id and public.ys_tour_pid(s.tour_id) = public.ys_pid()))$f$, t, t);
      raise notice '✅ %：改為依 scene_id → tour → 專案 隔離', t;
    else
      raise notice '⚠ %：找不到 tour_id／scene_id，暫時只給 admin', t;
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';

-- ── 4. 自我檢查：ys003（專案5）應該只看得到自己的漫遊 ──────
do $$
declare n_all int; n_other int;
begin
  select count(*) into n_all from public.vr_tours;
  select count(*) into n_other from public.vr_tours where project_id <> 5;
  raise notice 'ℹ 資料庫共 % 筆漫遊，其中不屬於專案5的有 % 筆（客戶ys003應該一筆都讀不到）', n_all, n_other;
end $$;

select tablename, policyname, cmd
from pg_policies
where schemaname='public' and tablename in ('vr_tours','vr_scenes','vr_hotspots','materials','power_items','journey_surprises')
order by tablename, policyname;
