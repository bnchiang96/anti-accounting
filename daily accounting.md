This document defines the **Daily Accounting** module in a way that aligns with the high-level PRD and the action list.

It covers only the day-to-day accounting actions in the tenant system.

This module is the **workflow and business-logic layer** above CRUD.
It is the layer the UI should normally call for operational accounting actions.

It does **not** cover:
- Global superadmin functions
- Company login / authentication
- Organization admin user-management functions
- Reporting / views
- Standalone invoice lifecycle as a separate module

For this project, **Daily Accounting** means the actions listed in the action list as items **14-25**.

### Daily Accounting Responsibility

Daily Accounting should own:
- business workflow sequencing
- posting logic
- allocation logic
- void and reversal flows
- journal creation logic
- UI-facing action orchestration
- coordination of validation across multiple records

Daily Accounting may call CRUD functions underneath, but it should not bypass CRUD integrity guards.

Examples:
- UI calls `postReceipt` workflow, not raw receipt table updates
- workflow decides what journal entry to create
- CRUD enforces that a posted receipt cannot be edited afterward

### Daily Accounting vs CRUD Boundary

- Daily Accounting = workflow, business logic, and UI-facing actions
- CRUD = direct DB foundation API with hard integrity guards

In short:
- Daily Accounting decides **how** the accounting action should happen
- CRUD ensures the database is changed safely

### Daily Accounting Scope

The module is divided into 3 workflow areas:
- Receipts (incoming money)
- Payments (outgoing money)
- Manual journals (adjustments, transfers, corrections)

These workflows must always follow the core PRD invariants:
- Posted transactions are immutable
- Corrections happen by reversal plus new entry
- Every posting must remain balanced
- Drafts do not affect reports
- Posted transactions must write audit history
- Draft documents may use logical_id references, but posted documents must freeze the exact physical record ids used at posting time

---

### 1. Receipt Workflow

This workflow aligns to action list items **14-18**:
- Create receipt
- Update draft receipt
- Post receipt to general ledger
- Allocate receipt to invoice(s)
- Void / cancel receipt

**Purpose**

Record money received into cash or bank, including customer payments, cash sales, refunds received, or other incoming amounts.

**Flow**

1. **Create Draft Receipt**
   User enters:
   - receipt date
   - total amount
   - payment method
   - receiving account
   - party or free-text counterparty details
   - optional reference and notes

   User adds one or more lines.

   Each line must represent part of the total and must point to either:
   - an AR invoice
   - an income account

2. **Update Draft Receipt**
   A draft receipt may be edited by the allowed actor before posting.

   Editable data includes:
   - header fields
   - line items
   - counterparty details
   - references and notes

3. **Post Receipt**
   System validates:
   - receipt is still draft
   - sum of line amounts equals receipt total
   - all lines are valid
   - resulting journal entry is balanced

   When posting succeeds, system:
   - creates the journal entry
   - updates balances
   - freezes the exact linked party, account, and invoice physical record ids used at posting time
   - changes receipt status to posted
   - locks the receipt from further editing
   - records audit history

4. **Allocate Receipt**
   A posted receipt may be allocated to one or more AR invoices.

   System updates invoice payment state based on allocation result:
   - unpaid
   - partial
   - paid

5. **Void / Cancel Receipt**
   A posted receipt may only be cancelled through a void flow.

   System must:
   - require a reason
   - create a reversing journal entry
   - mark the receipt as voided or cancelled
   - record audit history

**Rules**

- Only drafts can be updated
- Posted receipts are immutable
- Total receipt amount must equal total line amount
- Posting must always create balanced double-entry
- Posted receipt display and downstream logic must use the frozen posted record ids, not the latest current master version

---

### 2. Payment Workflow

This workflow aligns to action list items **19-23**:
- Create payment
- Update draft payment
- Post payment to general ledger
- Allocate payment to invoice(s) or expense
- Void / cancel payment

**Purpose**

Record money paid out from cash or bank, including supplier payments, utilities, salary, rent, and other expenses.

**Flow**

1. **Create Draft Payment**
   User enters:
   - payment date
   - total amount
   - payment method
   - source account
   - party or free-text counterparty details
   - optional reference and notes

   User adds one or more lines.

   Each line must represent part of the total and must point to either:
   - an AP invoice
   - an expense account

2. **Update Draft Payment**
   A draft payment may be edited by the allowed actor before posting.

3. **Post Payment**
   System validates:
   - payment is still draft
   - sum of line amounts equals payment total
   - all lines are valid
   - resulting journal entry is balanced

   When posting succeeds, system:
   - creates the journal entry
   - updates balances
   - freezes the exact linked party, account, and invoice physical record ids used at posting time
   - changes payment status to posted
   - locks the payment from further editing
   - records audit history

4. **Allocate Payment**
   A posted payment may be allocated to one or more AP invoices, or treated as direct expense allocation according to the selected lines.

   System updates invoice payment state where applicable.

5. **Void / Cancel Payment**
   A posted payment may only be cancelled through a void flow.

   System must:
   - require a reason
   - create a reversing journal entry
   - mark the payment as voided or cancelled
   - record audit history

