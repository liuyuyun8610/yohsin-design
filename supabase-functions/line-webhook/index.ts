// LINE Bot webhook receiver.
// 收 LINE 推來的事件，主要功能：
//   - 機器人被加進新群組時自動回覆群組 ID
//   - 任何使用者在群組打 /id 或 /groupid → 回覆當前群組 ID
// 群組 ID 拿到後就能設定到對應專案，給 line-push function 用。
//
// Required env vars (Supabase Dashboard → Edge Functions → Manage secrets):
//   LINE_CHANNEL_SECRET          (從 LINE Developers Console)
//   LINE_CHANNEL_ACCESS_TOKEN    (同上)

const LINE_CHANNEL_SECRET = Deno.env.get('LINE_CHANNEL_SECRET')!
const LINE_CHANNEL_ACCESS_TOKEN = Deno.env.get('LINE_CHANNEL_ACCESS_TOKEN')!

// Verify LINE webhook signature (HMAC-SHA256 of raw body using channel secret).
// LINE specifies the signature is base64-encoded.
async function verifySignature(rawBody: string, signature: string): Promise<boolean> {
  if (!signature) return false
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(LINE_CHANNEL_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sigBytes = await crypto.subtle.sign('HMAC', key, enc.encode(rawBody))
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBytes)))
  return sigB64 === signature
}

async function lineReply(replyToken: string, messages: unknown[]): Promise<void> {
  await fetch('https://api.line.me/v2/bot/message/reply', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`,
    },
    body: JSON.stringify({ replyToken, messages }),
  })
}

Deno.serve(async (req) => {
  // Health check / verify URL
  if (req.method === 'GET') {
    return new Response('LINE webhook OK', { status: 200 })
  }
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const rawBody = await req.text()
  const signature = req.headers.get('x-line-signature') ?? ''
  if (!(await verifySignature(rawBody, signature))) {
    return new Response('Invalid signature', { status: 401 })
  }

  let payload: { events?: any[] }
  try { payload = JSON.parse(rawBody) } catch { return new Response('Bad JSON', { status: 400 }) }

  for (const event of payload.events ?? []) {
    try {
      // (1) Bot joined a group → 自動回 group ID
      if (event.type === 'join') {
        const id = event.source?.groupId ?? event.source?.roomId ?? ''
        await lineReply(event.replyToken, [{
          type: 'text',
          text: `已加入！\n此群組 ID：\n${id}\n\n稍後請把這個 ID 提供給管理員設定到對應專案，之後就會收到該專案的進度照片。\n\n（也可以隨時在群組打 /id 查詢）`,
        }])
      }
      // (2) User types /id or /groupid → 回 group/user ID
      else if (event.type === 'message' && event.message?.type === 'text') {
        const text = String(event.message.text ?? '').trim().toLowerCase()
        if (text === '/id' || text === '/groupid') {
          const src = event.source ?? {}
          const id = src.groupId || src.roomId || src.userId || ''
          const label = src.type === 'group' ? '群組' : src.type === 'room' ? '多人聊天室' : '個人'
          await lineReply(event.replyToken, [{
            type: 'text',
            text: `${label} ID：\n${id}`,
          }])
        }
      }
    } catch (err) {
      console.error('Error handling event', err)
    }
  }

  return new Response('OK', { status: 200 })
})
