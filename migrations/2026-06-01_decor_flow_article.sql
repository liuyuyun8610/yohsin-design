-- ============================================================
-- 裝修流程說明（articles id=2）：放入中古屋翻新 + 新成屋裝修完整流程
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行 (ref: vqxxaameifyvezvozvnf)
-- ※ 內容由截圖整理，請於套用後在客戶端校對（中古屋法條/天數、標「待校對」處）
-- ============================================================
update articles set body = $BODY$
<div class="art-subtitle">室內裝修工程流程（新成屋約 3 個月起跳、中古屋約 5 個月起跳）。非本公司配合之廠商，一律由屋主自行對接。</div>

<div class="art-section-hd">一、中古屋翻新</div>
<div class="art-note"><div class="art-note-title">待校對</div><div class="art-note-list">此段原圖較模糊，法條與天數請務必確認後修正。</div></div>
<p>開工前須申請管委會同意，以及該縣市的「室內裝修許可」：</p>
<ul>
  <li>請務必於認證單位審查設計合約後，向社區／大樓提出室內裝修申請書。</li>
  <li>同時須向當地主管機關通報、取得實質施工許可。</li>
  <li>裝修期間若遭檢舉或糾紛，將依《建築法》相關規定處理（條號待校對）。</li>
  <li>若屋主拒絕配合申請，本公司得無條件解除設計合約，且不承接後續工程。</li>
</ul>

<div class="art-section-hd">二、新成屋裝修</div>
<p>完成室裝許可申請後，即可進行室內裝修，流程如下：</p>

<div class="art-meeting-hd">防水工程</div>
<div class="art-meeting-bd">防水工程為外包，請客戶於裝修前約防水公司配合評估；我們可於後續工序協助防水公司施作。</div>

<div class="art-meeting-hd">開工／拆牆拜拜</div>
<div class="art-meeting-bd">準備鑽牆用的水果、點心拜拜；若有敲牆、鑽孔等動作，依民俗於施工前進行拜拜事宜。</div>

<div class="art-meeting-hd">保護工程</div>
<div class="art-meeting-bd">依管委會規範保護公共區域與梯廳、電梯、樓地板等。</div>
<div class="art-note"><div class="art-note-title">注意事項</div><ol class="art-note-list">
  <li>我們不使用超黏的膠帶，避免日後殘膠難清除；木櫃體周邊會保持乾燥。</li>
  <li>保護材料施工過程可能留下膠痕，天氣濕熱時尤其明顯，屬正常現象。（待校對）</li>
</ol></div>

<div class="art-meeting-hd"><span class="art-day">3–5 日</span>拆除工程</div>
<div class="art-meeting-bd">通常會一次處理較大的破除（敲除水泥牆面等），並盡量保留可用的原始牆面。</div>
<div class="art-note"><div class="art-note-title">注意事項</div><div class="art-note-list">會打鑿、聲音較吵。</div></div>

<div class="art-meeting-hd"><span class="art-day">2–3 日</span>鋁窗工程</div>
<div class="art-meeting-bd">若有拆除窗戶，於拆除工程後由鋁窗廠商進場安裝。</div>

<div class="art-meeting-hd"><span class="art-day">1–2 日</span>鐵工程</div>
<div class="art-meeting-bd">鐵件／空調支架等施作，建議先告知管委會。會打鑿、聲音較吵。（待校對）</div>

<div class="art-meeting-hd"><span class="art-day">1–3 日</span>空調工程（配管）</div>
<div class="art-meeting-bd">配冷媒管路；排水管須做洩水坡度、不可走平。會打鑿、聲音較吵。</div>
<div class="art-note"><div class="art-note-title">注意事項</div><div class="art-note-list">若客人自行承包空調工程，設計師不負責監工與保固。</div></div>

<div class="art-meeting-hd"><span class="art-day">1–3 日</span>全熱工程</div>
<div class="art-meeting-bd">全熱交換機／吊隱式除濕機安裝，安裝後接管線至牆面。（待校對）</div>

<div class="art-meeting-hd"><span class="art-day">1–12 日</span>水電工程</div>
<div class="art-meeting-bd">放樣、進行打鑿、配水管、電管、拉電線、燈線。</div>

<div class="art-meeting-hd"><span class="art-day">30–35 日</span>泥作工程</div>
<div class="art-meeting-bd">先施作全室需要泥作的地方（隔間、地坪等）；完成後牆面需時間乾燥，並於拆除後地坪（粗胚）上彈性水泥防水，防水養護約需 24 小時。（待校對）</div>

<div class="art-meeting-hd"><span class="art-day">1 日</span>粗清工程</div>
<div class="art-meeting-bd">清出粗料垃圾，垃圾車預估一台。</div>

<div class="art-meeting-hd"><span class="art-day">1–3 日（製作約一週）</span>石材工程</div>
<div class="art-meeting-bd">石材品項較多，需先丈量、製作再安裝；前置作業須先確認預留牆面的石材樣式與拼貼方式。</div>

