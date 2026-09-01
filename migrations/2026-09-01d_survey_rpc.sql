-- ============================================================
-- 修復公開問卷 + 擋住客戶互看問卷回覆
-- （ys-interior / vqxxaame）— 2026-09-01 補丁 d
--
-- 【問題 1】公開問卷完全壞掉（尚無人回報）
--   問卷回覆存在 system_settings（key = 'survey_resp_<token>'），
--   而填問卷的人是未登入的 anon、沒有 ys token，
--   昨天鎖表之後：讀既有回覆得到 []，送出時 401 permission denied。
--
-- 【問題 2】登入的客戶讀得到別人的問卷回覆
--   實測 ys001 可列出 3 筆 survey_resp_*，內容含他人填寫的生活習慣與需求。
--   主檔的 system_settings policy 只擋了金鑰類 key 名，沒料到這裡塞的是客戶資料。
--
-- 【修法】
--   公開問卷改走 SECURITY DEFINER RPC：知道問卷連結 token 的人才碰得到那一筆，
--   跟原本「拿到連結才能填」的設計一致，但不再需要對整張表開放 anon。
--   同時把 survey_% 從客戶可讀範圍排除（admin 仍可讀，走 admin_all policy）。
--
-- 在【ys-interior（vqxxaame）】Supabase > SQL Editor 執行。可重複執行。
-- ============================================================

-- ── 1. 公開問卷專用的讀寫 RPC ────────────────────────────
create or replace function public.survey_get(p_token text)
returns text language sql stable security definer set search_path = public as $$
  select s.value from public.system_settings s
   where p_token is not null and length(p_token) >= 8
     and s.key = 'survey_resp_' || p_token
   limit 1
$$;

create or replace function public.survey_save(p_token text, p_value text)
returns void language plpgsql security definer set search_path = public as $$
begin
  -- 擋掉空白／過短的 token：舊資料裡就有一筆 key='survey_resp_'（token 是空的）
  if p_token is null or length(p_token) < 8 then
    raise exception '無效的問卷連結';
  end if;
  insert into public.system_settings(key, value)
  values ('survey_resp_' || p_token, p_value)
  on conflict (key) do update set value = excluded.value;
end $$;

grant execute on function public.survey_get(text)        to anon;
grant execute on function public.survey_save(text, text) to anon;

-- ── 2. 客戶不再讀得到任何 survey_* ───────────────────────
drop policy if exists "sess_read" on public.system_settings;
create policy "sess_read" on public.system_settings
  for select to anon
  using (
    public.ys_kind() is not null
    and key !~* '(key|password|secret|token|api)'   -- 金鑰類不外流
    and key not like 'survey\_%'                    -- 問卷資料不外流（admin 走 admin_all 仍可讀）
  );

notify pgrst, 'reload schema';

-- ── 3. 自我檢查 ──────────────────────────────────────────
-- 用一個測試 token 寫入再讀出，確認 RPC 真的能動；跑完會自己刪掉測試資料。
do $$
declare got text;
begin
  perform public.survey_save('__selftest_token__', '{"probe":true}');
  select public.survey_get('__selftest_token__') into got;
  if got is null then
    raise exception '❌ survey RPC 自我檢查失敗：寫入後讀不回來';
  end if;
  delete from public.system_settings where key = 'survey_resp___selftest_token__';
  raise notice '✅ survey RPC 自我檢查通過（寫入→讀出→清理）';
end $$;

select '✅ 補丁 d 完成' as 結果;