**Rules**

- Only drafts can be updated
- Posted payments are immutable
- Total payment amount must equal total line amount
- Posting must always create balanced double-entry
- Posted payment display and downstream logic must use the frozen posted record ids, not the latest current master version

---

### 3. Manual Journal Workflow

This workflow aligns to action list items **24-25**:
- Create and post manual journal entry
- Reverse posted journal entry

**Purpose**

Record internal transfers, adjustments, corrections, and other entries that are not represented by receipt or payment workflows.

**Flow**

1. **Create and Post Manual Journal**
   User enters:
   - entry date
   - description
   - optional reference
   - multiple debit and credit lines

   System validates:
   - total debit equals total credit

   When posting succeeds, system:
   - creates the journal entry
   - updates balances
   - freezes the exact account physical record ids used on the journal lines
   - locks the journal entry
   - records audit history

2. **Reverse Posted Journal**
   If a posted journal is wrong, user cannot edit it directly.

   System must:
   - create a reversing journal linked to the original
   - mark reversal relationship clearly
   - preserve the original entry
   - record audit history

   If correction is needed, user then creates a new correct journal entry separately.

**Rules**

- Manual journals must always balance
- Posted manual journals are immutable
- Corrections are done by reverse plus new entry, never by editing history

---

### What Daily Accounting Does Not Own

To stay aligned with the PRD and action list, this module does not own:
- global company lifecycle
- tenant login
- company user management
- reporting and financial views

Invoices may exist in the system schema, but they are not part of the core Daily Accounting scope defined in the current PRD and action list document.

---

### Summary

The Daily Accounting module is responsible for the operational accounting actions that directly create posted ledger impact:
- receipts
- payments
- manual journals

The core lifecycle is:

`draft -> update -> post -> lock`

And the correction rule is:

`posted error -> reverse -> create new correct entry`

The architecture rule is:

`UI -> Daily Accounting workflow -> CRUD foundation -> database`

===

Here is the **complete and final lifecycle** for all four main document types in your system, presented clearly together.

### Final Document Lifecycle Summary

| Stage          | Status         | Description                                                                 | Can Edit? | Can Allocate? | Posted to GL? | Immutable? | Who Can Perform          | Applies To |
|----------------|----------------|-----------------------------------------------------------------------------|-----------|---------------|---------------|------------|--------------------------|------------|
| Draft          | `draft`        | Document is being prepared. Lines and details can be freely edited.         | Yes       | No            | No            | No         | Creator or Admin         | All        |
| Posted         | `posted`       | Document is finalized and posted to General Ledger. Balances updated.       | **No**    | Yes           | Yes           | **Yes**    | Creator or Admin         | All        |
| Partial        | `partial`      | Invoice has been partially paid (only for AR/AP invoices).                  | No        | Yes           | Yes           | Yes        | System (auto)            | Invoice only |
| Paid           | `paid`         | Invoice is fully paid.                                                      | No        | No            | Yes           | Yes        | System (auto)            | Invoice only |
| Voided         | `voided`       | Document is cancelled. Reversing journal entry created.                     | No        | No            | Yes (reversed)| **Yes**    | Admin                    | All        |
| Superseded     | `superseded`   | Old version after an update (only possible while in draft).                 | No        | No            | Yes (old)     | Yes        | System (auto)            | All        |

### Detailed Lifecycle for Each Document Type

#### 1. Receipt Lifecycle (Incoming Money)

| Stage       | Status       | Description                                                                 | Can Edit? | Can Allocate? | Posted to GL? | Immutable? |
|-------------|--------------|-----------------------------------------------------------------------------|-----------|---------------|---------------|------------|
| Draft       | `draft`      | Receipt is being prepared (header + lines)                                  | Yes       | No            | No            | No         |
| Posted      | `posted`     | Receipt posted to GL. Balances updated.                                     | **No**    | Yes           | Yes           | **Yes**    |
| Voided      | `voided`     | Receipt cancelled (error or returned). Reversing entry created.             | No        | No            | Yes (reversed)| **Yes**    |
| Superseded  | `superseded` | Old version (only while draft).                                             | No        | No            | Yes (old)     | Yes        |

**Key Rules**: Only draft can be edited. Allocation to AR invoices possible after posting.

---

#### 2. Payment Lifecycle (Outgoing Money)

| Stage       | Status       | Description                                                                 | Can Edit? | Can Allocate? | Posted to GL? | Immutable? |
|-------------|--------------|-----------------------------------------------------------------------------|-----------|---------------|---------------|------------|
| Draft       | `draft`      | Payment voucher is being prepared (header + lines)                          | Yes       | No            | No            | No         |
| Posted      | `posted`     | Payment posted to GL. Balances updated.                                     | **No**    | Yes           | Yes           | **Yes**    |
| Voided      | `voided`     | Payment cancelled. Reversing journal entry created.                         | No        | No            | Yes (reversed)| **Yes**    |
| Superseded  | `superseded` | Old version (only while draft).                                             | No        | No            | Yes (old)     | Yes        |

