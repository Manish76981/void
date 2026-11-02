-- ============================================================================
-- VoidZone Gaming Cafe - Production Cloudflare D1 Relational Schema & Seed Data
-- Strict RBAC Architecture: Customer, Staff (PIN 1234), Owner (PIN 9999)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- 1. Members Table (Player Authentication & Loyalty Vault)
CREATE TABLE IF NOT EXISTS members (
    id TEXT PRIMARY KEY,
    member_account TEXT NOT NULL UNIQUE COLLATE NOCASE,
    member_phone TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT DEFAULT '',
    riot_id TEXT DEFAULT '',
    pin_salt TEXT NOT NULL,
    pin_hash TEXT NOT NULL,
    pass_tier TEXT NOT NULL DEFAULT 'none' CHECK (pass_tier IN ('none', 'silver', 'gold', 'radiant')),
    pass_expires_at TEXT,
    wallet_balance REAL NOT NULL DEFAULT 0.0 CHECK (wallet_balance >= 0.0),
    bonus_hh_minutes INTEGER NOT NULL DEFAULT 0,
    spins_available INTEGER NOT NULL DEFAULT 1,
    drops_available INTEGER NOT NULL DEFAULT 0,
    shards_count INTEGER NOT NULL DEFAULT 0,
    cooler_coupons INTEGER NOT NULL DEFAULT 0,
    playtime_streak_days INTEGER NOT NULL DEFAULT 0,
    streak_shields INTEGER NOT NULL DEFAULT 1,
    kyc_verified INTEGER NOT NULL DEFAULT 0 CHECK (kyc_verified IN (0, 1)),
    kyc_doc_note TEXT DEFAULT 'Pending Desk KYC',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 2. Auth Sessions Table (Bearer Tokens & RBAC Roles)
CREATE TABLE IF NOT EXISTS auth_sessions (
    token TEXT PRIMARY KEY,
    member_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'staff', 'owner')),
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
);

-- 3. Stations Table (Mazgaon Hardware Fleet: 16 PCs, 4 PS5s, 1 Racing Sim)
CREATE TABLE IF NOT EXISTS stations (
    id TEXT PRIMARY KEY,
    branch TEXT NOT NULL DEFAULT 'MAZGAON' CHECK (branch IN ('MAZGAON', 'CHARNI_ROAD')),
    station_type TEXT NOT NULL CHECK (station_type IN ('PC', 'PS5', 'SIM', 'VR')),
    rig_name TEXT NOT NULL,
    hardware_specs TEXT NOT NULL,
    hourly_rate_peak REAL NOT NULL,
    hourly_rate_hh REAL NOT NULL,
    live_status TEXT NOT NULL DEFAULT 'AVAILABLE' CHECK (live_status IN ('AVAILABLE', 'OCCUPIED', 'RESERVED')),
    current_customer TEXT DEFAULT '—',
    session_start_ms INTEGER DEFAULT 0
);

