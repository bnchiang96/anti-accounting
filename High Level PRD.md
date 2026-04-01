Yes — let's go fully high-level and abstract away from any UI buttons, screens, endpoints, or technical action names.

We focus purely on the **logical user flows**, **business processes**, **decision points**, **system responsibilities**, and **key invariants** (what must always be true).

This is the "what happens in the real world" level — how the accounting works from a business/user perspective, without worrying about how it's clicked or coded yet.

### 1. Core Principles & Invariants (non-negotiable rules)

- Every company is completely isolated (own database file, own users, own books)
- Once money movement is recorded and posted to the general ledger → it is **immutable forever**
- All corrections are done via **reversing entry + new entry** (never edit posted records)
- Every change (document edit, user role change, company profile update) is logged with who, when, and what changed
- No action can make the books unbalanced (debit must = credit in every journal entry)
- All monetary amounts are in the company's default currency (usually MYR)
- Date fields are business dates (can be backdated), timestamps are system UTC epoch
- Once a document is posted, any linked versioned master record used by that document must be frozen by exact physical record id at posting time (not only by logical_id)

### 2. Major Business Flows (High-Level Only)

#### Flow A: Bringing a New Company Into the System

1. Someone with global superadmin rights decides to add a new company.
2. They provide:
    - Unique short identifier (slug)
    - Full legal/trade name
    - Registration & tax info (SSM, SST, e-Invoice TIN — optional)
    - Address & contact details
    - Financial year end date
    - First admin user (username + password)
3. System:
    - Registers the new company in the global registry
    - Creates a completely separate set of books for this company
    - Sets up standard chart of accounts
    - Creates the first admin user inside those books
    - Records the creation event in global audit
4. The first admin can now log in to this company and start working.

**Invariant**: Every company has exactly one set of books, isolated from all others.

#### Flow B: Accessing a Company to Work

1. User provides:
    - Which company they want to work on (slug/identifier)
    - Their username + password for that company
2. System:
    - Finds the company
    - Verifies the user belongs to it and credentials match
    - Grants access to that company's books only
3. User now works only within this company's data (receipts, payments, reports, etc.)

**Invariant**: No user can see or affect data from another company unless they are global superadmin (and even then only metadata, not accounting details).

#### Flow C: Recording Money Coming In (Receipt / Payment Received)

1. User wants to record money received (cash sale, customer payment, refund, etc.).
2. User specifies:
    - Date received
    - Amount
    - How received (cash, bank transfer, etc.)
    - Into which account (Cash, Bank Maybank, etc.)
    - From whom (select existing customer or type name + description)
    - Optional reference / notes
3. If splitting the receipt:
    - User adds one or more lines
    - Each line: amount + either:
        - Link to existing customer invoice (AR)
        - Direct income account (e.g. Service Revenue)
4. User saves as draft (can edit later) or marks as final/posted.
5. When posted:
    - System records the receipt permanently
    - Creates corresponding double-entry in general ledger
    - Updates account balances
    - Freezes linked party/account/invoice references by exact physical record id used at posting time
    - Logs who posted and when

**Invariant**: Total amount received must equal sum of line amounts.  
**Invariant**: Posted receipt cannot be edited — only voided/cancelled (with reason).

#### Flow D: Recording Money Going Out (Payment Voucher / Expense)

Symmetric to incoming, but opposite direction:

1. User records payment to supplier, utility, salary, etc.
2. Specifies:
    - Date
    - Amount
    - Payment method
    - From which account (Bank, Cash)
    - To whom (select supplier or type name + description)
3. If splitting:
    - Lines: amount + either:
        - Link to supplier invoice (AP)
        - Direct expense account (Utilities, Salary, Rent)
4. Save draft or post → creates journal entry (debit expense/AP, credit bank/cash)
5. When posted:
    - System freezes linked party/account/invoice references by exact physical record id used at posting time

**Invariant**: Same as receipts — posted = locked.

#### Flow E: Manual Adjustment / Internal Transfer

1. User needs to move money internally (cash → bank) or correct error.
2. User enters:
    - Date
    - Description
    - Multiple debit/credit lines (account + amount + memo)
3. System checks: total debit = total credit
4. User posts → journal entry created, balances updated, locked forever
5. If later error discovered → user creates reversing entry + new correct entry
6. Posted journal lines must retain the exact physical account record id used at posting time

**Invariant**: Posted manual journals are never edited — only reversed + replaced.

#### Flow F: Managing People Inside a Company

1. Company admin logs in
2. Goes to user management area
3. Can:
    - Add new user (username, password, name, role)
    - Change role / deactivate user
    - Reset any user's password
4. All changes logged with who did it and when

**Invariant**: Only company admins can manage users. Global superadmin cannot see or edit user passwords inside companies (only reset if locked out).

#### Flow G: Viewing Financial Status

1. Logged-in user selects report type and period/date
2. System shows:
    - Trial balance (all accounts balances)
    - Profit & Loss (income - expenses)
    - Balance Sheet (assets vs liabilities + equity)
    - Cash book (transactions on cash/bank accounts)
    - General ledger (all movements for one account)
3. Reports always use current/active versions of accounts/documents

**Invariant**: Reports only include posted entries. Drafts are excluded.

### Summary of Key Business Invariants

- Posted financial transactions are immutable
- Corrections always create new entries (reverse + correct)
- Every company has completely separate books
- Global superadmin manages companies, not accounting data
- Company admin manages users in their company
- Username is the login identifier (email optional)
- All money movements go through double-entry (debit = credit always)
- Posted documents must retain exact versioned references by physical id for linked master records

This is now pure business logic / workflow level — no UI, no endpoints, no technical naming.
