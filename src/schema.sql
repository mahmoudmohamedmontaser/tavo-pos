// Tiny zero-dependency JSON file database.
// Good enough to launch a prototype; swap for Postgres/MySQL when you scale.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// DATA_DIR lets deployments (and tests) point the JSON store at a writable/
// isolated location instead of the bundled ./data dir.
const DB_FILE = process.env.DATA_DIR
? path.join(process.env.DATA_DIR, 'db.json')
  : path.join(__dirname, '..', 'data', 'db.json');
if (process.env.DATA_DIR && !fs.existsSync(process.env.DATA_DIR)) fs.mkdirSync(process.env.DATA_DIR, { recursive: true });

const DEFAULTS = {
  menu: [],        // {id, category, name, price, emoji, active}
  orders: [],      // {id, table, lines, status, createdAt}
  payments: [],    // {id, orderId, subtotal, tax, tip, total, method, status, stripeId, createdAt}
  tables: [],      // {number, status, orderId}
  staff: [],       // {id, name, role, clockedInAt, tenantId}
  users: [],       // {id, name, role, pinHash, tenantId}  — login accounts
  tenants: [],     // {id, name, slug, plan, createdAt}  — businesses on the platform
  inventory: [],   // {id, name, unit, qty, parLevel, cost, tenantId}  — stock / ingredients
  customers: [],   // {id, name, phone, points, visits, totalSpent, tenantId, createdAt}  — loyalty members
  giftcards: [],   // {id, code, balance, initialBalance, active, tenantId, createdAt}  — gift cards
  drawers: [],     // {id, openedBy, openedAt, startingFloat, paidIn, paidOut, status, ...}  — cash drawer sessions
  shifts: [],      // {id, userId, name, role, clockIn, clockOut, breakMins, wage, status, tenantId}  — time clock
  messages: [],    // {id, channel, kind, to, customerId, campaignId, subject, body, status, tenantId, createdAt}  — digital receipts + marketing
  campaigns: [],   // {id, name, channel, segment, subject, body, recipients, sent, failed, tenantId, createdAt}  — marketing campaigns
  vendors: [],     // {id, name, contact, email, phone, notes, tenantId, createdAt}  — suppliers
  purchaseOrders: [], // {id, vendorId, vendorName, status, lines, total, notes, receivedAt, tenantId, createdAt}  — POs
  stocktakes: [],  // {id, name, status, counts, tenantId, createdAt, closedAt}  — cycle counts
  reservations: [], // {id, kind, name, phone, partySize, time, quotedWait, status, tableNumber, notes, tenantId, createdAt, seatedAt}
  houseAccounts: [], // {id, name, contact, email, phone, creditLimit, balance, tenantId, createdAt}
  invoices: [],    // {id, accountId, accountName, lines, total, status, dueDate, notes, tenantId, createdAt, paidAt}
  locations: [],   // {id, name, address, slug, tenantId, createdAt}  — multi-site registry
  discountPresets: [], // {id, name, kind:'percent'|'amount', value, reason, scope:'check', schedule:{days:[0-6],start:'HH:MM',end:'HH:MM'}|null, autoApply, active, tenantId, createdAt}  — preset & scheduled (happy-hour) discounts
  // ★ NEW: per-tenant monotonic order-number counter.
  //   Shape: { [tenantId]: nextNumberToIssue }  — e.g. { default: 1005 }
  orderSequences: {}
};

function ensureFile() {
  const dir = path.dirname(DB_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(DB_FILE)) fs.writeFileSync(DB_FILE, JSON.stringify(DEFAULTS, null, 2));
}

export function read() {
  ensureFile();
  try {
    return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(DB_FILE, 'utf8')) };
  } catch {
    return structuredClone(DEFAULTS);
  }
}

export function write(data) {
  ensureFile();
  fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));
  return data;
}

// Convenience: mutate the db with a callback and persist.
export function update(fn) {
  const db = read();
  const result = fn(db);
  write(db);
  return result;
}