-- 4. Master Log Table (Sheet 1 & Sheet 13: 21-Column Transactional & Floor History Ledger)
CREATE TABLE IF NOT EXISTS master_log (
    tx_id TEXT PRIMARY KEY,
    session_date TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    time_in TEXT DEFAULT '',
    time_out TEXT DEFAULT '',
    total_hr REAL NOT NULL DEFAULT 0.0,
    console_id TEXT DEFAULT '',
    category TEXT DEFAULT 'Standard',
    controllers INTEGER NOT NULL DEFAULT 1,
    game_charges REAL NOT NULL DEFAULT 0.0,
    snacks REAL NOT NULL DEFAULT 0.0,
    total_bill REAL NOT NULL DEFAULT 0.0,
    cash REAL NOT NULL DEFAULT 0.0,
    upi REAL NOT NULL DEFAULT 0.0,
    wallet REAL NOT NULL DEFAULT 0.0,
    total_received REAL NOT NULL DEFAULT 0.0,
    balance_due REAL NOT NULL DEFAULT 0.0,
    cash_given REAL NOT NULL DEFAULT 0.0,
    change_to_return REAL NOT NULL DEFAULT 0.0,
    wallet_status TEXT NOT NULL DEFAULT '✅ Paid',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_master_log_date ON master_log(session_date);
CREATE INDEX IF NOT EXISTS idx_master_log_console ON master_log(console_id, session_date, time_in, time_out);

-- 5. Snack Log Table (Sheet 2: Itemized F&B Sales)
CREATE TABLE IF NOT EXISTS snack_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tx_id TEXT NOT NULL,
    sale_date TEXT NOT NULL,
    snack_name TEXT NOT NULL,
    qty INTEGER NOT NULL DEFAULT 1,
    unit_price REAL NOT NULL,
    total_cost REAL NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 6. Inventory Table (Sheet 8: F&B Stock & Reorder Thresholds)
CREATE TABLE IF NOT EXISTS inventory (
    item_name TEXT PRIMARY KEY,
    sell_price REAL NOT NULL,
    total_purchased INTEGER NOT NULL DEFAULT 0,
    total_sold INTEGER NOT NULL DEFAULT 0,
    current_stock INTEGER NOT NULL DEFAULT 0,
    reorder_level INTEGER NOT NULL DEFAULT 10
);

-- 7. Wallet Top-Ups Table (Sheet 3 & Sheet 4: Deposits & Cash Bonus %)
CREATE TABLE IF NOT EXISTS wallet_topups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    deposit_date TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    amount_deposited REAL NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'UPI',
    bonus_pct REAL NOT NULL DEFAULT 0.0,
    bonus_amount REAL NOT NULL DEFAULT 0.0,
    total_credited REAL NOT NULL DEFAULT 0.0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 8. OpEx Ledger Table (Sheet 5 & Sheet 10: Operating Expenses)
CREATE TABLE IF NOT EXISTS opex_ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    expense_date TEXT NOT NULL,
    expense_category TEXT NOT NULL,
    description TEXT NOT NULL,
    amount REAL NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 9. Customer Directory Table (Sheet 12: Customer Details Dashboard)
CREATE TABLE IF NOT EXISTS customer_directory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    membership_tier TEXT NOT NULL DEFAULT 'Non-Member'
);

-- ============================================================================
-- Seed Data from Master_Calculator_Hardened.xlsx
-- ============================================================================

INSERT OR IGNORE INTO stations (id, branch, station_type, rig_name, hardware_specs, hourly_rate_peak, hourly_rate_hh) VALUES
('PC-1', 'MAZGAON', 'PC', 'Rig 01 [VIP Alpha]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 240Hz Zowie', 80.0, 60.0),
('PC-2', 'MAZGAON', 'PC', 'Rig 02 [VIP Bravo]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 240Hz Zowie', 80.0, 60.0),
('PC-3', 'MAZGAON', 'PC', 'Rig 03 [Stage Main]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 240Hz Zowie', 80.0, 60.0),
('PC-4', 'MAZGAON', 'PC', 'Rig 04 [Stage Wing]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 240Hz Zowie', 80.0, 60.0),
('PC-5', 'MAZGAON', 'PC', 'Rig 05 [Stage Mid]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 240Hz Zowie', 80.0, 60.0),
('PC-6', 'MAZGAON', 'PC', 'Rig 06 [Stage Anchor]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 240Hz Zowie', 80.0, 60.0),
('PC-7', 'MAZGAON', 'PC', 'Rig 07 [Arena A1]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 180Hz BenQ', 80.0, 60.0),
('PC-8', 'MAZGAON', 'PC', 'Rig 08 [Arena A2]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 180Hz BenQ', 80.0, 60.0),
('PC-9', 'MAZGAON', 'PC', 'Rig 09 [Arena A3]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 180Hz BenQ', 80.0, 60.0),
('PC-10', 'MAZGAON', 'PC', 'Rig 10 [Arena A4]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 180Hz BenQ', 80.0, 60.0),
('PC-11', 'MAZGAON', 'PC', 'Rig 11 [Squad B1]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 165Hz Asus', 80.0, 60.0),
('PC-12', 'MAZGAON', 'PC', 'Rig 12 [Squad B2]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 165Hz Asus', 80.0, 60.0),
('PC-13', 'MAZGAON', 'PC', 'Rig 13 [Squad B3]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 165Hz Asus', 80.0, 60.0),
('PC-14', 'MAZGAON', 'PC', 'Rig 14 [Squad B4]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 165Hz Asus', 80.0, 60.0),
('PC-15', 'MAZGAON', 'PC', 'Rig 15 [Squad B5]', 'i5-14400F · RTX 4060 · 32GB DDR5 · 165Hz Asus', 80.0, 60.0),
('PC-16', 'MAZGAON', 'PC', 'Rig 16 [Streamer Pod]', 'i5-14400F · RTX 4060 · Dual 240Hz · Shure Mic', 80.0, 60.0),
('PS-1', 'MAZGAON', 'PS5', 'PS5 Lounge Pod 1', 'Sony PS5 · 55" 4K OLED 120Hz · 4x DualSense', 100.0, 80.0),
('PS-2', 'MAZGAON', 'PS5', 'PS5 Lounge Pod 2', 'Sony PS5 · 55" 4K OLED 120Hz · 4x DualSense', 100.0, 80.0),
('PS-3', 'MAZGAON', 'PS5', 'PS5 Private Pod 3', 'Sony PS5 · 65" Sony Bravia 120Hz · 4x DualSense Edge', 100.0, 80.0),
('PS-4', 'MAZGAON', 'PS5', 'PS5 Arena Pod 4', 'Sony PS5 · 55" Samsung Neo QLED · 4x DualSense', 100.0, 80.0),
('SIM-1', 'MAZGAON', 'SIM', 'Racing Simulator Cockpit', 'Fanatec Podium DD2 · ClubSport V3 · Triple 32" + PSVR2', 200.0, 150.0);

