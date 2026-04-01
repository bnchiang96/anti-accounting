# Functional Specification Document (FSD)

## 1. Purpose

This document defines the functional behavior of the anti-accounting system based on the current PRD, action list, workflow documents, and schema direction.

It is intended to align product, design, and engineering on:
- system scope
- roles and permissions
- module responsibilities
- document lifecycle
- functional rules
- data integrity expectations

This FSD is written at the **functional system level**.
It defines what the system must do and how modules are expected to behave, without locking into UI screen design or endpoint naming.

---

## 2. Product Summary

The system is a multi-tenant accounting platform where each company operates in a completely isolated set of books.

The product supports:
- global company setup and lifecycle management
- company-level authentication and user management
- daily accounting operations
- immutable posting into the general ledger
- financial reporting from posted transactions only
- full auditability of important changes

The core product principle is that accounting history must remain trustworthy:
- posted financial records are immutable
- corrections are done by reverse plus new entry
- every posting must remain balanced
- posted documents must retain exact linked version references by physical record id

---

## 3. Scope

### In Scope

- master-level organization registry
- global superadmin access
- tenant/company login
- tenant user management
- chart of accounts maintenance
- parties maintenance
- receipts
- payments
- invoices
- manual journals
- audit log viewing
- financial reports

### Out of Scope

- UI layout specification
- API endpoint naming
- integration with external tax, banking, or payment services
- advanced inventory, payroll, or fixed asset modules

---

## 4. User Roles

### 4.1 Global Superadmin

Can:
- log in to the master system
- create companies
- list companies
- suspend and reactivate companies
- reset company admin passwords
- view organization-level audit history

Cannot:
- access tenant accounting books as an accounting operator
- directly manage tenant accounting transactions

### 4.2 Organization Admin

Can:
- log in to a specific tenant
- manage tenant users
- update company profile
- perform accounting actions allowed inside the tenant
- view reports
- view company audit log

### 4.3 Accountant / Normal User

Can:
- log in to a specific tenant
- perform permitted accounting actions
- view reports according to role

### 4.4 Viewer / Auditor

Can:
- access read-only reporting and audit history according to permission rules

Cannot:
- create, edit, post, void, or reverse accounting documents

---

## 5. Core System Rules

The following are non-negotiable system rules:

1. Every company must be fully isolated from every other company.
2. No action may create an unbalanced journal entry.
3. Only posted entries affect accounting reports.
4. Posted accounting records are immutable.
5. Corrections must use reversal plus new entry, never direct edit.
6. Important changes must be auditable with actor and time.
7. Business dates are stored separately from system timestamps.
8. Posted documents must freeze linked versioned records by exact physical `id`, not only by `logical_id`.

---

## 6. High-Level Architecture

The system is organized into two main application layers for tenant operations.

### 6.1 CRUD Layer

CRUD is the foundation API closest to the database.

It owns:
- direct create / read / update / list / archive operations
- line-item maintenance
- versioning mechanics
- audit-log persistence
- direct DB integrity guards
- low-level status checks and lock checks

Examples of CRUD-owned protection:
- non-draft document cannot be edited
- posted document lines cannot be changed
- only current version may be superseded
- referenced records must exist
- posted documents must freeze exact linked physical record ids

### 6.2 Workflow Layer

Daily Accounting and other higher-level modules are the workflow layer.

It owns:
- business workflow sequencing
- posting logic
- allocation logic
- void logic
- reversal logic
- journal creation rules
- UI-facing operational actions

### 6.3 Architecture Rule

The expected interaction pattern is:

`UI -> Workflow layer -> CRUD layer -> Database`

The workflow layer must not bypass CRUD integrity guards.

---

## 7. Module Breakdown

### 7.1 Global Module

Responsible for:
- global login
- create organization
- list organizations
- suspend / reactivate organization
- reset organization admin password
- view organization audit log

### 7.2 Org Admin Module

Responsible for:
- create user
- update user
- list users
- reset user password
- deactivate user
- update company profile
- get company profile

### 7.3 CRUD Foundation Modules

Current tenant-side CRUD modules:
- accounts
- receipts
- payments
- invoices
- parties
- users
- company profile
- journal
- audit log

### 7.4 Daily Accounting Workflow Module

Responsible for tenant operational accounting actions:
- receipts
- payments
- manual journals

### 7.5 Reporting Module

