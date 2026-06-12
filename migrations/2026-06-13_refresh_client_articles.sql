-- 修 bug：客戶端登入時把整包 client（含 assigned_articles）存進 localStorage，
-- 之後 restore 都直接用快照、不再查 DB —— 後台新增的文章（如 #8 防水、#10 甲醛）
-- 對「登入過的客戶」永遠不會出現，除非登出重登。
--
-- 此函式給前端 restore 時背景刷新指派清單用。
-- SECURITY DEFINER：clients 表有 RLS 鎖 anon，但這裡只回傳文章 id 陣列，無敏感資料。

create or replace function public.refresh_client_articles(p_client_id integer)
returns integer[]
language sql
security definer
set search_path = public
as $$
  select coalesce(assigned_articles, '{}'::integer[])
  from clients
  where id = p_client_id;
$$;

revoke all on function public.refresh_client_articles(integer) from public;
grant execute on function public.refresh_client_articles(integer) to anon, authenticated;