INSERT OR IGNORE INTO members (id, member_account, member_phone, full_name, email, riot_id, pin_salt, pin_hash, pass_tier, wallet_balance, playtime_streak_days, kyc_verified, kyc_doc_note) VALUES
('ICF-1001', 'rahul_vz', '9820011223', 'Rahul', 'rahul.esports@gmail.com', 'Rahul#VZ01', 'vz_9820011223', '0000', 'none', 1880.0, 4, 1, 'Aadhaar Last-4 (4821)'),
('ICF-1002', 'manish_vz', '9819397166', 'manish', 'manishjaryan@gmail.com', 'manish#VZ02', 'vz_9819397166', '0000', 'silver', 400.0, 3, 1, 'College ID Verified'),
('ICF-1003', 'amit_vz', '9820044556', 'Amit', 'amit@gmail.com', 'Amit#VZ03', 'vz_9820044556', '0000', 'none', 0.0, 1, 0, 'Pending Desk KYC'),
('ICF-1004', 'suresh_vz', '9833011221', 'Suresh', 'suresh@gmail.com', 'Suresh#VZ04', 'vz_9833011221', '0000', 'none', 0.0, 1, 0, 'Pending Desk KYC'),
('ICF-1005', 'group_a', '9800000001', 'Group_A', 'groupa@gmail.com', 'GroupA#VZ05', 'vz_9800000001', '0000', 'none', 0.0, 1, 1, 'Tournament Squad'),
('ICF-1006', 'player_5', '9800000002', 'Player_5', 'player5@gmail.com', 'Player5#VZ06', 'vz_9800000002', '0000', 'none', 0.0, 1, 0, 'Pending Desk KYC'),
('ICF-1007', 'makdn_vz', '4864548845', 'Makdn', 'makdn@gmail.com', 'Makdn#VZ07', 'vz_4864548845', '0000', 'none', 0.0, 1, 0, 'Pending Desk KYC'),
('ICF-1008', 'manish_2', '9819394511', 'manish', 'manish2@gmail.com', 'manish#VZ08', 'vz_9819394511', '0000', 'none', 0.0, 1, 0, 'Pending Desk KYC');

