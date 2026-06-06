-- AI 生活情境預覽 — 資料表
-- 客戶在「效果圖」頁可請 AI 解說、生成情境預覽圖（改光線/加生活感），
-- 但不覆蓋原圖、每位客戶可由設計師開關並限制每日次數。
--
-- 全部讀寫都走 Edge Function `ai-preview`（service role 繞過 RLS）。
-- 這裡開了 RLS 但「不建立任何 anon/authenticated policy」= 預設拒絕，
-- 前端不直接碰這兩張表，最安全。

-- 1) 每位客戶的開關設定（預設關閉，要設計師逐個打開）
create table if not exists ai_preview_settings (
  client_id   int  primary key,
  enabled     boolean not null default false,
  daily_limit int  not null default 3,
  updated_at  timestamptz not null default now()
);

-- 2) AI 情境預覽生成紀錄（歷史 + 後台查看 + 每日次數計算）
create table if not exists ai_scene_previews (
  id               bigserial primary key,
  client_id        int  not null,
  project_id       int,
  source_image_url text not null,          -- 原始效果圖網址
  source_drawing_id text,                  -- 原圖的 dbId（用來歸到同一張圖底下）
  scene_key        text not null,          -- 預設情境 key 或 'custom'
  scene_label      text,                   -- 顯示用（早晨自然光…）
  prompt           text,                   -- 實際送出的提示（自訂時為客戶輸入）
  result_image_url text not null,          -- 生成圖（存在 photos bucket）
  in_discussion    boolean not null default false,  -- 設計師標記「加入正式討論紀錄」
  created_at       timestamptz not null default now()
);

create index if not exists idx_ai_scene_client
  on ai_scene_previews(client_id, created_at desc);

alter table ai_preview_settings enable row level security;
alter table ai_scene_previews   enable row level security;
