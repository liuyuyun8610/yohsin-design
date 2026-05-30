-- ============================================================
-- client_article_notes：每位客戶 × 每篇切結書的「設計師備註」
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行
-- (project ref: vqxxaameifyvezvozvnf)
--
-- 動機：客戶有時殺價，設計師會以「免費替他監工空調」等條件作為優惠。
--      需要在該客戶的「自行找空調外包」切結書下，放一段只給這位客戶看到的備註。
--      備註是「每客戶各自不同」，所以做成 (client_id, article_id) 對應一段文字。
--      安全姿態比照既有的 client_signatures（anon 可讀寫，前端以 client_id 過濾）。
-- ============================================================

create table if not exists client_article_notes (
  id bigserial primary key,
  client_id bigint not null references clients(id) on delete cascade,
  article_id bigint not null references articles(id) on delete cascade,
  note text,
  updated_at timestamptz default now(),
  unique(client_id, article_id)
);

-- 通知 PostgREST 重載 schema cache
notify pgrst, 'reload schema';
