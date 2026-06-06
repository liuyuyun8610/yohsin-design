// AI 生活情境預覽 — Edge Function（客戶端「效果圖」頁專用）
//
// 一支函式包辦：
//   action='explain'   看圖 → 溫暖的中文解說（fal any-llm/vision）
//   action='generate'  看圖 → 生一張情境預覽圖（fal nano-banana/edit），存進 storage + 寫紀錄
//   action='list'      讀某客戶的歷史預覽（客戶看自己的 / 後台查看）
//   action='settings'  讀某客戶的開關設定（後台，需 x-admin-secret）
//   action='set'       設定開關 + 每日次數（後台，需 x-admin-secret）
//   action='flag'      標記某張「加入正式討論紀錄」（後台，需 x-admin-secret）
//
// 安全：金鑰只留伺服器；情境提示嚴格限制「只改光線/生活感、不動格局/櫃體/尺寸/風格」；
//       自訂輸入若涉及正式設計變更 → 不生圖，回提示請與設計師討論；
//       每位客戶預設關閉，要設計師逐個打開並設每日上限。
//
// 需要的 env（Supabase 已自動注入 SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY）：
//   FAL_KEY            （= su-ai-render 那把 fal.ai 金鑰）
//   ADMIN_PUSH_SECRET  （後台動作用，與 line-push 同一把）

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FAL_KEY = Deno.env.get('FAL_KEY')!
const ADMIN_SECRET = Deno.env.get('ADMIN_PUSH_SECRET') || ''
const SB_URL = Deno.env.get('SUPABASE_URL')!
const SB_SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const EDIT_MODEL = 'fal-ai/nano-banana/edit'                 // 指令式編輯：保留構圖、只改光線/氛圍
const VISION_MODEL = 'fal-ai/any-llm/vision'                 // 看圖 → 文字
const VISION_LLM = 'google/gemini-2.5-flash'

const STORAGE_BUCKET = 'photos'
const STORAGE_FOLDER = 'ai-previews'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-admin-secret, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', ...corsHeaders } })

const sb = createClient(SB_URL, SB_SERVICE, { auth: { persistSession: false } })

// 台灣（UTC+8）當日 00:00 對應的 UTC 時刻 — 每日次數以台灣日界線重置
function twDayStartISO(): string {
  const tw = new Date(Date.now() + 8 * 3600 * 1000)
  tw.setUTCHours(0, 0, 0, 0)
  return new Date(tw.getTime() - 8 * 3600 * 1000).toISOString()
}

// ── 預設情境（label 由伺服器決定，前端不可竄改）──
const SCENES: Record<string, { label: string; prompt: string }> = {
  morning:  { label: '早晨自然光', prompt: 'Relight the scene as soft early-morning natural daylight coming through the windows, gentle warm sunrise glow, fresh and calm mood.' },
  evening:  { label: '傍晚暖光',   prompt: 'Relight the scene as warm late-afternoon golden-hour sunlight, cozy amber tones, soft long shadows.' },
  night:    { label: '晚上開燈',   prompt: 'Change to night time: turn on the interior lights (lamps, ceiling lights, indirect lighting), warm cozy artificial glow, dark sky outside the windows.' },
  cozy:     { label: '加入生活感', prompt: 'Add subtle lived-in touches such as a few books, a folded throw blanket, a small plant or a cup on a surface. Keep it tasteful and minimal, do not clutter.' },
  dining:   { label: '餐桌使用情境', prompt: 'Show the dining area gently in use: simple tableware or a tea set on the dining table, suggesting a warm everyday meal moment.' },
  kids:     { label: '有小孩的日常', prompt: 'Add gentle hints of a family with young children, such as one small soft toy. Keep it subtle and tasteful.' },
  pets:     { label: '有寵物的日常', prompt: 'Add one friendly calm pet (a dog or a cat) resting naturally in the space, suggesting cozy daily life with pets.' },
  brighter: { label: '畫面更明亮', prompt: 'Make the overall image brighter, airier and fresher with more natural light, without overexposing or washing out detail.' },
}

// 嚴格保留設計本體；只允許動光線 / 時間 / 輕微生活道具
const BASE_RULES =
  'You are creating a lifestyle PREVIEW of a finished interior design photo for the client. ' +
  'STRICT RULES — you MUST keep them all: do NOT change the room layout, walls, windows, doors, ceiling, floor, ' +
  'built-in cabinets, the furniture pieces or their positions, the materials or the colors of fixed elements, ' +
  'and do NOT change the camera angle or composition. It must clearly be the SAME room. ' +
  'ONLY change what the instruction asks (lighting / time of day / small lived-in props). ' +
  'Photorealistic, natural, high quality. No text, no watermark, no border. Instruction: '

