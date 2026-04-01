This document defines the **CRUD layer** as the foundation API of the system.

The CRUD layer is the closest application layer to the database.
It is responsible for direct persistence, retrieval, version-safe updates, and non-bypassable data integrity guards.

### CRUD Layer Responsibility

CRUD functions are used by higher-level modules to connect to the database safely and consistently.

This layer should own:
- direct database create / read / update / list / archive operations
- line-item maintenance
- versioning mechanics
- audit-log writes
- hard edit-lock checks
- low-level integrity checks tied directly to the table model

Examples of rules that belong in CRUD:
- non-draft document cannot be edited
- posted document cannot have lines added, changed, or removed
- only current version can be superseded
- referenced record must exist before save
- posted document must freeze exact linked physical record ids

This layer should **not** own UI-facing workflow orchestration.

That means business actions such as:
- post
- allocate
- void
- reverse

are primarily workflow actions, even if they may call CRUD helpers internally or reuse CRUD-level integrity checks.

### CRUD vs Workflow Boundary

- CRUD = foundation API for direct database access and record safety
- Daily Accounting = logic, workflow, and UI-facing action layer built on top of CRUD

In short:
- CRUD protects the data model
- Daily Accounting explains how accounting actions happen

### 1. accounts.js

| Function                | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|-------------------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `create`                | Create a new account                                              | code, name, type, subtype, opening_balance?, tax_code? | subtype must be from fixed list, code must be unique                                      |
| `update`                | Update an existing account                                        | id/logicalId, name?, subtype?, tax_code?, etc.       | Cannot change type, only non-system accounts                                              |
| `get`                   | Get single account details                                        | id or logicalId                                      | Returns current version only                                                              |
| `list`                  | List accounts with filters                                        | type?, subtype?, is_active?, search?, page, limit    | Supports pagination and search                                                            |
| `delete`                | Soft delete / archive account                                     | id or logicalId                                      | Cannot delete system accounts                                                             |
| `updateOpeningBalance`  | Update opening balance of an account                              | id or logicalId, amount                              | Only allowed before any transactions are posted                                           |

---

### 2. receipts.js

This module is the receipt data-access foundation.
It owns receipt persistence and editability guards.

| Function     | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|--------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `create`     | Create a new draft receipt                                        | receipt_date, total_amount, payment_method, account_logical_id, party_logical_id?, lines[] | Lines total must equal header total_amount; draft may use logical_id references           |
| `update`     | Update a draft receipt                                            | id/logicalId, updateData (header + lines)            | Only allowed if status = 'draft'                                                          |
| `get`        | Get single receipt with lines                                     | id or logicalId                                      | Returns current version + lines                                                           |
| `list`       | List receipts with filters                                        | date range, status, party, payment_method, search     | Supports pagination                                                                       |
| `addLine`    | Add a line to a draft receipt                                     | receiptId, lineData                                  | Only for draft receipts                                                                   |
| `updateLine` | Update a line in a draft receipt                                  | lineId, lineData                                     | Only for draft receipts                                                                   |
| `deleteLine` | Delete a line from a draft receipt                                | lineId                                               | Only for draft receipts                                                                   |
| `post`       | Post draft receipt to GL                                          | id or logicalId                                      | Must be draft and balanced, creates journal entry, locks receipt, and freezes linked party/account/invoice physical record ids used at posting |
| `void`       | Void a posted receipt                                             | id or logicalId, reason                              | Requires reason, creates reversing journal entry                                          |
| `allocate`   | Allocate receipt to AR invoice(s)                                 | receiptId, allocations: [{invoice_logical_id, amount}] | Only on posted receipts, total allocated ≤ receipt amount                                 |

---

### 3. payments.js

This module is the payment data-access foundation.
It owns payment persistence and editability guards.