**Key Rules**: Only draft can be edited. Allocation to AP invoices or direct expense accounts.

---

#### 3. Invoice Lifecycle (AR or AP)

| Stage       | Status       | Description                                                                 | Can Edit? | Can Allocate? | Posted to GL? | Immutable? |
|-------------|--------------|-----------------------------------------------------------------------------|-----------|---------------|---------------|------------|
| Draft       | `draft`      | Invoice is being prepared (AR or AP). Lines editable.                       | Yes       | No            | No            | No         |
| Posted      | `posted`     | Invoice posted to GL. AR or AP balance updated.                             | **No**    | Yes           | Yes           | **Yes**    |
| Partial     | `partial`    | Invoice partially paid (managed by allocation).                             | No        | Yes           | Yes           | Yes        |
| Paid        | `paid`       | Invoice fully paid.                                                         | No        | No            | Yes           | Yes        |
| Voided      | `voided`     | Invoice cancelled. Reversing journal entry created.                         | No        | No            | Yes (reversed)| **Yes**    |
| Superseded  | `superseded` | Old version (only while draft).                                             | No        | No            | Yes (old)     | Yes        |

**Key Rules**: `invoice_type` (AR/AP) determines GL behavior. Partial/Paid status managed automatically by allocations.

---

#### 4. Manual Journal Lifecycle

| Stage       | Status       | Description                                                                 | Can Edit? | Can Allocate? | Posted to GL? | Immutable? | Who Can Perform |
|-------------|--------------|-----------------------------------------------------------------------------|-----------|---------------|---------------|------------|-----------------|
| Draft       | `draft`      | Manual journal is being prepared (multiple debit/credit lines).             | Yes       | No            | No            | No         | Any user        |
| Posted      | `posted`     | Manual journal posted to GL. Balances updated.                              | **No**    | No            | Yes           | **Yes**    | Any user        |
| Voided      | `voided`     | Manual journal cancelled. Reversing entry created.                          | No        | No            | Yes (reversed)| **Yes**    | Admin           |
| Superseded  | `superseded` | Not applicable (manual journals do not use supersede).                      | No        | No            | —             | —          | —               |

**Key Rules for Manual Journal**:
- Must always balance (total debit = total credit)
- Once posted, **cannot be edited or superseded**
- Corrections are done only by:
   - Creating a **reversing entry** (negative of the wrong entry)
   - Creating a **new correcting entry**
- `source_type = 'manual'` or `'transfer'` or `'adjustment'`

---

### Overall System Rules (Applies to All Documents)

- **Draft** = Working / editable stage
- **Posted** = Final, **immutable** stage (no edit, no supersede allowed)
- **Voided** = Cancelled with full history and reversing entry
- **Superseded** = Only used for draft documents (old version after update)
- Any change after posting → use **Void** or **Reversing + New Entry**
- All actions are logged in `audit_log`

This is now the **final, consistent lifecycle** for all four document types.

===

Here’s a **clear and simple diagram** showing the **lifecycle and correction flow** for posted documents.

### Document Lifecycle & Correction Diagram

```
                          Start
                            ↓
                    Create Draft
                            ↓
                 (Edit as many times as needed)
                            ↓
                       Post Document
                            ↓
                    Status = "posted"
                            ↓
                       LOCKED
                 (Immutable - No Edit)
                            ↓
               Correction Needed?
                   /           \
                 Yes            No
                  ↓              ↓
        Create Reversing Entry     End (Normal Flow)
                  ↓
        Create New Correct Entry
                  ↓
             Books Corrected
                  ↓
           Full History Preserved
                  ↓
             Audit Log Updated
```

### Detailed Breakdown of Correction Flow (After Posting)

```
Posted Document (Wrong Amount)
          ↓
   [User/Admin initiates correction]
          ↓
Create Reversing Entry
   - Negative of the original wrong entry
   - Links to original via reversal_of
   - Description: "Reversing error in REC-001"
          ↓
Create New Correct Entry
   - Contains the correct values
   - Links to the same source document
   - Description: "Corrected REC-001"
          ↓
Net Effect:
   - Wrong entry remains in history
   - Reversing entry cancels the error
   - New entry applies the correct amount
   - Account balances are now accurate
          ↓
Everything logged in audit_log with who, when, and reason
```

### Visual Status Flow (for Receipt, Payment, Invoice)

```
Draft ────────→ Posted ────────→ Voided
   │               │
   └─ Superseded   └─ (Correction via Reversing + New Entry)
```

### Manual Journal Specific Flow

```
Create Manual Journal
        ↓
     Post
        ↓
   LOCKED (Immutable)
        ↓
Error Found?
   ↓ Yes
Create Reversing Entry (negative)
        ↓
Create New Correct Entry
        ↓
   Books Corrected
```

### Key Takeaways from the Diagram

- **Posted = Locked**: No editing or superseding allowed after posting.
- **Correction Path**: Always **Reversing Entry → New Correct Entry**
- **History Preserved**: Original wrong entry stays in the system (with reversal flag)
- **Audit Trail**: Every step is logged with user, time, and reason

This is the standard, safe approach used in professional accounting systems.