// 自訂輸入若涉及正式設計變更 → 擋下
const BLOCK_RE = /(拆|打掉|敲掉|拆除|移除牆|移牆|挖|改格局|換格局|格局調整|動線|隔間|打通|改尺寸|放大空間|縮小|變大|加大|改櫃|換櫃|拆櫃|加櫃|改門|改窗|挑高|樓中樓|夾層|改風格|換風格|工業風|北歐風|侘寂風|改成.{0,4}風|重新設計|重做|整個改|全部改|加蓋|增建|換地板|換磁磚|換建材|改建材|敲牆)/

const pickImg = (d: any) => d?.images?.[0]?.url || d?.image?.url || d?.url || null

async function falRun(model: string, input: unknown) {
  const r = await fetch(`https://fal.run/${model}`, {
    method: 'POST',
    headers: { 'Authorization': `Key ${FAL_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  })
  if (!r.ok) throw new Error(`${model} ${r.status}: ${(await r.text().catch(() => '')).slice(0, 300)}`)
  return r.json()
}

function isAdmin(req: Request) {
  return ADMIN_SECRET && req.headers.get('x-admin-secret') === ADMIN_SECRET
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  let body: any
  try { body = await req.json() } catch { return json({ error: 'bad json' }, 400) }
  const action = body?.action

  try {
    // ───── 看圖解說 ─────
    if (action === 'explain') {
      if (!body.imageUrl) return json({ error: '缺少 imageUrl' }, 400)
      const out = await falRun(VISION_MODEL, {
        model: VISION_LLM,
        image_urls: [body.imageUrl],
        system_prompt:
          '你是一位溫暖、專業的台灣室內設計師，正在為客戶解說一張空間效果圖。語氣親切、簡潔、有溫度，不要像機器人，不要分段標題、不要條列。用 100~140 字、2~3 句話，自然帶到：設計重點、空間氛圍、材質感、動線或生活情境其中幾項。只描述畫面看得到的，不要捏造機能或建材，不要提到「這是 AI」。直接輸出說明文字。',
        prompt: '請用溫暖口吻幫客戶解說這張空間效果圖。',
        temperature: 0.6,
        max_tokens: 400,
      })
      const text = (out?.output || '').trim()
      if (!text) return json({ error: 'AI 沒有回覆內容' }, 502)
      return json({ text })
    }

    // ───── 生成情境預覽圖 ─────
    if (action === 'generate') {
      const clientId = Number(body.clientId)
      if (!clientId) return json({ error: '缺少 clientId' }, 400)
      if (!body.sourceImageUrl) return json({ error: '缺少原圖' }, 400)

      // 開關 + 每日上限
      const { data: setting } = await sb.from('ai_preview_settings').select('*').eq('client_id', clientId).maybeSingle()
      if (!setting || !setting.enabled) {
        return json({ blocked: true, reason: 'disabled', message: '此功能尚未對你開放，若想試用情境預覽，請與設計師說一聲 🙂' }, 200)
      }
      const limit = Number(setting.daily_limit) || 3
      const { count } = await sb.from('ai_scene_previews').select('id', { count: 'exact', head: true })
        .eq('client_id', clientId).gte('created_at', twDayStartISO())
      const used = count || 0
      if (used >= limit) {
        return json({ blocked: true, reason: 'limit', message: `今天的 AI 情境預覽次數已用完（每日 ${limit} 次），明天再回來看看吧 🌙` }, 200)
      }

      // 組提示：預設情境 or 自訂
      const sceneKey = String(body.sceneKey || 'custom')
      let instruction = ''
      let sceneLabel = ''
      if (sceneKey === 'custom') {
        const custom = String(body.customPrompt || '').trim()
        if (!custom) return json({ error: '請輸入想看的情境' }, 400)
        if (BLOCK_RE.test(custom)) {
          return json({
            blocked: true, reason: 'design-change',
            message: '這類調整屬於正式設計變更（例如改格局、拆除櫃體、改尺寸或整體風格），請與設計師討論後再進行 🙂\n你可以改成想看的「生活情境」或「光線氛圍」，例如：早晨光線、傍晚暖光、餐桌上有筆電。',
          }, 200)
        }
        // 把自訂需求收斂成「只加生活情境、不動設計」
        instruction = `Add or adjust ONLY the following everyday-life scenario into the room, without changing any design: ${custom}`
        sceneLabel = custom.length > 16 ? custom.slice(0, 16) + '…' : custom
      } else {
        const s = SCENES[sceneKey]
        if (!s) return json({ error: '未知的情境' }, 400)
        instruction = s.prompt
        sceneLabel = s.label
      }

      // 生圖
      const edited = await falRun(EDIT_MODEL, {
        prompt: BASE_RULES + instruction,
        image_urls: [body.sourceImageUrl],
        num_images: 1,
        output_format: 'jpeg',
      })
      const falUrl = pickImg(edited)
      if (!falUrl) return json({ error: 'AI 未回傳圖片' }, 502)

      // 下載 → 上傳到 storage（fal.media 是暫時網址，要落地）
      const imgRes = await fetch(falUrl)
      if (!imgRes.ok) return json({ error: '下載生成圖失敗' }, 502)
      const bytes = new Uint8Array(await imgRes.arrayBuffer())
      const path = `${STORAGE_FOLDER}/${clientId}/${Date.now()}_${Math.random().toString(36).slice(2)}.jpg`
      const { error: upErr } = await sb.storage.from(STORAGE_BUCKET).upload(path, bytes, { contentType: 'image/jpeg', upsert: false })
      if (upErr) return json({ error: '存圖失敗：' + upErr.message }, 500)
      const { data: pub } = sb.storage.from(STORAGE_BUCKET).getPublicUrl(path)
      const resultUrl = pub.publicUrl

      // 寫紀錄
      const { data: row, error: insErr } = await sb.from('ai_scene_previews').insert({
        client_id: clientId,
        project_id: body.projectId ? Number(body.projectId) : null,
        source_image_url: body.sourceImageUrl,
        source_drawing_id: body.sourceDrawingId ? String(body.sourceDrawingId) : null,
        scene_key: sceneKey,
        scene_label: sceneLabel,
        prompt: sceneKey === 'custom' ? String(body.customPrompt || '') : instruction,
        result_image_url: resultUrl,
      }).select().single()
      if (insErr) return json({ error: '寫紀錄失敗：' + insErr.message }, 500)

      return json({ url: resultUrl, id: row.id, sceneLabel, remaining: Math.max(0, limit - used - 1) })
    }

    // ───── 讀歷史 ─────
    if (action === 'list') {
      const clientId = Number(body.clientId)
      if (!clientId) return json({ error: '缺少 clientId' }, 400)
      const q = sb.from('ai_scene_previews').select('*').eq('client_id', clientId).order('created_at', { ascending: false })
      if (body.sourceDrawingId) q.eq('source_drawing_id', String(body.sourceDrawingId))
      const { data } = await q
      return json({ items: data || [] })
    }

    // ───── 後台：讀設定 ─────
    if (action === 'settings') {
      if (!isAdmin(req)) return json({ error: 'Unauthorized' }, 401)
      const clientId = Number(body.clientId)
      if (!clientId) return json({ error: '缺少 clientId' }, 400)
      const { data } = await sb.from('ai_preview_settings').select('*').eq('client_id', clientId).maybeSingle()
      const { count } = await sb.from('ai_scene_previews').select('id', { count: 'exact', head: true })
        .eq('client_id', clientId).gte('created_at', twDayStartISO())
      return json({ enabled: data?.enabled ?? false, daily_limit: data?.daily_limit ?? 3, used_today: count || 0 })
    }

    // ───── 後台：寫設定 ─────
    if (action === 'set') {
      if (!isAdmin(req)) return json({ error: 'Unauthorized' }, 401)
      const clientId = Number(body.clientId)
      if (!clientId) return json({ error: '缺少 clientId' }, 400)
      const enabled = !!body.enabled
      const daily_limit = Math.max(1, Math.min(30, Number(body.dailyLimit) || 3))
      const { error } = await sb.from('ai_preview_settings')
        .upsert({ client_id: clientId, enabled, daily_limit, updated_at: new Date().toISOString() }, { onConflict: 'client_id' })
      if (error) return json({ error: error.message }, 500)
      return json({ ok: true, enabled, daily_limit })
    }

    // ───── 後台：標記加入正式討論 ─────
    if (action === 'flag') {
      if (!isAdmin(req)) return json({ error: 'Unauthorized' }, 401)
      const { error } = await sb.from('ai_scene_previews').update({ in_discussion: !!body.inDiscussion }).eq('id', body.id)
      if (error) return json({ error: error.message }, 500)
      return json({ ok: true })
    }

    return json({ error: '未知 action' }, 400)
  } catch (e) {
    return json({ error: (e as Error)?.message || '未知錯誤' }, 500)
  }
})
