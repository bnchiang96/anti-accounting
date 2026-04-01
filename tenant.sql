-- tenant_schema.sql
-- Full schema for per-tenant accounting database
-- Run this once when creating a new tenant DB
-- Conventions:
-- - logical_id TEXT (UUID) for versioned/mutable entities
-- - TEXT 'YYYY-MM-DD' for date-only fields
-- - INTEGER epoch seconds (UTC) for precise timestamps
-- - Versioned pattern: logical_id + version + is_current + superseded_by (physical id)
-- - Draft documents may use logical_id lookups; posted documents must freeze exact linked physical record ids
-- - Audit trail via audit_log
-- - Lines for receipts, payments, invoices (no separate allocation table)
-- - Status TEXT with CHECK for lifecycle (draft → posted → voided/superseded)

PRAGMA
journal_mode = WAL;
PRAGMA
synchronous = NORMAL;
PRAGMA
auto_vacuum = INCREMENTAL;
PRAGMA
foreign_keys = ON;

-- 1. Company Profile (single row per tenant)
CREATE TABLE company_profile
(
    id                       INTEGER PRIMARY KEY CHECK (id = 1),
    logical_id               TEXT    NOT NULL UNIQUE,
    version                  INTEGER NOT NULL DEFAULT 1,
    is_current               INTEGER          DEFAULT 1 CHECK (is_current IN (0, 1)),
    status                   TEXT             DEFAULT 'active' CHECK (status IN ('active', 'superseded')),

    superseded_by            TEXT,
    superseded_at_epoch      INTEGER,

    legal_name               TEXT    NOT NULL,
    trade_name               TEXT,
    registration_no          TEXT,
    sst_registration_no      TEXT,
    einvoice_tin             TEXT,
    address_line1            TEXT    NOT NULL,
    address_line2            TEXT,
    postcode                 TEXT    NOT NULL,
    city                     TEXT    NOT NULL,
    state                    TEXT    NOT NULL,
    country                  TEXT             DEFAULT 'Malaysia',
    phone                    TEXT,
    mobile                   TEXT,
    email                    TEXT,
    website                  TEXT,
    financial_year_end_day   INTEGER NOT NULL CHECK (financial_year_end_day BETWEEN 1 AND 31),
    financial_year_end_month INTEGER NOT NULL CHECK (financial_year_end_month BETWEEN 1 AND 12),
    default_currency         TEXT             DEFAULT 'MYR',
    logo_path                TEXT,
    accounting_basis         TEXT             DEFAULT 'accrual' CHECK (accounting_basis IN ('accrual', 'cash')),

    created_at_epoch         INTEGER NOT NULL,
    created_by               INTEGER NOT NULL,
    updated_at_epoch         INTEGER NOT NULL,
    updated_by               INTEGER NOT NULL
);

-- 2. Accounts (Chart of Accounts) – versioned
CREATE TABLE accounts
(
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    logical_id          TEXT    NOT NULL UNIQUE,
    version             INTEGER NOT NULL DEFAULT 1,
    is_current          INTEGER          DEFAULT 1 CHECK (is_current IN (0, 1)),
    status              TEXT             DEFAULT 'active' CHECK (status IN ('active', 'superseded', 'archived')),

    superseded_by       INTEGER,
    superseded_at_epoch INTEGER,

    code                TEXT    NOT NULL,
    name                TEXT    NOT NULL,
    name_bm             TEXT,

    type                TEXT    NOT NULL CHECK (type IN ('asset', 'liability', 'equity', 'income', 'expense')),

    subtype             TEXT    NOT NULL CHECK (subtype IN (
                                                            'current_asset',
                                                            'fixed_asset',
                                                            'other_asset',
                                                            'current_liability',
                                                            'long_term_liability',
                                                            'equity_capital',
                                                            'equity_retained_earning',
                                                            'sales',
                                                            'cost_of_sales',
                                                            'other_income',
                                                            'expenses'
        )),

    tax_code            TEXT,
    opening_balance     REAL             DEFAULT 0,
    current_balance     REAL             DEFAULT 0,

    is_system           INTEGER          DEFAULT 0 CHECK (is_system IN (0, 1)),
    is_active           INTEGER          DEFAULT 1 CHECK (is_active IN (0, 1)),

    created_at_epoch    INTEGER NOT NULL,
    created_by          INTEGER NOT NULL,
    updated_at_epoch    INTEGER NOT NULL,
    updated_by          INTEGER NOT NULL
);

