-- 1. articles 加兩欄
ALTER TABLE articles
  ADD COLUMN IF NOT EXISTS requires_signature boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS signature_label text;

-- 2. 客戶簽名紀錄表
CREATE TABLE IF NOT EXISTS client_signatures (
  id bigserial PRIMARY KEY,
  client_id bigint NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  article_id bigint NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  signature_url text NOT NULL,
  agreement_text text,
  signed_at timestamptz DEFAULT now(),
  UNIQUE(client_id, article_id)
);

-- 3. 通知 PostgREST 重載 schema cache
NOTIFY pgrst, 'reload schema';
