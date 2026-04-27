// LINE Bot photo-push endpoint.
// 由 ys-interior 前端管理介面呼叫，把指定群組的施工照片透過 LINE Bot 推播。
//
// Auth：請求需要帶 X-Admin-Secret header，值需與 ADMIN_PUSH_SECRET env var 一致。
//
// Body (JSON):
//   {
//     "to":         "<groupId|userId|roomId>",      // 必填
//     "photoUrls":  ["https://...jpg", "https://...jpg"],  // 選填，最多 4 張
//     "message":    "文字說明（選填）"
//   }
// 訊息會以「文字 + 圖片群組」一次推送。LINE 單次最多 5 則訊息，所以圖片會限制到 4 張
// 加 1 則文字 = 5 則。
//
// Required env vars:
//   LINE_CHANNEL_ACCESS_TOKEN    (從 LINE Developers Console)
//   ADMIN_PUSH_SECRET            (任一隨機字串，前端要送相同字串)

const LINE_CHANNEL_ACCESS_TOKEN = Deno.env.get('LINE_CHANNEL_ACCESS_TOKEN')!
const ADMIN_PUSH_SECRET = Deno.env.get('ADMIN_PUSH_SECRET')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-admin-secret, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const adminSecret = req.headers.get('x-admin-secret')
  if (!ADMIN_PUSH_SECRET || adminSecret !== ADMIN_PUSH_SECRET) {
    return json({ error: 'Unauthorized' }, 401)
  }

  let body: { to?: string; photoUrls?: string[]; message?: string }
  try { body = await req.json() } catch { return json({ error: 'Bad JSON' }, 400) }

  const to = (body.to ?? '').trim()
  if (!to) return json({ error: 'Missing "to" field' }, 400)

  const messages: unknown[] = []
  if (body.message?.trim()) messages.push({ type: 'text', text: body.message.trim() })
  if (Array.isArray(body.photoUrls)) {
    for (const url of body.photoUrls.slice(0, 4)) {
      if (typeof url !== 'string' || !url.startsWith('https://')) continue
      messages.push({ type: 'image', originalContentUrl: url, previewImageUrl: url })
    }
  }
  if (messages.length === 0) return json({ error: 'No content (need photoUrls or message)' }, 400)

  const lineRes = await fetch('https://api.line.me/v2/bot/message/push', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`,
    },
    body: JSON.stringify({ to, messages }),
  })

  if (!lineRes.ok) {
    const detail = await lineRes.text()
    console.error('LINE API error', lineRes.status, detail)
    return json({ error: 'LINE API error', status: lineRes.status, detail }, 502)
  }

  return json({ ok: true, count: messages.length })
})
