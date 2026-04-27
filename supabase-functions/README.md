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
