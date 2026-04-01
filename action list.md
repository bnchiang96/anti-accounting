Here is the **full high-level action list** for the entire system, organized in a clean table format.

The list covers all major logical actions/processes we have defined so far. Each action includes:
- **Category**
- **Action Name** (descriptive, not endpoint-specific)
- **Who Can Perform It** (persona/role)
- **Purpose / What It Does**
- **Main Restrictions / Rules**

| #  | Category                  | Action Name                              | Who Can Perform It                  | Purpose / What It Does                                                                 | Main Restrictions / Rules                                                                 |
|----|---------------------------|------------------------------------------|-------------------------------------|----------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| 1  | Global Superadmin Setup   | Setup initial global superadmin          | System (one-time script)            | Create master.db and default superadmin user                                           | Run once only; default credentials must be changed immediately                           |
| 2  | Global Superadmin Auth    | Login as global superadmin               | Anyone with global credentials      | Gain access to company management functions                                            | Grants metadata access only (no accounting data)                                          |
| 3  | Company Management        | Create new company                       | Global superadmin                   | Register new organization + create isolated tenant DB + defaults + first admin user   | Slug must be unique; requires company details + first admin credentials                   |
| 4  | Company Management        | List all companies                       | Global superadmin                   | View list of all registered companies                                                  | Shows only metadata (slug, name, status, created date)                                    |
| 5  | Company Management        | Suspend company                          | Global superadmin                   | Temporarily block access to a company                                                  | Company cannot be deleted; suspends all logins                                            |
| 6  | Company Management        | Reactivate suspended company             | Global superadmin                   | Restore access to a suspended company                                                  | Logs reactivation event                                                                   |
| 7  | Company Management        | Reset password for organization admin    | Global superadmin                   | Reset password for a specific admin user in a company                                  | Must specify company + target username; sets must-change-password flag                    |
| 8  | Company Management        | View organization audit log              | Global superadmin                   | See history of company creation/suspend/reactivate events                              | Read-only; global scope only                                                              |
| 9  | Company Login             | Login to a specific company              | Any registered user in that company | Gain access to one company’s books                                                     | Requires company identifier + username + password; suspended companies block login       |
| 10 | User Management           | List users in company                    | Organization admin                  | View all users in this company                                                         | Shows username, name, role, status, last login                                            |
| 11 | User Management           | Create new user                          | Organization admin                  | Add new staff user to this company                                                     | Username unique in company; valid role; new user must change password on first login      |
| 12 | User Management           | Update user (name, role, status)         | Organization admin                  | Change user details or role or activate/deactivate                                     | Cannot lower own role or deactivate self; all changes logged                              |
| 13 | User Management           | Reset password for user                  | Organization admin                  | Reset any user’s password in this company                                              | Sets must-change-password flag; logged                                                    |
| 14 | Receipt (Incoming)        | Create receipt                           | Any user with posting permission    | Record money received (cash sale, AR payment, etc.)                                    | Can save as draft or post directly; total must match lines                                |
| 15 | Receipt (Incoming)        | Update draft receipt                     | Creator or admin                    | Edit receipt while still draft                                                         | Only allowed if draft; creates new version (old superseded)                               |
| 16 | Receipt (Incoming)        | Post receipt to general ledger           | Creator or admin                    | Finalize receipt and post to GL                                                        | Must balance; creates journal entry; locks receipt; updates balances; freezes linked party/account/invoice record ids used at posting |
| 17 | Receipt (Incoming)        | Allocate receipt to invoice(s)           | Any user                            | Link receipt to AR invoice(s) (partial/full payment)                                   | Only on posted receipts; updates invoice status                                           |
| 18 | Receipt (Incoming)        | Void / cancel receipt                    | Admin                               | Cancel posted receipt (e.g. error)                                                     | Requires reason; creates reversing journal entry                                          |
| 19 | Payment (Outgoing)        | Create payment                           | Any user with posting permission    | Record money paid out (supplier, expense, etc.)                                        | Same rules as receipt                                                                     |
| 20 | Payment (Outgoing)        | Update draft payment                     | Creator or admin                    | Edit payment while draft                                                               | Same as receipt                                                                           |
| 21 | Payment (Outgoing)        | Post payment to general ledger           | Creator or admin                    | Finalize payment and post to GL                                                        | Same as receipt; freezes linked party/account/invoice record ids used at posting         |
| 22 | Payment (Outgoing)        | Allocate payment to invoice(s) or expense| Any user                            | Link payment to AP invoice(s) or direct expense account                                | Partial/full allowed; updates invoice status                                              |
| 23 | Payment (Outgoing)        | Void / cancel payment                    | Admin                               | Cancel posted payment                                                                  | Same as receipt                                                                           |
| 24 | Manual Journal            | Create & post manual journal entry       | Any user with posting permission    | Record internal transfer, adjustment, correction                                       | Debit must equal credit; can be backdated; posted → immutable; journal lines freeze exact account record ids used at posting |
| 25 | Manual Journal            | Reverse posted journal entry             | Any user with posting permission    | Correct error in posted journal                                                        | Creates new reversing entry (negative amounts); links to original                         |
| 26 | Reports & Views           | View trial balance                       | All logged-in users (role-based)    | Show current balances grouped by subtype/type                                          | Uses current account balances; posted entries only                                        |
| 27 | Reports & Views           | View profit & loss statement             | All logged-in users                 | Income - cost of sales - expenses for a period                                         | Period-based                                                                              |
| 28 | Reports & Views           | View balance sheet                       | All logged-in users                 | Assets vs liabilities + equity as of a date                                            | As-of date                                                                                |
| 29 | Reports & Views           | View cash book / bank transactions       | All logged-in users                 | List receipts/payments for cash/bank accounts                                          | Filter by account + date range                                                            |
| 30 | Reports & Views           | View general ledger for an account       | All logged-in users                 | Chronological list of all movements for one account (journal entries)                  | Running balance calculated; posted entries only                                           |
| 31 | Reports & Views           | View all journal entries                 | All logged-in users (role-based)    | Full list of all posted journal entries (filtered by date/source/reference)            | No running balance unless account selected; read-only                                     |
| 32 | Reports & Views           | View company audit log                   | Organization admin + viewer role    | See all changes in this company (who changed what, when)                               | Read-only; company scope only                                                             |

### Total: **32 major actions**

- **Global superadmin exclusive**: 7 actions (1–7)
- **Organization admin exclusive**: 5 actions (8–13)
- **Daily accounting**: 12 actions (14–25)
- **Reports & views**: 7 actions (26–32)

### Quick Access Summary

- Global superadmin → company lifecycle only (no accounting data access)
- Organization admin → user management + full accounting
- Accountant/normal user → accounting + reports
- Viewer → reports + audit log only

This is now a complete, high-level action inventory.
