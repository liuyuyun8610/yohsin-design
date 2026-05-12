-- ════════════════════════════════════════════════════════════
-- 裝修旅程驚喜：加「已實現」狀態（redeemed_at）
--
-- 原有狀態流：
--   未拆 → acknowledged_at（點開 modal 自動標）
--
-- 新狀態流：
--   未拆 → acknowledged_at（點開）→ redeemed_at（實際使用）
--
-- 為什麼分兩個 timestamp：
--   acknowledged = 客戶有看到這份禮物（被動）
--   redeemed     = 客戶實際選擇使用/兌現（主動行為，不可逆）
--
-- 跑在 ys-interior Supabase（vqxxaameifyvezvozvnf）SQL Editor
-- ════════════════════════════════════════════════════════════

alter table journey_surprises
  add column if not exists redeemed_at timestamptz;

create index if not exists journey_surprises_redeemed_idx
  on journey_surprises (client_id, redeemed_at desc nulls last);

notify pgrst, 'reload schema';
