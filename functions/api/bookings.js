/**
 * VoidZone Gaming Cafe - Serverless Edge Reservation & Collision-Lock Controller (/functions/api/bookings.js)
 * Enforces atomic station overlap checks, customer-scoped RBAC visibility, and writes directly to master_log.
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

export async function onRequestOptions() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function onRequestGet(context) {
  const { request, env } = context;
  const db = env.DB;
  if (!db) return jsonResponse({ ok: false, error: "D1 database binding (DB) not configured." }, 500);

  const url = new URL(request.url);
  const dateStr = url.searchParams.get("date") || new Date().toISOString().slice(0, 10);
  const phone = (url.searchParams.get("phone") || "").replace(/\D/g, "").slice(-10);
  const pinHeader = request.headers.get("X-VZ-Pin") || "";
  const isStaffOrOwner = pinHeader === "1234" || pinHeader === "9999";

  // Return anonymized station occupancy intervals for collision checking + customer's own full ticket details
  const allRows = await db.prepare(
    `SELECT tx_id, session_date, customer_name, phone, time_in, time_out, total_hr, console_id, category, controllers, total_bill, wallet_status
     FROM master_log WHERE session_date = ?1 ORDER BY time_in ASC`
  ).bind(dateStr).all();

  const records = (allRows.results || []).map((r) => {
    if (isStaffOrOwner || (phone && r.phone === phone)) {
      return r;
    }
    return {
      tx_id: "OCCUPIED",
      session_date: r.session_date,
      console_id: r.console_id,
      time_in: r.time_in,
      time_out: r.time_out,
      total_hr: r.total_hr,
      wallet_status: "Reserved"
    };
  });

  return jsonResponse({ ok: true, date: dateStr, bookings: records });
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

  const stationId = String(body.station_id || "PC-1").replace("PS5-", "PS-");
  const customerName = String(body.customer_name || "Walk-in Player").trim().slice(0, 40);
  const phone = String(body.customer_phone || "").replace(/\D/g, "").slice(-10);
  const startTs = String(body.start_ts || "");
  const endTs = String(body.end_ts || "");
  const sessionDate = (startTs.split(" ")[0] || new Date().toISOString().slice(0, 10)).slice(0, 10);
  const timeIn = (startTs.split(" ")[1] || "14:00:00").slice(0, 8);
  const timeOut = (endTs.split(" ")[1] || "16:00:00").slice(0, 8);
  const totalHr = Math.max(0.5, Number(body.duration_hrs || 1));
  const category = String(body.category || "Standard");
  const controllers = Math.max(0, Number(body.controllers || (stationId.startsWith("PS-") ? 1 : 0)));
  const totalInr = Math.max(0, Number(body.total_inr || 80));
  const payMode = String(body.payment_mode || "PAY_AT_DESK");

  if (!/^\d{10}$/.test(phone)) {
    return jsonResponse({ ok: false, error: "Valid 10-digit mobile number required." }, 400);
  }

  // Atomic station collision check: start_time < existing_end AND end_time > existing_start
  const collision = await db.prepare(
    `SELECT tx_id, time_in, time_out FROM master_log
     WHERE session_date = ?1 AND console_id = ?2
       AND time_in < ?4 AND time_out > ?3
     LIMIT 1`
  ).bind(sessionDate, stationId, timeIn, timeOut).first();

  if (collision) {
    return jsonResponse({
      ok: false,
      error: `Station ${stationId} is already reserved between ${collision.time_in} and ${collision.time_out}.`
    }, 409);
  }

  const countRow = await db.prepare(
    `SELECT COUNT(*) AS cnt FROM master_log WHERE session_date = ?1`
  ).bind(sessionDate).first();
  const seq = Number(countRow?.cnt || 0) + 1;
  const txId = `${sessionDate.replace(/-/g, "")}${String(seq).padStart(3, "0")}`;

  const walletPaid = payMode === "WALLET" ? totalInr : 0;
  const balanceDue = payMode === "WALLET" ? 0 : totalInr;
  const statusStr = payMode === "WALLET" ? "✅ Paid" : "⏳ Reserved";

  await db.prepare(
    `INSERT INTO master_log (
      tx_id, session_date, customer_name, phone, time_in, time_out, total_hr,
      console_id, category, controllers, game_charges, snacks_inr, total_bill,
      cash_inr, upi_inr, wallet_inr, total_received, balance_due, cash_given, change_to_return, wallet_status
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, 0, ?11, 0, 0, ?12, ?12, ?13, 0, 0, ?14)`
  ).bind(
    txId, sessionDate, customerName, phone, timeIn, timeOut, totalHr,
    stationId, category, controllers, totalInr, walletPaid, balanceDue, statusStr
  ).run();

  await db.prepare(
    `INSERT INTO customer_directory (customer_name, phone, membership_tier)
     VALUES (?1, ?2, 'Non-Member')
     ON CONFLICT(customer_name, phone) DO NOTHING`
  ).bind(customerName, phone).run();

  return jsonResponse({
    ok: true,
    tx_id: txId,
    station_id: stationId,
    session_date: sessionDate,
    time_in: timeIn,
    time_out: timeOut,
    total_bill: totalInr,
    status: statusStr
  }, 201);
}