Responsible for:
- trial balance
- profit and loss
- balance sheet
- cash book
- general ledger
- journal listing
- company audit history view

---

## 8. Functional Action Coverage

The system currently covers 32 major actions.

### 8.1 Global Actions

1. Setup initial global superadmin
2. Login as global superadmin
3. Create company
4. List companies
5. Suspend company
6. Reactivate company
7. Reset organization admin password
8. View organization audit log

### 8.2 Tenant Access and Admin Actions

9. Login to a company
10. List users in company
11. Create user
12. Update user
13. Reset password for user

### 8.3 Daily Accounting Actions

14. Create receipt
15. Update draft receipt
16. Post receipt
17. Allocate receipt
18. Void / cancel receipt
19. Create payment
20. Update draft payment
21. Post payment
22. Allocate payment
23. Void / cancel payment
24. Create and post manual journal
25. Reverse posted journal

### 8.4 Reporting and Read-Only Actions

26. View trial balance
27. View profit and loss
28. View balance sheet
29. View cash book
30. View general ledger
31. View all journal entries
32. View company audit log

---

## 9. Document Lifecycle

### 9.1 General Lifecycle Model

Accounting documents follow a controlled lifecycle.

The main functional states are:
- `draft`
- `posted`
- `voided` or `cancelled`
- `superseded` where version replacement is used

### 9.2 Draft

A draft document:
- may be created and edited
- does not affect ledger balances
- does not appear in accounting reports
- may resolve linked references using current `logical_id` lookups

### 9.3 Posted

A posted document:
- affects the ledger
- is immutable
- may not be edited directly
- must freeze all required linked physical record ids
- must be auditable

### 9.4 Voided / Cancelled

A voided or cancelled document:
- is not directly edited
- must be supported by appropriate reversal behavior where applicable
- remains part of historical record

### 9.5 Superseded

Superseded applies to versioned records where a new physical row replaces the current one.

This is version control behavior, not business correction by itself.

### 9.6 Reversal

Reversal is the accounting correction mechanism for posted entries.

The original posted record remains in history.
A reversing entry neutralizes the original effect.
If needed, a new correct entry is then created separately.

---

## 10. Versioning and Reference Freezing

The system uses versioned records with:
- `logical_id` for stable business identity
- physical `id` for exact record version

### 10.1 Draft Behavior

While a document is still draft:
- the system may resolve related records by `logical_id`
- users may continue editing content and lines

### 10.2 Posted Behavior

When a document is posted:
- linked versioned references must be frozen by exact physical `id`
- future updates to the source master record must not change the meaning of the posted document

Examples of linked records that may require frozen physical ids:
- party
- account
- invoice

This rule exists to preserve historical accuracy without relying on copied text snapshots.

---

## 11. Daily Accounting Functional Specification

### 11.1 Receipt Workflow

#### Purpose

Record money received into cash or bank.

Typical scenarios:
- customer payment
- cash sale
- refund received
- other incoming amount

#### Required Functional Behavior

The system must allow:
- create draft receipt
- update draft receipt
- post receipt
- allocate posted receipt to invoice
- void or cancel posted receipt

#### Create Draft Receipt

User provides:
- receipt date
- total amount
- payment method
- receiving account
- party or direct counterparty details
- optional reference / notes
- one or more receipt lines

Each line must point to either:
- an AR invoice
- an income account

#### Update Draft Receipt

Only draft receipts may be updated.

Allowed updates include:
- header changes
- line changes
- counterparty changes
- note/reference changes

#### Post Receipt

Before posting, system must verify:
- receipt status is draft
- total line amount equals header total
- each line is valid
- resulting journal is balanced

On success, system must:
- create journal entry and journal lines
- update balances
- freeze linked physical record ids
- lock receipt from further editing
- record audit history

#### Allocate Receipt

Posted receipt may be allocated to one or more AR invoices.

System must update invoice payment state accordingly:
- unpaid
- partial
- paid

#### Void / Cancel Receipt

Only an allowed actor may void/cancel a posted receipt.

System must:
- require reason
- create reversing journal effect where applicable
- preserve original history
- record audit history

### 11.2 Payment Workflow

#### Purpose

Record money paid out from cash or bank.

Typical scenarios:
- supplier payment
- utilities
- salary
- rent
- other expenses

#### Required Functional Behavior

The system must allow:
- create draft payment
- update draft payment
- post payment
- allocate posted payment
- void or cancel posted payment

