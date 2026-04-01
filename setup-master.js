const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');
const bcrypt = require('bcrypt');

const MASTER_DB_PATH = path.join(__dirname, 'database', 'master.db');
const SALT_ROUNDS = 12;

// Default superadmin credentials (CHANGE PASSWORD AFTER FIRST LOGIN!)
const DEFAULT_SUPERADMIN = {
    username: 'admin',
    plainPassword: 'admin123',        // ← Change this immediately in production!
    name: 'System Administrator',
    email: 'admin@yourcompany.com',
    role: 'superadmin'
};

function hashPassword(password) {
    return bcrypt.hashSync(password, SALT_ROUNDS);
}

function setupMasterDb() {
    // Ensure directory exists
    fs.mkdirSync(path.dirname(MASTER_DB_PATH), { recursive: true });

    // Open (or create) the database
    const db = new Database(MASTER_DB_PATH, { verbose: console.log });

    console.log('Initializing master database...');

    // Apply schema
    db.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA synchronous = NORMAL;
    PRAGMA auto_vacuum = INCREMENTAL;

    -- Organizations table
    CREATE TABLE IF NOT EXISTS organizations (
      id                  TEXT PRIMARY KEY,
      slug                TEXT UNIQUE NOT NULL,
      name                TEXT NOT NULL,
      registration_no     TEXT,
      sst_registration_no TEXT,
      einvoice_tin        TEXT,
      db_path             TEXT NOT NULL,
      currency            TEXT DEFAULT 'MYR',
      status              TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'archived')),
      created_at          TEXT DEFAULT (datetime('now')),
      updated_at          TEXT DEFAULT (datetime('now'))
    );

    -- Global admins table
    CREATE TABLE IF NOT EXISTS global_admins (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      username            TEXT UNIQUE NOT NULL,
      password_hash       TEXT NOT NULL,
      name                TEXT NOT NULL,
      email               TEXT,
      role                TEXT DEFAULT 'superadmin' CHECK (role IN ('superadmin', 'support', 'auditor')),
      is_active           INTEGER DEFAULT 1 CHECK (is_active IN (0,1)),
      created_at          TEXT DEFAULT (datetime('now')),
      last_login_epoch    INTEGER
    );

    -- Organization-level audit log
    CREATE TABLE IF NOT EXISTS org_audit_log (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      org_id              TEXT NOT NULL,
      action              TEXT NOT NULL,
      performed_by        TEXT NOT NULL,
      performed_at_epoch  INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
      details_json        TEXT,
      notes               TEXT
    );

    -- Indexes
    CREATE INDEX IF NOT EXISTS idx_org_slug ON organizations(slug);
    CREATE INDEX IF NOT EXISTS idx_org_status ON organizations(status);
    CREATE INDEX IF NOT EXISTS idx_global_username ON global_admins(username);
    CREATE INDEX IF NOT EXISTS idx_org_audit_org ON org_audit_log(org_id);
  `);

    // Insert default superadmin if not exists
    const insertAdmin = db.prepare(`
    INSERT OR IGNORE INTO global_admins (
      username,
      password_hash,
      name,
      email,
      role,
      is_active,
      created_at
    ) VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
  `);

    const hashedPassword = hashPassword(DEFAULT_SUPERADMIN.plainPassword);

    insertAdmin.run(
        DEFAULT_SUPERADMIN.username,
        hashedPassword,
        DEFAULT_SUPERADMIN.name,
        DEFAULT_SUPERADMIN.email,
        DEFAULT_SUPERADMIN.role,
        1
    );

    console.log('Master database setup complete.');
    console.log(`Default superadmin created:`);
    console.log(`  Username: ${DEFAULT_SUPERADMIN.username}`);
    console.log(`  Password: ${DEFAULT_SUPERADMIN.plainPassword}  ← CHANGE THIS NOW!`);
    console.log(`  Hash stored: ${hashedPassword.substring(0, 30)}...`);

    // Optional: Log the initial setup
    db.prepare(`
    INSERT INTO org_audit_log (org_id, action, performed_by, performed_at_epoch, details_json, notes)
    VALUES (NULL, 'system_init', 'setup_script', CAST(strftime('%s', 'now') AS INTEGER), ?, 'Master DB initialized')
  `).run(JSON.stringify({ version: '1.0', default_admin: DEFAULT_SUPERADMIN.username }));

    db.close();
}

// Run the setup
setupMasterDb();