-- 3. Journal Entries (immutable once posted)
CREATE TABLE journal_entries
(
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    entry_date       TEXT    NOT NULL,
    description      TEXT    NOT NULL,
    reference        TEXT,
    source_type      TEXT, -- 'receipt', 'payment', 'invoice', 'manual', 'adjustment', 'transfer'
    receipt_id       INTEGER,
    payment_id       INTEGER,
    invoice_id       INTEGER,
    posted_by        INTEGER NOT NULL,
    posted_at_epoch  INTEGER NOT NULL,
    created_at_epoch INTEGER NOT NULL,
    is_reversed      INTEGER DEFAULT 0 CHECK (is_reversed IN (0, 1)),
    reversal_of      INTEGER,

    FOREIGN KEY (receipt_id) REFERENCES receipts (id),
    FOREIGN KEY (payment_id) REFERENCES payments (id),
    FOREIGN KEY (invoice_id) REFERENCES invoices (id),
    FOREIGN KEY (reversal_of) REFERENCES journal_entries (id)
);

CREATE TABLE journal_lines
(
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    journal_id         INTEGER NOT NULL,
    account_logical_id TEXT    NOT NULL,
    debit              REAL DEFAULT 0,
    credit             REAL DEFAULT 0,
    tax_amount         REAL DEFAULT 0,
    memo               TEXT,
    FOREIGN KEY (journal_id) REFERENCES journal_entries (id) ON DELETE CASCADE
);

-- 4. Receipts (versioned, with lines)
CREATE TABLE receipts
(
    id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    logical_id               TEXT    NOT NULL,
    version                  INTEGER NOT NULL DEFAULT 1,
    is_current               INTEGER          DEFAULT 1 CHECK (is_current IN (0, 1)),
    status                   TEXT    NOT NULL CHECK (status IN ('draft', 'posted', 'voided', 'superseded', 'cancelled')),

    superseded_by            INTEGER,
    superseded_at_epoch      INTEGER,

    receipt_no               TEXT    NOT NULL,
    receipt_date             TEXT    NOT NULL,
    total_amount             REAL    NOT NULL,

    party_logical_id         TEXT,
    party_id                 INTEGER,
    counterparty_name        TEXT,
    counterparty_description TEXT,

    payment_method           TEXT    NOT NULL CHECK (payment_method IN
                                                     ('cash', 'bank_transfer', 'cheque', 'ewallet', 'other')),
    account_logical_id       TEXT    NOT NULL,
    account_id               INTEGER,
    reference                TEXT,
    notes                    TEXT,

    created_at_epoch         INTEGER NOT NULL,
    created_by               INTEGER NOT NULL,
    updated_at_epoch         INTEGER NOT NULL,
    updated_by               INTEGER NOT NULL
);

CREATE TABLE receipt_lines
(
    id                         INTEGER PRIMARY KEY AUTOINCREMENT,
    receipt_id                 INTEGER NOT NULL,
    description                TEXT    NOT NULL,
    amount                     REAL    NOT NULL,

    invoice_logical_id         TEXT,
    invoice_id                 INTEGER,
    expense_account_logical_id TEXT,
    expense_account_id         INTEGER,
    income_account_logical_id  TEXT,
    income_account_id          INTEGER,

    tax_amount                 REAL DEFAULT 0,
    memo                       TEXT,

    FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
);

-- 5. Payments (versioned, with lines)
CREATE TABLE payments
(
    id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    logical_id               TEXT    NOT NULL,
    version                  INTEGER NOT NULL DEFAULT 1,
    is_current               INTEGER          DEFAULT 1 CHECK (is_current IN (0, 1)),
    status                   TEXT    NOT NULL CHECK (status IN ('draft', 'posted', 'voided', 'superseded', 'cancelled')),

    superseded_by            INTEGER,
    superseded_at_epoch      INTEGER,

    payment_no               TEXT    NOT NULL,
    payment_date             TEXT    NOT NULL,
    total_amount             REAL    NOT NULL,

    party_logical_id         TEXT,
    party_id                 INTEGER,
    counterparty_name        TEXT,
    counterparty_description TEXT,

    payment_method           TEXT    NOT NULL CHECK (payment_method IN
                                                     ('cash', 'bank_transfer', 'cheque', 'ewallet', 'other')),
    account_logical_id       TEXT    NOT NULL,
    account_id               INTEGER,
    reference                TEXT,
    notes                    TEXT,

    created_at_epoch         INTEGER NOT NULL,
    created_by               INTEGER NOT NULL,
    updated_at_epoch         INTEGER NOT NULL,
    updated_by               INTEGER NOT NULL
);

CREATE TABLE payment_lines
(
    id                         INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id                 INTEGER NOT NULL,
    description                TEXT    NOT NULL,
    amount                     REAL    NOT NULL,

    invoice_logical_id         TEXT,
    invoice_id                 INTEGER,
    expense_account_logical_id TEXT,
    expense_account_id         INTEGER,
    income_account_logical_id  TEXT,
    income_account_id          INTEGER,

    tax_amount                 REAL DEFAULT 0,
    memo                       TEXT,

    FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE CASCADE
);