#### Create Draft Payment

User provides:
- payment date
- total amount
- payment method
- source account
- party or direct counterparty details
- optional reference / notes
- one or more payment lines

Each line must point to either:
- an AP invoice
- an expense account

#### Update Draft Payment

Only draft payments may be updated.

#### Post Payment

Before posting, system must verify:
- payment status is draft
- total line amount equals header total
- each line is valid
- resulting journal is balanced

On success, system must:
- create journal entry and journal lines
- update balances
- freeze linked physical record ids
- lock payment from further editing
- record audit history

#### Allocate Payment

Posted payment may be allocated to:
- AP invoices
- direct expense treatment according to selected lines

System must update invoice payment state where applicable.

#### Void / Cancel Payment

System must:
- require reason
- create reversing journal effect where applicable
- preserve original history
- record audit history

### 11.3 Manual Journal Workflow

#### Purpose

Record adjustments, transfers, and corrections outside receipt/payment flows.

#### Required Functional Behavior

The system must allow:
- create and post manual journal
- reverse posted journal

#### Create and Post Manual Journal

User provides:
- entry date
- description
- optional reference
- multiple debit and credit lines

Before posting, system must verify:
- total debit equals total credit

On success, system must:
- create journal entry
- update balances
- freeze exact account physical ids used on journal lines
- lock the posted entry
- record audit history

#### Reverse Posted Journal

If posted journal is wrong:
- original journal must not be edited
- system creates a reversing journal linked to the original
- original history is preserved
- audit history is recorded

If correction is needed, user creates a new correct entry separately.

---

## 12. User Management Functional Specification

The system must support tenant user management with the following rules:
- username is the primary login identifier
- email is optional
- only organization admin can manage tenant users
- user changes must be auditable
- user password reset must set must-change-password behavior
- actor cannot deactivate self
- actor cannot lower own role in a way that violates governance rules

---

## 13. Reporting Functional Specification

Reports are read-only and must use posted data only.

The system must support:
- trial balance
- profit and loss
- balance sheet
- cash book
- general ledger
- journal listing
- company audit log view

### Reporting Rules

- drafts are excluded
- posted entries are included
- reports use current active account/document views where functionally appropriate
- ledger detail must remain historically consistent with frozen posted references

---

## 14. Audit Requirements

The system must maintain auditability at both global and tenant levels.

### 14.1 Global Audit

Must record events such as:
- organization creation
- suspension
- reactivation
- admin password reset

### 14.2 Tenant Audit

Must record important changes such as:
- document creation where required by policy
- posting
- voiding
- reversal
- user changes
- company profile changes

Each audit record should capture at minimum:
- entity type
- action
- target logical id
- old/new record references where applicable
- performed by
- performed at

---

## 15. Validation and Integrity Rules

### 15.1 General

- referenced records must exist
- only valid roles may perform restricted actions
- suspended companies block tenant login
- company isolation must always be enforced

### 15.2 Accounting Documents

- only draft documents are editable
- posted documents are locked
- line totals must equal header totals where applicable
- journal debit and credit totals must match
- reversal must preserve original history

### 15.3 Versioning

- only current version may be updated into a new version
- posted documents must preserve exact linked physical record ids

---

## 16. Data Model Direction

The current schema direction uses:
- master database for organization metadata and global admins
- one tenant database per company
- versioned tenant entities using `logical_id`, `version`, `is_current`, and `superseded_by`
- immutable journal entries once posted
- direct line tables for receipts, payments, and invoices

Key tenant entities include:
- company profile
- accounts
- journal entries
- journal lines
- receipts
- receipt lines
- payments
- payment lines
- invoices
- invoice lines
- parties
- users
- audit log

---

## 17. Open Items / Clarifications

The following areas should still be finalized in a later refinement pass:
- exact invoice lifecycle ownership across documents and folder structure
- exact API contract shapes for UI calls
- exact foreign key enforcement for newly added frozen physical-id columns
- detailed validation matrix by function
- report calculation details and output formatting rules

---

## 18. Implementation Guidance

The current intended implementation direction is:
- use CRUD modules as guarded DB foundation
- use workflow modules for business actions
- use versioned records for mutable master data
- use physical-id freezing at posting time for historical integrity
- use audit logging as a first-class system behavior

This FSD is sufficient for a first engineering implementation pass and can be refined into lower-level technical design and API contracts afterward.