-- -- Tavo POS — PostgreSQL schema (multi-tenant)
-- CREATE TABLE IF NOT EXISTS tenants (
--   id         TEXT PRIMARY KEY,
--   name       TEXT,
--   slug       TEXT UNIQUE,
--   plan       TEXT DEFAULT 'free',
--   mode       TEXT DEFAULT 'restaurant',
--   settings   JSONB DEFAULT '{}',
--   created_at BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS menu (
--   id         TEXT PRIMARY KEY,
--   category   TEXT,
--   name       TEXT NOT NULL,
--   price      NUMERIC(10,2) NOT NULL,
--   emoji      TEXT,
--   image      TEXT,
--   sort_order INTEGER DEFAULT 0,
--   modifier_groups JSONB DEFAULT '[]',
--   recipe     JSONB DEFAULT '[]',
--   sku        TEXT,
--   barcode    TEXT,
--   stock      NUMERIC(12,3),
--   track_stock BOOLEAN DEFAULT FALSE,
--   tax_rate   NUMERIC(6,4),
--   schedule   JSONB,
--   is_combo   BOOLEAN DEFAULT FALSE,
--   combo_items JSONB DEFAULT '[]',
--   weighted   BOOLEAN DEFAULT FALSE,
--   weight_unit TEXT DEFAULT 'lb',
--   tenant_id  TEXT DEFAULT 'default',
--   active     BOOLEAN DEFAULT TRUE
-- );

-- CREATE TABLE IF NOT EXISTS tables (
--   number    INTEGER,
--   status    TEXT DEFAULT 'open',
--   order_id  TEXT,
--   tenant_id TEXT DEFAULT 'default'
-- );

-- CREATE TABLE IF NOT EXISTS orders (
--   id         TEXT PRIMARY KEY,
--   number     INTEGER,
--   table_no   INTEGER,
--   lines      JSONB,
--   subtotal   NUMERIC(10,2),
--   tax        NUMERIC(10,2),
--   total      NUMERIC(10,2),
--   status     TEXT,
--   void_reason TEXT,
--   channel    TEXT DEFAULT 'pos',
--   platform   TEXT,
--   customer   TEXT,
--   external_id TEXT,
--   fired_courses JSONB DEFAULT '[]',
--   tenant_id  TEXT DEFAULT 'default',
--   created_at BIGINT,
--   fired_at   BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS payments (
--   id         TEXT PRIMARY KEY,
--   order_id   TEXT,
--   table_no   INTEGER,
--   lines      JSONB,
--   subtotal   NUMERIC(10,2),
--   tax        NUMERIC(10,2),
--   tip        NUMERIC(10,2),
--   total      NUMERIC(10,2),
--   method     TEXT,
--   status     TEXT,
--   stripe_id  TEXT,
--   confirmed  BOOLEAN DEFAULT FALSE,
--   customer_id TEXT,
--   points_earned INTEGER DEFAULT 0,
--   points_redeemed INTEGER DEFAULT 0,
--   user_id    TEXT,
--   user_name  TEXT,
--   refunded_amount NUMERIC(10,2) DEFAULT 0,
--   refunded_at BIGINT,
--   tenant_id  TEXT DEFAULT 'default',
--   created_at BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS users (
--   id        TEXT PRIMARY KEY,
--   name      TEXT,
--   role      TEXT,
--   pin_hash  TEXT,
--   tenant_id TEXT DEFAULT 'default'
-- );

-- CREATE TABLE IF NOT EXISTS staff (
--   id            TEXT PRIMARY KEY,
--   name          TEXT,
--   role          TEXT,
--   clocked_in_at BIGINT,
--   tenant_id     TEXT DEFAULT 'default'
-- );

-- CREATE TABLE IF NOT EXISTS inventory (
--   id         TEXT PRIMARY KEY,
--   name       TEXT NOT NULL,
--   unit       TEXT DEFAULT 'unit',
--   qty        NUMERIC(12,3) DEFAULT 0,
--   par_level  NUMERIC(12,3) DEFAULT 0,
--   cost       NUMERIC(10,4) DEFAULT 0,
--   tenant_id  TEXT DEFAULT 'default'
-- );

-- CREATE TABLE IF NOT EXISTS customers (
--   id          TEXT PRIMARY KEY,
--   name        TEXT,
--   phone       TEXT,
--   email       TEXT,
--   notes       TEXT,
--   marketing_opt_in BOOLEAN DEFAULT TRUE,
--   points      INTEGER DEFAULT 0,
--   visits      INTEGER DEFAULT 0,
--   total_spent NUMERIC(12,2) DEFAULT 0,
--   tenant_id   TEXT DEFAULT 'default',
--   created_at  BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS giftcards (
--   id              TEXT PRIMARY KEY,
--   code            TEXT,
--   balance         NUMERIC(10,2) DEFAULT 0,
--   initial_balance NUMERIC(10,2) DEFAULT 0,
--   active          BOOLEAN DEFAULT TRUE,
--   tenant_id       TEXT DEFAULT 'default',
--   created_at      BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS drawers (
--   id             TEXT PRIMARY KEY,
--   opened_by      TEXT,
--   opened_at      BIGINT,
--   starting_float NUMERIC(10,2) DEFAULT 0,
--   paid_in        NUMERIC(10,2) DEFAULT 0,
--   paid_out       NUMERIC(10,2) DEFAULT 0,
--   closed_by      TEXT,
--   closed_at      BIGINT,
--   expected       NUMERIC(10,2),
--   counted        NUMERIC(10,2),
--   variance       NUMERIC(10,2),
--   status         TEXT DEFAULT 'open',
--   tenant_id      TEXT DEFAULT 'default'
-- );

-- CREATE TABLE IF NOT EXISTS shifts (
--   id         TEXT PRIMARY KEY,
--   user_id    TEXT,
--   name       TEXT,
--   role       TEXT,
--   clock_in   BIGINT,
--   clock_out  BIGINT,
--   break_mins INTEGER DEFAULT 0,
--   wage       NUMERIC(10,2) DEFAULT 0,
--   status     TEXT DEFAULT 'open',
--   tenant_id  TEXT DEFAULT 'default'
-- );

-- CREATE TABLE IF NOT EXISTS messages (
--   id          TEXT PRIMARY KEY,
--   channel     TEXT,
--   kind        TEXT,
--   to_addr     TEXT,
--   customer_id TEXT,
--   campaign_id TEXT,
--   subject     TEXT,
--   body        TEXT,
--   status      TEXT DEFAULT 'sent',
--   error       TEXT,
--   tenant_id   TEXT DEFAULT 'default',
--   created_at  BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS campaigns (
--   id          TEXT PRIMARY KEY,
--   name        TEXT,
--   channel     TEXT,
--   segment     TEXT,
--   subject     TEXT,
--   body        TEXT,
--   recipients  INTEGER DEFAULT 0,
--   sent        INTEGER DEFAULT 0,
--   failed      INTEGER DEFAULT 0,
--   tenant_id   TEXT DEFAULT 'default',
--   created_at  BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS vendors (
--   id          TEXT PRIMARY KEY,
--   name        TEXT,
--   contact     TEXT,
--   email       TEXT,
--   phone       TEXT,
--   notes       TEXT,
--   tenant_id   TEXT DEFAULT 'default',
--   created_at  BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS purchase_orders (
--   id          TEXT PRIMARY KEY,
--   vendor_id   TEXT,
--   vendor_name TEXT,
--   status      TEXT DEFAULT 'draft',
--   lines       JSONB DEFAULT '[]',
--   total       NUMERIC(12,2) DEFAULT 0,
--   notes       TEXT,
--   received_at BIGINT,
--   tenant_id   TEXT DEFAULT 'default',
--   created_at  BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS stocktakes (
--   id          TEXT PRIMARY KEY,
--   name        TEXT,
--   status      TEXT DEFAULT 'open',
--   counts      JSONB DEFAULT '[]',
--   tenant_id   TEXT DEFAULT 'default',
--   created_at  BIGINT,
--   closed_at   BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS reservations (
--   id           TEXT PRIMARY KEY,
--   kind         TEXT DEFAULT 'reservation',
--   name         TEXT,
--   phone        TEXT,
--   party_size   INTEGER DEFAULT 1,
--   time         BIGINT,
--   quoted_wait  INTEGER,
--   status       TEXT DEFAULT 'booked',
--   table_number INTEGER,
--   notes        TEXT,
--   tenant_id    TEXT DEFAULT 'default',
--   created_at   BIGINT,
--   seated_at    BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS house_accounts (
--   id           TEXT PRIMARY KEY,
--   name         TEXT,
--   contact      TEXT,
--   email        TEXT,
--   phone        TEXT,
--   credit_limit NUMERIC(12,2) DEFAULT 0,
--   balance      NUMERIC(12,2) DEFAULT 0,
--   tenant_id    TEXT DEFAULT 'default',
--   created_at   BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS invoices (
--   id           TEXT PRIMARY KEY,
--   account_id   TEXT,
--   account_name TEXT,
--   lines        JSONB DEFAULT '[]',
--   total        NUMERIC(12,2) DEFAULT 0,
--   status       TEXT DEFAULT 'open',
--   due_date     BIGINT,
--   notes        TEXT,
--   tenant_id    TEXT DEFAULT 'default',
--   created_at   BIGINT,
--   paid_at      BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS locations (
--   id         TEXT PRIMARY KEY,
--   name       TEXT,
--   address    TEXT,
--   slug       TEXT,
--   tenant_id  TEXT DEFAULT 'default',
--   created_at BIGINT
-- );

-- CREATE TABLE IF NOT EXISTS discount_presets (
--   id         TEXT PRIMARY KEY,
--   name       TEXT,
--   kind       TEXT DEFAULT 'percent',   -- 'percent' | 'amount'
--   value      NUMERIC(10,2) DEFAULT 0,
--   reason     TEXT,
--   scope      TEXT DEFAULT 'check',
--   schedule   JSONB,                     -- {days:[0-6], start:'HH:MM', end:'HH:MM'} or NULL for always
--   auto_apply BOOLEAN DEFAULT FALSE,     -- auto-apply during its schedule window (happy hour)
--   active     BOOLEAN DEFAULT TRUE,
--   tenant_id  TEXT DEFAULT 'default',
--   created_at BIGINT
-- );

-- CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
-- CREATE INDEX IF NOT EXISTS idx_payments_stripe ON payments(stripe_id);
