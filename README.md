# VoidZone Gaming Cafe – Production Deployment Guide (v5.2)

## Why Did "VoidZone Edge API Ready" Appear?
When deployed to **Cloudflare Workers** (`*.workers.dev`), if static assets are not configured or if `worker.js` was deployed without asset bindings, the worker previously returned a plain-text API status message.

In **v5.2**, `worker.js` is now **100% self-contained**: it embeds the complete VoidZone frontend application and automatically serves `index.html` on `/` or any browser route, while simultaneously routing all `/api/*` endpoints!

---

## Deployment Options (Choose Either):

### Option A: Cloudflare Workers (Recommended for `workers.dev`)
1. In your Cloudflare Dashboard, go to **Workers & Pages** -> your Worker (`voidzone-gaming-cafe`).
2. Click **Edit code** (or **Quick Edit**).
3. Open `worker.js` from this zip, select all (`Ctrl+A`), copy, and paste into the editor.
4. Click **Deploy**.
5. Visit `https://voidzone-gaming-cafe.manishharyan.workers.dev/` — the full website loads immediately!

### Option B: Cloudflare Pages (Drag & Drop)
1. Go to **Workers & Pages** -> **Create application** -> **Pages** -> **Upload assets**.
2. Name your project `voidzone-gaming-cafe`.
3. Drag and drop the unzipped folder containing `index.html`.
4. Click **Deploy site**.