| Function     | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|--------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `create`     | Create a new draft payment                                        | payment_date, total_amount, payment_method, account_logical_id, party_logical_id?, lines[] | Lines total must equal header total_amount; draft may use logical_id references           |
| `update`     | Update a draft payment                                            | id/logicalId, updateData (header + lines)            | Only allowed if status = 'draft'                                                          |
| `get`        | Get single payment with lines                                     | id or logicalId                                      | Returns current version + lines                                                           |
| `list`       | List payments with filters                                        | date range, status, party, payment_method, search     | Supports pagination                                                                       |
| `addLine`    | Add a line to a draft payment                                     | paymentId, lineData                                  | Only for draft payments                                                                   |
| `updateLine` | Update a line in a draft payment                                  | lineId, lineData                                     | Only for draft payments                                                                   |
| `deleteLine` | Delete a line from a draft payment                                | lineId                                               | Only for draft payments                                                                   |
| `post`       | Post draft payment to GL                                          | id or logicalId                                      | Must be draft and balanced, creates journal entry, locks payment, and freezes linked party/account/invoice physical record ids used at posting |
| `void`       | Void a posted payment                                             | id or logicalId, reason                              | Requires reason, creates reversing journal entry                                          |
| `allocate`   | Allocate payment to AP invoice or expense                         | paymentId, allocations: [{invoice_logical_id?, expense_account_logical_id?, amount}] | Can allocate to invoice or direct expense                                                 |

---

### 4. invoices.js (includes lines)

This module is the invoice data-access foundation.
It owns invoice persistence and editability guards.

| Function      | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|---------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `create`      | Create a new draft invoice (AR or AP) with lines                  | invoice_type, invoice_date, due_date, counterparty_logical_id, lines[] | Lines must have valid account; draft may use logical_id references                        |
| `update`      | Update a draft invoice                                            | id/logicalId, updateData (header + lines)            | Only allowed if draft                                                                     |
| `get`         | Get single invoice with lines                                     | id or logicalId                                      | Returns current version + lines                                                           |
| `list`        | List invoices with filters                                        | invoice_type, status, date range, counterparty, search | Supports AR/AP filtering                                                                  |
| `post`        | Post draft invoice to GL                                          | id or logicalId                                      | Creates journal entry, updates AR/AP, and freezes linked party/account physical record ids used at posting |
| `void`        | Void a posted invoice                                             | id or logicalId, reason                              | Requires reason, creates reversing journal entry                                          |
| `addLine`     | Add a line to a draft invoice                                     | invoiceId, lineData                                  | Only for draft invoices                                                                   |
| `updateLine`  | Update a line in a draft invoice                                  | lineId, lineData                                     | Only for draft invoices                                                                   |
| `deleteLine`  | Delete a line from a draft invoice                                | lineId                                               | Only for draft invoices                                                                   |

---

### 5. parties.js

| Function   | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `create`   | Create a new party (customer or supplier)                         | type, name, address..., tax_id?                      | Type must be customer/supplier/other                                                      |
| `update`   | Update party details                                              | id or logicalId, updateData                          | Can update address, credit limit, etc.                                                    |
| `get`      | Get single party                                                  | id or logicalId                                      | Returns current version                                                                   |
| `list`     | List parties with filters                                         | type, search, outstanding?, pagination               | Can filter by customer/supplier                                                           |
| `delete`   | Soft delete party                                                 | id or logicalId                                      | Cannot delete if has outstanding balance                                                  |

---

### 6. users.js

| Function         | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|------------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `create`         | Create new user in this company                                   | username, password, name, role, email?               | Username unique in company, role must be valid                                            |
| `update`         | Update user details                                               | id or logicalId, name?, role?, email?, is_active?    | Cannot change own role to lower                                                           |
| `get`            | Get single user                                                   | id or logicalId                                      | Returns current version                                                                   |
| `list`           | List users in company                                             | role?, is_active?, search, pagination                | Organization scope only                                                                   |
| `resetPassword`  | Reset user password                                               | id or logicalId, newPassword                         | Sets must_change_password = true                                                          |
| `deactivate`     | Deactivate user                                                   | id or logicalId                                      | Cannot deactivate self                                                                    |

---

### 7. companyProfile.js

| Function   | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `get`      | Get current company profile                                       | —                                                    | Returns current version                                                                   |
| `update`   | Update company profile                                            | updateData (address, financial year, einvoice_tin, etc.) | Only organization admin                                                                   |

---

### 8. journal.js

This module is the journal data-access foundation.
It owns journal persistence and low-level immutability rules.

