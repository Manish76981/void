/**
 * VoidZone Gaming Cafe - Serverless Edge Owner Executive Controller (/functions/api/owner.js)
 * Strictly gated by Owner PIN 9999 (X-VZ-Pin: 9999). Returns the complete 13-sheet Excel dataset & P&L telemetry.
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

function verifyOwnerPin(request) {
  const url = new URL(request.url);
  const pin = request.headers.get("X-VZ-Pin") || url.searchParams.get("pin") || "";
  return pin === "9999";
}

export async function onRequestOptions() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function onRequestGet(context) {
  const { request, env } = context;
  if (!verifyOwnerPin(request)) {
    return jsonResponse({
      ok: false,
      error: "RBAC_FORBIDDEN: Exclusive Cafe Owner PIN (9999) required to access executive ledgers, customer directory, and P&L telemetry."
    }, 403);
  }

  const db = env.DB;
  if (!db) return jsonResponse({ ok: false, error: "D1 database binding (DB) not configured." }, 500);

  const [masterLog, snackLog, inventory, walletTopups, opexLedger, customers, stations, tillSnapshots] = await Promise.all([
    db.prepare("SELECT * FROM master_log ORDER BY session_date DESC, tx_id DESC").all(),
    db.prepare("SELECT * FROM snack_log ORDER BY session_date DESC, id DESC").all(),
    db.prepare("SELECT * FROM inventory ORDER BY item_name ASC").all(),
    db.prepare("SELECT * FROM wallet_topups ORDER BY topup_date DESC, id DESC").all(),
    db.prepare("SELECT * FROM opex_ledger ORDER BY expense_date DESC, id DESC").all(),
    db.prepare("SELECT * FROM customer_directory ORDER BY id ASC").all(),
    db.prepare("SELECT * FROM stations ORDER BY station_id ASC").all(),
    db.prepare("SELECT * FROM cash_drawer_ledger ORDER BY snapshot_ts DESC").all()
  ]);

  const ml = masterLog.results || [];
  const sl = snackLog.results || [];
  const op = opexLedger.results || [];

  const gameplayRev = ml.reduce((s, r) => s + Number(r.game_charges || 0), 0);
  const fbRev = sl.reduce((s, r) => s + Number(r.total_cost || 0), 0);
  const totalOpex = op.reduce((s, r) => s + Number(r.amount_inr || 0), 0);
  const trueNetProfit = (gameplayRev + fbRev) - totalOpex;

  return jsonResponse({
    ok: true,
    role: "owner",
    executive_summary: {
      gameplay_revenue_inr: gameplayRev,
      fb_revenue_inr: fbRev,
      total_opex_inr: totalOpex,
      true_net_profit_inr: trueNetProfit
    },
    sheets: {
      master_log: ml,
      snack_log: sl,
      inventory: inventory.results || [],
      wallet_topups: walletTopups.results || [],
      opex_ledger: op,
      customer_directory: customers.results || [],
      stations: stations.results || [],
      cash_drawer_ledger: tillSnapshots.results || []
    }
  });
}

export async function onRequestPost(context) {
  const { request, env } = context;
  if (!verifyOwnerPin(request)) {
    return jsonResponse({
      ok: false,
      error: "RBAC_FORBIDDEN: Exclusive Cafe Owner PIN (9999) required for administrative ledger mutations."
    }, 403);
  }

  const db = env.DB;
  if (!db) return jsonResponse({ ok: false, error: "D1 database binding (DB) not configured." }, 500);

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ ok: false, error: "Invalid JSON payload." }, 400);
  }

  const type = String(body.type || "");
  if (type === "opex") {
    const expDate = String(body.expense_date || new Date().toISOString().slice(0, 10));
    const cat = String(body.category || "Electricity");
    const desc = String(body.description || "Operating Expense");
    const amt = Math.max(0, Number(body.amount_inr || 0));
    await db.prepare(
      `INSERT INTO opex_ledger (expense_date, category, description, amount_inr) VALUES (?1, ?2, ?3, ?4)`
    ).bind(expDate, cat, desc, amt).run();
    return jsonResponse({ ok: true, recorded: "opex", amount_inr: amt }, 201);
  }

  if (type === "wallet_topup") {
    const topDate = String(body.topup_date || new Date().toISOString().slice(0, 10));
    const cname = String(body.customer_name || "Customer");
    const phone = String(body.phone || "No Phone");
    const deposit = Math.max(0, Number(body.deposit_amount || 0));
    const method = String(body.payment_method || "UPI");
    const bonusPct = Number(body.bonus_pct || 0);
    const bonusAmt = Math.round(deposit * bonusPct);
    const totalCredited = deposit + bonusAmt;

    await db.prepare(
      `INSERT INTO wallet_topups (topup_date, customer_name, phone, deposit_amount, payment_method, bonus_pct, bonus_amount, total_credited)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`
    ).bind(topDate, cname, phone, deposit, method, bonusPct, bonusAmt, totalCredited).run();
    return jsonResponse({ ok: true, recorded: "wallet_topup", total_credited: totalCredited }, 201);
  }

  return jsonResponse({ ok: false, error: "Unsupported owner mutation type." }, 400);
}
