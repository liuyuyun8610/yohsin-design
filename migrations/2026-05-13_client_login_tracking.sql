-- ════════════════════════════════════════════════════════════
-- 客戶登入時間追蹤（first_login_at / last_login_at）
--
-- 用途：ERP 每個專案能顯示「客戶用過 N 天｜最近 N 天前還在用」。
--
-- 設計：
-- 1. 不動既有 verify_client RPC（避免破壞 hash 驗證流程）
-- 2. 新增獨立 RPC record_client_login() — 前端在登入成功後額外呼叫
-- 3. 新增 RPC get_client_login_stats(int[]) — work-system 跨庫批次查詢
--
-- 跑在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor
-- ════════════════════════════════════════════════════════════

-- 1) clients 加兩個欄位
alter table clients
  add column if not exists first_login_at timestamptz,
  add column if not exists last_login_at  timestamptz;

create index if not exists clients_last_login_idx
  on clients (last_login_at desc nulls last);

-- 2) 登入記錄 RPC（前端 verify_client 成功後立刻呼叫）
--    第二參數 p_skip 為 true 時不寫入（給「設計師預覽模式」用）
create or replace function record_client_login(
  p_client_id int,
  p_skip      boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_skip then
    return;
  end if;
  update clients
  set last_login_at  = now(),
      first_login_at = coalesce(first_login_at, now())
  where id = p_client_id;
end;
$$;

revoke all on function record_client_login(int, boolean) from public;
grant execute on function record_client_login(int, boolean) to anon, authenticated;

-- 3) 跨庫查詢 RPC（work-system 用 anon key 呼叫）
--    回傳指定 client id 列表的登入統計
create or replace function get_client_login_stats(p_client_ids int[])
returns table(
  id int,
  first_login_at timestamptz,
  last_login_at  timestamptz
)
language sql
security definer
set search_path = public
as $$
  select c.id, c.first_login_at, c.last_login_at
  from clients c
  where c.id = any(p_client_ids);
$$;

revoke all on function get_client_login_stats(int[]) from public;
grant execute on function get_client_login_stats(int[]) to anon, authenticated;

notify pgrst, 'reload schema';