| Function    | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|-------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `create`    | Create and post a manual journal entry                            | entry_date, description, lines[]                     | Debit must equal credit, can be backdated; posting freezes exact account physical record ids used on journal lines |
| `get`       | Get single journal entry                                          | id                                                   | Returns full entry with lines                                                             |
| `list`      | List journal entries                                              | date range, source_type, reference, pagination       | —                                                                                         |
| `reverse`   | Create a reversing entry for a posted journal                     | originalId, reason                                   | Creates new reversing entry, links to original                                            |

---

### 9. auditLog.js

| Function      | What it does                                                      | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|---------------|-------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `logCreate`   | Write audit log entry when a new tenant-side record is created    | entity_type, logical_id, new_record_id, performed_by, changes_summary?, new_value_json? | Used for create events only; must store tenant actor and target logical record            |
| `get`         | Get a single audit log entry                                      | id                                                   | Read-only                                                                                 |
| `list`        | List audit log entries with filters                               | entity_type?, logical_id?, action?, performed_by?, date range, pagination | Read-only; tenant scope only                                                              |

---

### 10. Global Module (`globalActions.js`)

This module contains all actions that only the **Global Superadmin** can perform.

| Function                        | What it does                                                                 | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|---------------------------------|------------------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `globalLogin`                   | Login as global superadmin                                                   | username, password                                   | Grants access only to company management functions (no accounting data access)            |
| `createOrganization`            | Create a new company (organization)                                          | slug, name, registration_no, sst_registration_no, einvoice_tin, address details, admin_username, admin_password, admin_name, admin_email | Slug must be unique; automatically creates tenant DB, default accounts, and first admin user |
| `listOrganizations`             | List all companies in the system                                             | status? (active / suspended / all)                   | Returns only metadata (slug, name, status, created_at)                                    |
| `suspendOrganization`           | Suspend a company (block all user logins)                                    | slug                                                 | Company must be active; logs the action                                                   |
| `reactivateOrganization`        | Reactivate a suspended company                                               | slug                                                 | Company must be suspended; logs the action                                                |
| `listOrgAdmins`                 | List all admin users in a specific company                                   | slug                                                 | Only returns users with role = 'admin'; read-only                                         |
| `resetAdminPassword`            | Reset password for a specific admin in a company                             | slug, targetLogicalId, newPassword?, generateTemp?   | Must use targetLogicalId from listOrgAdmins; sets must_change_password = true; logged      |
| `viewOrgAuditLog`               | View audit log of organization-level events                                  | slug, fromDate?, toDate?                             | Read-only; shows create, suspend, reactivate, password reset events                       |

---

### 11. OrgAdmin Module (`orgAdmin.js`)

This module contains actions that only the **Organization Admin** (role = 'admin' inside the company) can perform.

| Function                        | What it does                                                                 | Main Parameters                                      | Key Restrictions / Rules                                                                 |
|---------------------------------|------------------------------------------------------------------------------|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `createUser`                    | Create a new user inside this company                                        | username, password, name, role, email?               | Username must be unique in this company; role must be valid                               |
| `updateUser`                    | Update user details (name, role, email, active status)                       | userId or logicalId, name?, role?, email?, is_active? | Cannot change own role to lower; cannot deactivate self                                   |
| `getUser`                       | Get single user details                                                      | userId or logicalId                                  | Returns current version                                                                   |
| `listUsers`                     | List all users in this company                                               | role?, is_active?, search?, page, limit              | Organization scope only; supports filtering and pagination                                |
| `resetUserPassword`             | Reset password for any user in this company                                  | userId or logicalId, newPassword                     | Can reset any user including self; sets must_change_password = true                       |
| `deactivateUser`                | Deactivate a user (set is_active = false)                                    | userId or logicalId                                  | Cannot deactivate self                                                                    |
| `updateCompanyProfile`          | Update this company's profile (address, financial year, einvoice_tin, etc.)  | legal_name?, address_line1?, financial_year_end_day?, financial_year_end_month?, einvoice_tin?, etc. | Only organization admin can perform this; creates new version if needed                   |
| `getCompanyProfile`             | Get current company profile                                                  | —                                                    | Returns current version of company profile                                                |

---
