-- ============================================================
-- 設計流程說明（articles id=1）：移除 Notion／共用資料夾字眼，改成「客戶專區」
--
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行
-- (project ref: vqxxaameifyvezvozvnf)
--
-- 因為提案/反饋已改在客戶專區進行，不再用 Notion 頁面或共用資料夾。
-- 用 replace() 精準替換三處，不動文章其他內容。
-- ============================================================

update articles set body =
  replace(
  replace(
  replace(body,
    '開啟專案資料夾、NOTION頁面', '開啟專案資料夾與客戶專區'),
    '配置圖到資料夾內', '配置圖到客戶專區'),
    '渲染放置到資料夾方便客戶查看', '渲染上傳到客戶專區方便客戶查看')
where id = 1;

notify pgrst, 'reload schema';
