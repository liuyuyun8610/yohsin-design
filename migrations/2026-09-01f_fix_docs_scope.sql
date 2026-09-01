-- ============================================================
-- 🔴 修正隔離依據：project_docs / meetings / pending_items 的
--    project_id 欄位存的是 client.id，不是 projects.id
--    （ys-interior / vqxxaame）— 2026-09-01
--
-- 程式碼 getAdminDocClientId() 的註解寫得很清楚：
--   「約定：project_docs.project_id 在這個 app 實際存的是 client.id（命名歷史包袱）」
-- 我先前沒看到這行，policy 一律寫成 project_id = ys_pid()（專案 id），
-- 導致合雄新站（客戶3／專案5）用專案 id 5 去比對，撈到 client_id=5 的漾時光資料。
--
-- 正確依據：
--   project_docs / meetings / pending_items → project_id = 客戶 id → 用 ys_cid()
--   construction_logs / checklist_items / progress_items / change_orders
--                                          → 真的是專案 id     → 用 ys_pid()
--
-- 在【ys-interior（vqxxaame）】Supabase > SQL Editor 執行。可重複執行。
-- ============================================================

-- ── 1. 這三張改用 client.id 比對 ─────────────────────────
do $$
declare t text; tbls text[] := array['project_docs','meetings','pending_items'];
begin
  foreach t in array tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    execute format('drop policy if exists "client_own" on public.%I', t);
    execute format('drop policy if exists "sess_read"  on public.%I', t);
    execute format('drop policy if exists "admin_all"  on public.%I', t);
    execute format($f$create policy "admin_all" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);
    -- ⚠ 欄位叫 project_id，值是 client.id
    execute format($f$create policy "client_own" on public.%I
      for all to anon
      using (public.ys_is_client() and project_id = public.ys_cid())
      with check (public.ys_is_client() and project_id = public.ys_cid())$f$, t);
    raise notice '✅ %：改用 client.id 比對（欄位名雖為 project_id）', t;
  end loop;
end $$;

-- ── 2. 這幾張確認維持用專案 id ───────────────────────────
do $$
declare t text; tbls text[] := array['construction_logs','checklist_items','progress_items','change_orders'];
begin
  foreach t in array tbls loop
    if to_regclass('public.'||t) is null then continue; end if;
    execute format('drop policy if exists "client_own" on public.%I', t);
    execute format('drop policy if exists "sess_read"  on public.%I', t);
    execute format('drop policy if exists "admin_all"  on public.%I', t);
    execute format($f$create policy "admin_all" on public.%I
      for all to anon using (public.ys_is_admin()) with check (public.ys_is_admin())$f$, t);
    execute format($f$create policy "client_own" on public.%I
      for all to anon
      using (public.ys_is_client() and project_id = public.ys_pid())
      with check (public.ys_is_client() and project_id = public.ys_pid())$f$, t);
    raise notice '✅ %：維持用專案 id 比對', t;
  end loop;
end $$;

notify pgrst, 'reload schema';

-- ── 3. 驗證：合雄新站（客戶id 3）應該拿到 94 筆文件，不是 56 筆 ──
select
  '合雄新站(客戶id 3)' as 對象,
  (select count(*) from public.project_docs where project_id = 3) as 應得文件數,
  (select count(*) from public.meetings     where project_id = 3) as 應得會議數
union all
select
  '漾時光(客戶id 5)',
  (select count(*) from public.project_docs where project_id = 5),
  (select count(*) from public.meetings     where project_id = 5);
