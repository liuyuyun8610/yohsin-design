-- ============================================================
-- 專案裝修階段（給 ys-interior 客戶端首頁顯示時間軸用）
--
-- 跟 work-system migrations/2026-05-10_project_phase.sql 同樣 schema，
-- 兩邊都加一份，work-system 設計師更新時 dual-write 兩邊。
--
-- 在 Supabase Dashboard > SQL Editor 跑（ys-interior 專案）
-- ============================================================

ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS current_phase INT DEFAULT 1
  CHECK (current_phase BETWEEN 1 AND 11);
