-- ============================================================
-- project_docs 加 customer_signature_name 欄位
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行
-- (project ref: vqxxaameifyvezvozvnf)
--
-- 動機：客戶簽合約時除地址、電話外，需填「立契約書人全名」（法定全名），
--      讓 ERP 下載的已簽署版「甲方」欄位呈現正式名稱（取代登入帳號名）。
-- ============================================================

alter table public.project_docs
  add column if not exists customer_signature_name text;

comment on column public.project_docs.customer_signature_name is
  '客戶簽署時填的法定全名（合約用）/ 圖紙確認簽名（也可共用）';