-- 6. Invoices (versioned)
CREATE TABLE invoices
(
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    logical_id              TEXT    NOT NULL,
    version                 INTEGER NOT NULL DEFAULT 1,
    is_current              INTEGER          DEFAULT 1 CHECK (is_current IN (0, 1)),
    status                  TEXT    NOT NULL CHECK (status IN ('unpaid', 'partial', 'paid', 'voided', 'superseded')),

    superseded_by           INTEGER,
    superseded_at_epoch     INTEGER,

    invoice_type            TEXT    NOT NULL CHECK (invoice_type IN ('AR', 'AP', 'CN', 'DN')),

    invoice_no              TEXT    NOT NULL,
    invoice_date            TEXT    NOT NULL,
    due_date                TEXT    NOT NULL,
    counterparty_logical_id TEXT    NOT NULL,
    counterparty_id         INTEGER,
    subtotal                REAL    NOT NULL,
    tax_amount              REAL             DEFAULT 0,
    total_amount            REAL    NOT NULL,
    notes                   TEXT,

    created_at_epoch        INTEGER NOT NULL,
    created_by              INTEGER NOT NULL,
    updated_at_epoch        INTEGER NOT NULL,
    updated_by              INTEGER NOT NULL
);

CREATE TABLE invoice_lines
(
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id         INTEGER NOT NULL,
    description        TEXT    NOT NULL,
    quantity           REAL DEFAULT 1,
    unit_price         REAL    NOT NULL,
    discount           REAL DEFAULT 0,
    amount             REAL    NOT NULL,
    tax_amount         REAL DEFAULT 0,
    account_logical_id TEXT    NOT NULL,
    account_id         INTEGER,
    FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
);

-- 7. Parties (Customers / Suppliers / Others)
CREATE TABLE parties
(
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    logical_id          TEXT    NOT NULL UNIQUE,
    version             INTEGER NOT NULL DEFAULT 1,
    is_current          INTEGER          DEFAULT 1 CHECK (is_current IN (0, 1)),
    status              TEXT             DEFAULT 'active',

    superseded_by       INTEGER,
    superseded_at_epoch INTEGER,

    type                TEXT    NOT NULL CHECK (type IN ('customer', 'supplier', 'other')),
    name                TEXT    NOT NULL,
    registration_no     TEXT,
    tax_id              TEXT,
    address_line1       TEXT,
    address_line2       TEXT,
    postcode            TEXT,
    city                TEXT,
    state               TEXT,
    country             TEXT             DEFAULT 'Malaysia',
    phone               TEXT,
    mobile              TEXT,
    email               TEXT,
    website             TEXT,
    credit_limit        REAL             DEFAULT 0,
    outstanding         REAL             DEFAULT 0,

    created_at_epoch    INTEGER NOT NULL,
    created_by          INTEGER NOT NULL,
    updated_at_epoch    INTEGER NOT NULL,
    updated_by          INTEGER NOT NULL
);

-- 8. Users (per tenant)
CREATE TABLE users
(
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    logical_id           TEXT    NOT NULL UNIQUE,
    version              INTEGER NOT NULL DEFAULT 1,
    is_current           INTEGER          DEFAULT 1 CHECK (is_current IN (0, 1)),
    status               TEXT             DEFAULT 'active',

    superseded_by        INTEGER,
    superseded_at_epoch  INTEGER,

    username             TEXT    NOT NULL UNIQUE,
    password_hash        TEXT    NOT NULL,
    name                 TEXT    NOT NULL,
    email                TEXT,
    role                 TEXT             DEFAULT 'user' CHECK (role IN ('admin', 'accountant', 'viewer', 'user', 'auditor')),
    is_active            INTEGER          DEFAULT 1 CHECK (is_active IN (0, 1)),
    must_change_password INTEGER          DEFAULT 1 CHECK (must_change_password IN (0, 1)),
    last_login_epoch     INTEGER,

    created_at_epoch     INTEGER NOT NULL,
    created_by           INTEGER NOT NULL,
    updated_at_epoch     INTEGER NOT NULL,
    updated_by           INTEGER NOT NULL
);

-- 9. Audit Log (central trail for all changes)
CREATE TABLE audit_log
(
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type        TEXT    NOT NULL,
    action             TEXT    NOT NULL,
    logical_id         TEXT    NOT NULL,
    old_record_id      INTEGER,
    new_record_id      INTEGER,
    performed_by       INTEGER NOT NULL,
    performed_at_epoch INTEGER NOT NULL,
    changes_summary    TEXT,
    old_value_json     TEXT,
    new_value_json     TEXT
);

-- Performance Indexes
CREATE INDEX idx_accounts_logical_current ON accounts (logical_id, is_current);
CREATE INDEX idx_receipts_logical_current ON receipts (logical_id, is_current);
CREATE INDEX idx_payments_logical_current ON payments (logical_id, is_current);
CREATE INDEX idx_invoices_logical_current ON invoices (logical_id, is_current);
CREATE INDEX idx_users_logical_current ON users (logical_id, is_current);
CREATE INDEX idx_parties_logical_current ON parties (logical_id, is_current);
CREATE INDEX idx_audit_logical ON audit_log (entity_type, logical_id);
CREATE INDEX idx_audit_old_new ON audit_log (old_record_id, new_record_id);
