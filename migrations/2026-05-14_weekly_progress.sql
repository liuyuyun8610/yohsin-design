-- ════════════════════════════════════════════════════════════
-- projects 加 weekly_progress jsonb 欄位
--
-- 對齊「客戶想知道我們最近幫他做了什麼」洞察。
-- 設計師每週在 ERP 寫一次：完成了什麼 / 下週要做 / 需要客戶協助確認。
-- 客戶端首頁顯示。
--
-- 資料格式：
-- {
--   "week_label": "2026/05/12 - 05/18",
--   "completed": ["...", "..."],
--   "next_week": ["...", "..."],
--   "pending_for_client": ["...", "..."],
--   "updated_at": "2026-05-14T..."
-- }
--
-- 跑在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor
-- ════════════════════════════════════════════════════════════

alter table projects
  add column if not exists weekly_progress jsonb;

-- 給 anon 讀（客戶端要看）— 沿用 projects 既有 read policy
-- 寫入只有 admin（authenticated 走 service_role / 既有 admin 寫 policy）

notify pgrst, 'reload schema';
