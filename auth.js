/**
 * VoidZone Gaming Cafe - Serverless Edge Authentication Controller (/functions/api/auth.js)
 * Implements HMAC-SHA256 salted PIN verification, Player Sign-Up, Sign-In, and Session Token issuance.
 */
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-VZ-Role, X-VZ-Pin",
  "Content-Type": "application/json;charset=UTF-8"
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: CORS_HEADERS });
}

async function computePinHash(pin, saltHex) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode("VOIDZONE_HMAC_PEPPER_v5"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(`${saltHex}:${pin}`));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function randomHex(bytes = 16) {
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  return Array.from(arr).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function onRequestOptions() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function onRequestPost(context) {
  const { request, env } = context;
  const db = env.DB;
  if (!db) return jsonResponse({ ok: false, error: "D1 database binding (DB) not configured." }, 500);

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ ok: false, error: "Invalid JSON payload." }, 400);
  }

  const action = String(body.action || "signin").toLowerCase();

  if (action === "signup") {
    const phone = String(body.phone || "").replace(/\D/g, "").slice(-10);
    const name = String(body.name || "").trim().slice(0, 40);
    const memberAccount = String(body.member_account || name.toLowerCase().replace(/[^a-z0-9_]/g, "_")).slice(0, 24);
    const riotId = String(body.riot_id || "").trim().slice(0, 40);
    const pin = String(body.pin || "0000").trim();

    if (!/^\d{10}$/.test(phone) || !name || !/^\d{4,6}$/.test(pin)) {
      return jsonResponse({ ok: false, error: "Require valid 10-digit phone, name, and 4-6 digit PIN." }, 400);
    }

    const saltHex = randomHex(16);
    const pinHash = await computePinHash(pin, saltHex);
    const token = randomHex(24);
    const expiresAt = Date.now() + 7 * 86400 * 1000;

    await db.prepare(
      `INSERT INTO members (phone, member_account, name, riot_id, pin_salt, pin_hash, tier, wallet_inr)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, 'Non-Member', 0)
       ON CONFLICT(phone) DO UPDATE SET
         member_account = excluded.member_account,
         name = excluded.name,
         riot_id = excluded.riot_id,
         pin_salt = excluded.pin_salt,
         pin_hash = excluded.pin_hash,
         updated_at = datetime('now')`
    ).bind(phone, memberAccount, name, riotId, saltHex, pinHash).run();

    await db.prepare(
      `INSERT INTO customer_directory (customer_name, phone, membership_tier)
       VALUES (?1, ?2, 'Non-Member')
       ON CONFLICT(customer_name, phone) DO NOTHING`
    ).bind(name, phone).run();

    await db.prepare(
      `INSERT INTO auth_sessions (session_token, phone, role, expires_at)
       VALUES (?1, ?2, 'customer', ?3)`
    ).bind(token, phone, expiresAt).run();

    const member = await db.prepare(
      `SELECT phone, member_account, name, riot_id, tier, wallet_inr, visits, total_hours, spins, shards, drops, streak
       FROM members WHERE phone = ?1`
    ).bind(phone).first();

    return jsonResponse({ ok: true, session_token: token, role: "customer", member }, 201);
  }

  if (action === "signin") {
    const identifier = String(body.identifier || body.phone || "").trim();
    const cleanPhone = identifier.replace(/\D/g, "").slice(-10);
    const cleanAcct = identifier.replace(/^@/, "").toLowerCase();
    const pin = String(body.pin || "0000").trim();

    const member = await db.prepare(
      `SELECT * FROM members WHERE phone = ?1 OR lower(member_account) = ?2 OR lower(name) = ?2 LIMIT 1`
    ).bind(cleanPhone, cleanAcct).first();

    if (!member) {
      return jsonResponse({ ok: false, error: "Account not found." }, 404);
    }

    const computed = await computePinHash(pin, member.pin_salt);
    const isDemoDefault = member.pin_hash === "DEMO_PIN_0000" && pin === "0000";
    if (!isDemoDefault && computed !== member.pin_hash) {
      return jsonResponse({ ok: false, error: "Invalid player PIN." }, 401);
    }

    const token = randomHex(24);
    const expiresAt = Date.now() + 7 * 86400 * 1000;
    await db.prepare(
      `INSERT INTO auth_sessions (session_token, phone, role, expires_at)
       VALUES (?1, ?2, 'customer', ?3)`
    ).bind(token, member.phone, expiresAt).run();

    return jsonResponse({
      ok: true,
      session_token: token,
      role: "customer",
      member: {
        phone: member.phone,
        member_account: member.member_account,
        name: member.name,
        riot_id: member.riot_id,
        tier: member.tier,
        wallet_inr: member.wallet_inr,
        visits: member.visits,
        total_hours: member.total_hours,
        spins: member.spins,
        shards: member.shards,
        drops: member.drops,
        streak: member.streak
      }
    });
  }

  if (action === "staff_unlock") {
    const pin = String(body.pin || "").trim();
    if (pin !== "1234" && pin !== "9999") {
      return jsonResponse({ ok: false, error: "Invalid Staff/Owner security PIN." }, 403);
    }
    const role = pin === "9999" ? "owner" : "staff";
    const token = randomHex(24);
    const expiresAt = Date.now() + 8 * 3600 * 1000;
    await db.prepare(
      `INSERT INTO auth_sessions (session_token, phone, role, expires_at)
       VALUES (?1, ?2, ?3, ?4)`
    ).bind(token, role === "owner" ? "OWNER_9999" : "STAFF_1234", role, expiresAt).run();
    return jsonResponse({ ok: true, session_token: token, role });
  }

  return jsonResponse({ ok: false, error: "Unsupported auth action." }, 400);
}
