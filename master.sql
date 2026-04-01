-- master_schema.sql
-- Schema for the global / master database (master.db)
-- Shared across all tenants/organizations
-- Contains only metadata about organizations and global admins

PRAGMA
journal_mode = WAL;
PRAGMA
synchronous = NORMAL;
PRAGMA
auto_vacuum = INCREMENTAL;

-- Organizations (tenants / companies)
CREATE TABLE organizations
(
    id                  TEXT PRIMARY KEY,     -- UUID, e.g. 'org_550e8400-e29b-41d4-a716-446655440000'
    slug                TEXT UNIQUE NOT NULL, -- url-friendly: 'abc-trading', 'lee-bon-chiang-enterprise'
    name                TEXT        NOT NULL,
    registration_no     TEXT,                 -- SSM / company number
    sst_registration_no TEXT,
    einvoice_tin        TEXT,                 -- nullable
    db_path             TEXT        NOT NULL, -- relative path: 'tenants/abc-trading.db'
    currency            TEXT DEFAULT 'MYR',
    status              TEXT DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'archived')),
    created_at          TEXT DEFAULT (datetime('now')),
    updated_at          TEXT DEFAULT (datetime('now'))
);

-- Global super-admins (system-wide users who can create/manage organizations)
CREATE TABLE global_admins
(
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    username         TEXT UNIQUE NOT NULL, -- primary login identifier
    password_hash    TEXT        NOT NULL,
    name             TEXT        NOT NULL,
    email            TEXT,                 -- optional (for recovery / notifications)
    role             TEXT    DEFAULT 'superadmin'
        CHECK (role IN ('superadmin', 'support', 'auditor')),
    is_active        INTEGER DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at       TEXT    DEFAULT (datetime('now')),
    last_login_epoch INTEGER
);

-- Audit log for organization-level events (create, suspend, delete, etc.)
-- This is optional but highly recommended for traceability
CREATE TABLE org_audit_log
(
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    org_id             TEXT    NOT NULL, -- references organizations.id
    action             TEXT    NOT NULL, -- 'create', 'suspend', 'reactivate', 'archive', 'delete', 'update_profile'
    performed_by       TEXT    NOT NULL, -- username of global admin or system
    performed_at_epoch INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
    details_json       TEXT,             -- JSON with old/new values or reason
    notes              TEXT
);

-- Indexes for performance
CREATE INDEX idx_org_slug ON organizations (slug);
CREATE INDEX idx_org_status ON organizations (status);
CREATE INDEX idx_global_admin_username ON global_admins (username);
CREATE INDEX idx_org_audit_org ON org_audit_log (org_id);
CREATE INDEX idx_org_audit_time ON org_audit_log (performed_at_epoch);