INSERT OR IGNORE INTO master_log (tx_id, session_date, customer_name, phone, time_in, time_out, total_hr, console_id, category, controllers, game_charges, snacks, total_bill, cash, upi, wallet, total_received, balance_due, cash_given, change_to_return, wallet_status) VALUES
('20260318001', '2026-03-18', 'Rahul', '9820011223', '11:20:00', '16:20:00', 5.0, 'PC-1', 'Split Time', 0, 350.0, 120.0, 470.0, 0.0, 0.0, 120.0, 120.0, 350.0, 0.0, 0.0, '✅ Paid'),
('20260321001', '2026-03-21', 'manish', '9819397166', '00:33:00', '02:33:00', 2.0, 'PC-3', 'Standard', 1, 160.0, 0.0, 160.0, 120.0, 40.0, 0.0, 160.0, 0.0, 120.0, 0.0, '✅ Paid'),
('20260321002', '2026-03-21', 'rahul', '9820011223', '10:12:00', '12:05:00', 1.8833, 'PS-1', 'Happy Hr', 4, 640.0, 0.0, 640.0, 500.0, 140.0, 0.0, 640.0, 0.0, 500.0, 0.0, '✅ Paid'),
('20260322001', '2026-03-22', 'manish', '', '', '', 0.0, '', '', 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, '✅ Paid'),
('20260313001', '2026-03-13', 'rahul', '9820011223', '00:33:00', '02:33:00', 2.0, 'PC-5', 'Standard', 1, 160.0, 0.0, 160.0, 0.0, 0.0, 0.0, 0.0, 160.0, 0.0, 0.0, '✅ Paid'),
('20260321003', '2026-03-21', 'manish', '', '', '', 0.0, 'PS-3', '', 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, '✅ Paid');

INSERT OR IGNORE INTO snack_log (tx_id, sale_date, snack_name, qty, unit_price, total_cost) VALUES
('20260318001', '2026-03-18', 'Maggi', 2, 60.0, 120.0);

INSERT OR IGNORE INTO inventory (item_name, sell_price, total_purchased, total_sold, current_stock, reorder_level) VALUES
('diet coke', 50.0, 100, 0, 100, 20),
('Maggi', 60.0, 50, 2, 48, 10);

INSERT OR IGNORE INTO wallet_topups (deposit_date, customer_name, phone, amount_deposited, payment_method, bonus_pct, bonus_amount, total_credited) VALUES
('2026-03-18', 'Rahul', '9820011223', 2000.0, 'UPI', 0.0, 0.0, 2000.0);

INSERT OR IGNORE INTO opex_ledger (expense_date, expense_category, description, amount) VALUES
('2026-03-18', 'Electricity', 'Commercial Power', 25000.0);

INSERT OR IGNORE INTO customer_directory (customer_name, phone, membership_tier) VALUES
('Rahul', '9820011223', 'Tier 1'),
('manish', '9819397166', 'Non-Member'),
('manish', 'No Phone', 'Non-Member'),
('Amit', '9820044556', 'Non-Member'),
('Suresh', '9833011221', 'Non-Member'),
('Group_A', '9800000001', 'Non-Member'),
('Player_5', '9800000002', 'Non-Member'),
('Makdn', '4864548845', 'Non-Member'),
('manish', '9819394511', 'Non-Member');

-- 10. CASH_DRAWER_LEDGER TABLE (Physical Till Count & Shift Variance Snapshots)
CREATE TABLE IF NOT EXISTS cash_drawer_ledger (
  id TEXT PRIMARY KEY,
  snapshot_ts TEXT NOT NULL,
  staff_id TEXT NOT NULL DEFAULT 'STAFF_1234',
  opening_float REAL NOT NULL DEFAULT 2000,
  cash_received REAL NOT NULL DEFAULT 0,
  cash_payouts REAL NOT NULL DEFAULT 0,
  physical_cash REAL NOT NULL DEFAULT 0,
  expected_cash REAL NOT NULL DEFAULT 0,
  discrepancy REAL NOT NULL DEFAULT 0,
  notes_json TEXT NOT NULL DEFAULT '{}',
  notes_remark TEXT DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_cash_drawer_ts ON cash_drawer_ledger(snapshot_ts);

-- SEED CASH DRAWER SHIFT SNAPSHOT
INSERT OR IGNORE INTO cash_drawer_ledger (id, snapshot_ts, staff_id, opening_float, cash_received, cash_payouts, physical_cash, expected_cash, discrepancy, notes_json, notes_remark)
VALUES ('TILL-20260318-01', '2026-03-18 23:55:00', 'STAFF_1234', 2000, 120, 0, 2120, 2120, 0, '{"500":2,"200":2,"100":5,"50":2,"20":4,"10":2,"5":2,"2":3,"1":4}', 'Shift handover balanced.');
