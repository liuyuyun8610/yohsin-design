-- ════════════════════════════════════════════════════════════
-- VR 漫遊功能 schema（Step 1 of 3）
--
-- 三張表：
--   vr_tours    — 一個 project 可有多個 tour（例：「2026/05/11 完工實景」「設計階段預覽」）
--   vr_scenes   — 一個 tour 含多個場景（玄關 / 客廳 / 主臥）
--   vr_hotspots — 場景間的金色光點，點擊跳到下一個場景
--
-- 對應 demo：~/Desktop/3d-tour-demo.html（用 Photo Sphere Viewer）
-- 完整規格：~/Desktop/VR-TOUR-HANDOVER.md
--
-- 跑在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor
-- ════════════════════════════════════════════════════════════

-- ─── vr_tours ──────────────────────────────────────────────
create table if not exists vr_tours (
  id                uuid primary key default gen_random_uuid(),
  project_id        int not null,                       -- ys-interior projects.id
  client_id         int,                                -- 反正規化方便 RLS 比對（=projects.client_id）
  title             text not null,                      -- 「2026/05/11 完工實景漫遊」
  description       text,
  tour_date         date,
  initial_scene_id  uuid,                               -- 進場第一個場景（fk 之後 set）
  status            text not null default 'draft',      -- draft / published
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists vr_tours_project_idx
  on vr_tours (project_id, status);
create index if not exists vr_tours_client_idx
  on vr_tours (client_id) where status = 'published';

-- ─── vr_scenes ─────────────────────────────────────────────
create table if not exists vr_scenes (
  id            uuid primary key default gen_random_uuid(),
  tour_id       uuid not null references vr_tours(id) on delete cascade,
  name          text not null,                          -- 玄關 / 客廳 / 主臥
  panorama_url  text not null,                          -- Supabase Storage URL（4K equirectangular jpg）
  thumb_url     text,                                   -- 縮圖（給 picker 用，可選）
  default_yaw   numeric default 0,                      -- 進場初始視角 yaw（-180~180）
  default_pitch numeric default 0,                      -- 進場初始 pitch（-90~90）
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);

create index if not exists vr_scenes_tour_idx
  on vr_scenes (tour_id, sort_order);

-- 加 initial_scene_id 的外鍵（要等 vr_scenes 表先建好）
do $$
begin
  alter table vr_tours
    add constraint vr_tours_initial_scene_fk
    foreign key (initial_scene_id) references vr_scenes(id) on delete set null;
exception when duplicate_object then null;
end $$;

-- ─── vr_hotspots ───────────────────────────────────────────
create table if not exists vr_hotspots (
  id              uuid primary key default gen_random_uuid(),
  scene_id        uuid not null references vr_scenes(id) on delete cascade,
  target_scene_id uuid not null references vr_scenes(id) on delete cascade,
  yaw             numeric not null,                     -- 點擊位置 yaw（-180~180）
  pitch           numeric not null,                     -- 點擊位置 pitch（-90~90）
  label           text,                                 -- 「客廳」「主臥」（可選 tooltip）
  created_at      timestamptz not null default now()
);

create index if not exists vr_hotspots_scene_idx
  on vr_hotspots (scene_id);

-- ─── auto updated_at trigger（vr_tours）────────────────────
create or replace function vr_tours_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists vr_tours_updated_at on vr_tours;
create trigger vr_tours_updated_at
  before update on vr_tours
  for each row execute function vr_tours_set_updated_at();

-- ════════════════════════════════════════════════════════════
-- RLS policies（暫採務實寬鬆策略）
-- ════════════════════════════════════════════════════════════
-- 客戶端用 anon key 登入後看自己 tour。anon 知不知道自己是誰？
-- ys-interior 客戶身分在前端 sessionStorage，DB 端無法驗證。
-- 短期方案：published 的 tour 對 anon 全開（讀），其餘 admin only。
-- 寫入：admin 透過 service_role key 直接做（繞過 RLS）。
-- 中期：等 Phase B 客戶 Supabase Auth 完成後改更嚴格的 RLS。
-- ════════════════════════════════════════════════════════════

alter table vr_tours    enable row level security;
alter table vr_scenes   enable row level security;
alter table vr_hotspots enable row level security;

-- vr_tours：anon 可讀 published；authenticated（admin）可全 CRUD
drop policy if exists "vr_tours_anon_read_published" on vr_tours;
create policy "vr_tours_anon_read_published" on vr_tours
  for select to anon using (status = 'published');
drop policy if exists "vr_tours_authenticated_all" on vr_tours;
create policy "vr_tours_authenticated_all" on vr_tours
  for all to authenticated using (true) with check (true);

-- vr_scenes：anon 可讀屬於 published tour 的；authenticated 全 CRUD
drop policy if exists "vr_scenes_anon_read" on vr_scenes;
create policy "vr_scenes_anon_read" on vr_scenes
  for select to anon using (
    exists (select 1 from vr_tours t where t.id = vr_scenes.tour_id and t.status = 'published')
  );
drop policy if exists "vr_scenes_authenticated_all" on vr_scenes;
create policy "vr_scenes_authenticated_all" on vr_scenes
  for all to authenticated using (true) with check (true);

-- vr_hotspots：跟 scene 走
drop policy if exists "vr_hotspots_anon_read" on vr_hotspots;
create policy "vr_hotspots_anon_read" on vr_hotspots
  for select to anon using (
    exists (
      select 1 from vr_scenes s
      join vr_tours t on t.id = s.tour_id
      where s.id = vr_hotspots.scene_id and t.status = 'published'
    )
  );
drop policy if exists "vr_hotspots_authenticated_all" on vr_hotspots;
create policy "vr_hotspots_authenticated_all" on vr_hotspots
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════
-- ⚠️ 跑完此 SQL 後，請在 Supabase Dashboard 手動建 Storage bucket：
--
-- Storage → New bucket：
--   - 名稱：vr-panoramas
--   - Public bucket：✅ 開（讓 panorama URL 可直接 fetch）
--   - File size limit：30 MB
--   - Allowed MIME types：image/jpeg, image/png
--
-- 然後加 RLS policies（Storage > Policies）：
--   - SELECT for anon：true（public read，只要有 URL 就能看）
--   - INSERT/UPDATE/DELETE for authenticated：true
--
-- 路徑規範：vr-panoramas/{project_id}/{tour_id}/{scene_id}.jpg
-- ════════════════════════════════════════════════════════════
