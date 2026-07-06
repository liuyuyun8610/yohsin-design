-- 客戶類型：existing（成屋 · 完整版）/ presale（預售屋客變 · 精簡版）
-- 用英文值避免中文編碼問題。在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor 執行，可重複執行。

-- 若之前已用中文值建過欄位/約束，先清掉舊約束再重建
alter table public.projects drop constraint if exists projects_client_type_chk;

alter table public.projects add column if not exists client_type text;
-- 把舊的中文/空值統一成 existing
update public.projects set client_type='existing'
  where client_type is null or client_type not in ('existing','presale');
alter table public.projects alter column client_type set default 'existing';
alter table public.projects alter column client_type set not null;

alter table public.projects
  add constraint projects_client_type_chk check (client_type in ('existing','presale'));

notify pgrst, 'reload schema';
