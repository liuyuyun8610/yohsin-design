-- 客戶類型：成屋（完整版）/ 預售屋（客變精簡版）
-- 在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor 執行。可重複執行。
alter table public.projects add column if not exists client_type text not null default '成屋';

-- 只允許兩種值
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'projects_client_type_chk' and table_name = 'projects'
  ) then
    alter table public.projects
      add constraint projects_client_type_chk check (client_type in ('成屋','預售屋'));
  end if;
end $$;

notify pgrst, 'reload schema';
