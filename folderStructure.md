backend/
├── src/
│   ├── actions/
│   │   ├── index.js                    # Central action map (dispatcher)
│   │   │
│   │   ├── crud/                       # Foundation DB-facing API with hard integrity guards
│   │   │   ├── accounts.js
│   │   │   ├── receipts.js
│   │   │   ├── payments.js
│   │   │   ├── invoices.js             # ← includes invoice lines logic
│   │   │   ├── parties.js
│   │   │   ├── users.js
│   │   │   └── auditLog.js             # tenant audit log foundation
│   │   │
│   │   ├── global/                     # Global superadmin flows
│   │   │   └── globalActions.js
│   │   │
│   │   ├── daily/                      # Workflow and UI-facing accounting logic built on top of CRUD
│   │   │   ├── receiptFlows.js
│   │   │   ├── paymentFlows.js
│   │   │   ├── invoiceFlows.js
│   │   │   └── manualJournal.js
│   │   │
│   │   ├── reporting/                  # All reports
│   │   │   └── reports.js
│   │   │
│   │   └── orgAdmin/                   # Organization admin tasks
│   │       └── orgAdmin.js
│   │
│   ├── db/
│   │   ├── master/
│   │   │   ├── index.js
│   │   │   └── schema.sql
│   │   │
│   │   ├── tenant/
│   │   │   ├── index.js                # getTenantDb, createTenantDb
│   │   │   └── schema.sql              # full tenant schema
│   │   │
│   │   └── utils.js
│   │
│   ├── middleware/
│   │   ├── auth.js
│   │   └── error.js
│   │
│   ├── utils/
│   │   ├── jwt.js
│   │   ├── uuid.js
│   │   └── response.js
│   │
│   └── app.js                          # Koa app setup + router
│
├── database/
│   ├── master.db
│   └── tenants/
│
├── scripts/
│   └── setup-master.js                 # one-time master setup
│
├── .env
├── .env.example
├── package.json
└── README.md
