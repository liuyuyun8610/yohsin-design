-- ============================================================
-- 施工認知落差注意事項（articles id=3）：放入開工前必讀內容
-- 在 ys-interior Supabase Dashboard > SQL Editor 執行 (ref: vqxxaameifyvezvozvnf)
-- 內容來自「施工認知落差注意事項.pdf」，用文章既有樣式排版。
-- ============================================================
update articles set body = $BODY$
<div class="art-note"><div class="art-note-title">核心觀念</div><div class="art-note-list">手工非機器，修補優於換新。工程施作受環境、材料特性、人為手作等因素影響，必然會產生些許公差或不完美，此為無法避免的「正常現象」。以下列出裝修常見的認知落差，請務必詳閱，以確保工程順利進行。</div></div>

<div class="art-section-hd">第一部分　責任歸屬與前置作業</div>

<div class="art-meeting-hd">室內裝修許可與法規</div>
<ul>
  <li><strong>申請必要性：</strong>涉及改變建築結構、隔間、天花板，或高度超過 1.2 公尺的固定隔屏，依法須申請室內裝修許可。</li>
  <li><strong>拒絕申請之風險：</strong>若業主堅持不申請，需自行承擔所有罰金，本公司亦有權無條件解除合約。</li>
</ul>

<div class="art-meeting-hd">鄰里協調與糾紛</div>
<ul>
  <li><strong>業主責任：</strong>裝修過程若遇總幹事、主委或鄰居抗議與為難（常見於老屋），請業主務必出面協助解決，請勿讓設計公司單獨面對。</li>
  <li><strong>鄰損風險：</strong>拆除時若樓下鄰居反應牆壁龜裂（通常非結構問題），為維護鄰里關係，建議業主負擔油漆修補費用以安撫對方。</li>
</ul>

<div class="art-meeting-hd">保護工程與損傷認定（重要）</div>
<ul>
  <li><strong>無法完全避免損傷：</strong>施工中無法完全避免損傷，輕微損傷屬正常現象。</li>
  <li><strong>修補原則：</strong>受損部分以「美容修補」為主要處理方式；除非損壞程度導致不可使用，才會考慮更換。</li>
  <li><strong>現有物件風險：</strong>若保留現場原有物件（如廚具、鋁窗、地磚、大門），廠商會盡力保護，但若意外損傷（不影響功能前提下），同樣以美容修補為主。裝修工程有許多進出工種，些微刮傷難免，我們也會盡力修復。</li>
</ul>

<div class="art-section-hd">第二部分　各項工程常見狀況</div>

<div class="art-meeting-hd">🚧 拆除工程：隱藏的追加項目</div>
<ul>
  <li><strong>拆開才知道的問題：</strong>拆除後可能發現事前無法察覺的狀況，需額外報價（追加預算），例如：地面高低差嚴重、額外出現的樑柱／牆體或管線、隱藏在舊裝潢內的建築廢棄物、拆除後發現的漏水（需由業主找專業防水處理）。</li>
  <li><strong>隱蔽物損傷：</strong>誤傷隱藏在牆內的水電管路屬難免，修補費用將另行報價。</li>
</ul>

<div class="art-meeting-hd">🪵 木作與系統櫃：材質特性與公差</div>
<ul>
  <li><strong>色差與紋路：</strong>天然木皮或板材因批次不同，會有色差或紋路走向不一致。</li>
  <li><strong>環境影響：</strong>木製品會因氣溫濕度變化，短時間內出現翹曲或門片縫隙改變，屬正常現象。若施作木門，請於完工後保持室內濕度；若門片因長期未入住而膨脹受潮變形屬正常，保持除濕機開啟即可。</li>
  <li><strong>縫隙問題：</strong>因現場天地壁結構非完全垂直水平，櫃體與牆面接合處可能有些許縫隙，會以填縫板／矽利康收尾。</li>
  <li><strong>氣味：</strong>系統櫃完工初期會散發板材氣味，屬正常現象。</li>
  <li><strong>系統櫃限制：</strong>系統櫃依靠固定結構，無法像木作隨意造型；部分非外露面（如開孔處、櫃體背面）無封邊處理為正常。</li>
</ul>

<div class="art-meeting-hd">🎨 油漆工程：手作痕跡與修補</div>
<ul>
  <li><strong>手作痕跡：</strong>牆面塗刷皆為手工，近看出現刷痕、滾輪痕跡為正常現象。</li>
  <li><strong>修補色差：</strong>油漆修補後會有一定程度的光澤色差；建議裝潢一年後以「整面重刷」代替局部修補。</li>
  <li><strong>裂縫：</strong>異材質交接處（如木作與水泥牆）受地震或熱脹冷縮影響，容易產生裂縫。</li>
</ul>

<div class="art-meeting-hd">❄️ 空調工程：效能與維修</div>
<ul>
  <li><strong>效能說明：</strong>居家環境非實驗室，無法保證 100% 效能；冷房速度、風聲大小因人而異。</li>
  <li><strong>責任範圍：</strong>設計公司負責「安裝施工」，不負責「功能教學」；設備故障請洽原廠保固。</li>
  <li><strong>維修孔限制：</strong>吊隱式冷氣維修孔為手工開孔，無法精準如機器切割；若未來換機尺寸不同，可能需破壞天花板。</li>
</ul>

<div class="art-meeting-hd">💡 水電與燈光：感受差異</div>
<ul>
  <li><strong>開關面板：</strong>牆面不平整可能導致面板有些微縫隙；生產公差可能讓按鍵手感不同。</li>
  <li><strong>燈光感受：</strong>亮度與刺眼度屬個人主觀感受。</li>
  <li><strong>LED 閃爍：</strong>使用高耗電設備（如電陶爐）可能導致 LED 燈些微閃爍，非施工不良。</li>
</ul>

<div class="art-meeting-hd">🪟 地板、窗簾與玻璃</div>
<ul>
  <li><strong>木地板踏感：</strong>超耐磨地板多採「漂浮式施工」，踩踏時有輕微浮動感（不踏實感）為正常現象。</li>
  <li><strong>窗簾漏光：</strong>窗簾無法達到 100% 遮光，四周縫隙漏光屬正常。</li>
  <li><strong>玻璃色澤：</strong>普通玻璃或優白玻璃，側面看均會呈現綠色。</li>
</ul>

<div class="art-section-hd">完工後的保養須知</div>
<ul>
  <li><strong>矽利康發霉：</strong>矽利康屬消耗品，即便防霉款式，隨時間與濕度影響仍會發霉或收縮。</li>
  <li><strong>自然耗損：</strong>深色檯面吃色、水龍頭水垢、濾網髒污等，皆需業主定期保養，非工程瑕疵。</li>
</ul>
$BODY$
where id = 3;

notify pgrst, 'reload schema';
