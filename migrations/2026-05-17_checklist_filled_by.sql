-- ============================================================
-- checklist_items + power_items 加 filled_by 欄位
--
-- 用途：區分這筆是客戶自己填的 (client)，還是設計師從 ERP 代填的 (designer)。
-- 客戶端「必填清單」會在 designer 代填的項目旁顯示小 tag。
--
-- ⚠️ 注意：這個 SQL 跑在 ys-interior 的 Supabase（project ref: vqxxaameifyvezvozvnf），
--    不是 work-system（kwtozldimwidbkemrdgg）。
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行。
-- ============================================================

alter table public.checklist_items
  add column if not exists filled_by text not null default 'client'
  check (filled_by in ('client','designer'));

alter table public.power_items
  add column if not exists filled_by text not null default 'client'
  check (filled_by in ('client','designer'));

comment on column public.checklist_items.filled_by is
  'client = 客戶在 ys-interior 端自己填；designer = 設計師從 work-system ERP 代填';
comment on column public.power_items.filled_by is
  'client = 客戶在 ys-interior 端自己填；designer = 設計師從 work-system ERP 代填';
