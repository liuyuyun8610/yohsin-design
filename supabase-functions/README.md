# LINE Bot Edge Functions

Two Supabase Edge Functions powering the "把施工照片推到客戶 LINE 群組" feature.

## `line-webhook`

LINE servers POST events here when:
- Bot is added to a group (auto-replies the group ID)
- Anyone types `/id` or `/groupid` in a chat with the bot (replies the chat ID)

Verifies request authenticity via the LINE channel secret (HMAC-SHA256 over raw body, base64-compared with `x-line-signature` header).

**Required env vars:**
- `LINE_CHANNEL_SECRET`
- `LINE_CHANNEL_ACCESS_TOKEN`

**Webhook URL to paste into LINE Developers Console** (after deploy):

```
https://vqxxaameifyvezvozvnf.supabase.co/functions/v1/line-webhook
```

## `line-push`

Called from ys-interior admin UI. Sends a `text + image…` message to a LINE group/user via LINE Messaging API push.

Auth via shared secret in `X-Admin-Secret` header (env: `ADMIN_PUSH_SECRET`).

**Required env vars:**
- `LINE_CHANNEL_ACCESS_TOKEN`
- `ADMIN_PUSH_SECRET` (any random string; front-end must send the same value)

**Endpoint** (after deploy):

```
https://vqxxaameifyvezvozvnf.supabase.co/functions/v1/line-push
```

**Request shape:**

```json
{
  "to": "<groupId>",
  "photoUrls": ["https://...jpg"],
  "message": "本日工程進度（10/27）"
}
```

## Deploy steps (one-time)

1. Supabase Dashboard → Edge Functions → **Deploy a new function**
2. Function name: `line-webhook` → paste `line-webhook/index.ts` → Deploy
3. Function name: `line-push` → paste `line-push/index.ts` → Deploy
4. Edge Functions → **Manage secrets**:
   - `LINE_CHANNEL_SECRET` = (channel secret)
   - `LINE_CHANNEL_ACCESS_TOKEN` = (long-lived access token)
   - `ADMIN_PUSH_SECRET` = (random string you generate; pasted into ys-interior admin UI)
5. LINE Developers Console → Messaging API → set Webhook URL to the line-webhook URL above; turn on "Use webhook"

---

## `ai-preview`

「AI 生活情境預覽」功能後端（客戶端效果圖頁）。一支函式包辦：看圖解說、生成情境預覽圖（fal nano-banana/edit）、存圖、每日次數限制、危險詞攔截、後台開關與查看紀錄。

Auth：客戶動作（explain / generate / list）帶 anon `Authorization: Bearer`；後台動作（settings / set / flag）另帶 `X-Admin-Secret`（沿用 `ADMIN_PUSH_SECRET`）。

**Required env vars:**
- `FAL_KEY`（= su-ai-render 那把 fal.ai 金鑰）
- `ADMIN_PUSH_SECRET`（與 line-push 同一把，已設過就免）
- `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` — Supabase 自動注入，**不用手動設**

需先在 SQL Editor 跑 `migrations/2026-06-06_ai_scene_preview.sql` 建表。

**Endpoint**（deploy 後）：
```
https://vqxxaameifyvezvozvnf.supabase.co/functions/v1/ai-preview
```

Deploy：Dashboard → Edge Functions → Deploy a new function → 名稱 `ai-preview` → 貼上 `ai-preview/index.ts` → Deploy；再到 Manage secrets 加 `FAL_KEY`。