<div class="art-meeting-hd"><span class="art-day">1–3 日</span>除蟲工程</div>
<div class="art-meeting-bd">針對木料、夾板等容易藏蟲的死角，於現場進行除蟲處理，全室各區域與管道一併施作。（待校對）</div>

<div class="art-meeting-hd"><span class="art-day">30–40 日</span>木作工程</div>
<div class="art-meeting-bd">全室隔間、天花、門片、軌道拉門、木作櫃體等。</div>
<div class="art-note"><div class="art-note-title">注意事項</div><div class="art-note-list">客人如自行承包木作工程，須拍照並請廠商確認預留之窗簾盒深度。</div></div>

<div class="art-meeting-hd"><span class="art-day">1 日</span>燈具工程</div>
<div class="art-meeting-bd">木作完成後，由燈具廠商先開好嵌燈孔，供油漆施作。</div>

<div class="art-meeting-hd"><span class="art-day">40–45 日</span>油漆工程</div>
<div class="art-meeting-bd">中古屋會包含補批土、打磨（需先做 AB 膠、批土、打磨整平後才能上漆），天花也需同樣處理。新成屋若建商交屋的牆面本身有波浪，仍需透過油漆工程改善。</div>

<div class="art-meeting-hd"><span class="art-day">5 日</span>系統櫃工程</div>
<div class="art-meeting-bd">系統櫃於木作結束前先安裝，並於油漆後進料、組裝施工。</div>

<div class="art-meeting-hd"><span class="art-day">1–3 日</span>廚具設備</div>
<div class="art-note"><div class="art-note-title">注意事項</div><div class="art-note-list">斜背式抽油煙機若下方要安裝玻璃，需多一筆工資（約 $2000）拆機、裝機，讓玻璃貼合完成後再安裝到位。</div></div>

<div class="art-meeting-hd">衛浴設備（純待貨）</div>
<div class="art-meeting-bd">衛浴設備須於系統櫃工程前到貨並放置於安裝空間。如客戶自行採購，請事先與廠商確認商品完整、拆箱無破損，並於系統櫃工程前安裝完成。（待校對）</div>

<div class="art-meeting-hd"><span class="art-day">1–2 日</span>空調工程（掛機）</div>
<div class="art-meeting-bd">安裝室外機，試機完成後再安裝室內機。</div>

<div class="art-meeting-hd"><span class="art-day">1 日</span>粗清工程</div>
<div class="art-meeting-bd">地板鋪設前，必須將室內垃圾清空、不留垃圾。</div>

<div class="art-meeting-hd"><span class="art-day">1–3 日</span>地板工程</div>
<div class="art-note"><div class="art-note-title">注意事項</div><ol class="art-note-list">
  <li>地板施工完成當日嚴禁踩踏，以防矽利康擠壓變形。</li>
  <li>普通鋪設與石塑地板的工序與養護時間不同。（待校對）</li>
</ol></div>

<div class="art-meeting-hd"><span class="art-day">1 日</span>清潔工程</div>
<div class="art-meeting-bd">清潔工程包含：地面整理、拆除傢俱保護板、清潔地面與層架、灰塵打掃、面材與矽利康整理、窗框玻璃清洗、廚具油網與設備清潔等。公共區域保護於完工後一併拆除清運。</div>
<div class="art-note"><div class="art-note-title">注意事項</div><ol class="art-note-list">
  <li>裝修完成後通常會有落塵，未來二到三週內持續落塵屬正常現象。</li>
  <li>請勿以「長期居住、已穩定」的居家環境標準，來檢視剛完工清潔後的狀態。</li>
</ol></div>

<div class="art-meeting-hd"><span class="art-day">1 日</span>窗簾工程</div>
<div class="art-meeting-bd">須清潔後才能進場。客人如自行承包，須提前和廠商確認預留之窗簾盒深度；窗簾布略微離地是正常現象。</div>
<div class="art-note"><div class="art-note-title">注意事項</div><div class="art-note-list">確認窗簾軌道實際可左右安裝的位置。</div></div>

<div class="art-meeting-hd"><span class="art-day">1 日</span>淨水器工程</div>
<div class="art-meeting-bd">須清潔後才能進場，且須在玻璃工程之後、龍頭已安裝完成的情況下施作。</div>
<div class="art-note"><div class="art-note-title">注意事項</div><ol class="art-note-list">
  <li>請客戶自行採購並聯繫淨水器廠商。</li>
  <li>請於細清前完成安裝。</li>
</ol></div>

<div class="art-meeting-hd"><span class="art-day">1 日</span>熱水器設備</div>
<div class="art-note"><div class="art-note-title">注意事項</div><div class="art-note-list">熱水器安裝前須確認已掛錶（掛錶請屋主自行預約及前往），於清潔後安裝。</div></div>
$BODY$
where id = 2;

notify pgrst, 'reload schema';
