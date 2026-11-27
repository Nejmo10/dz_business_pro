# DzBusiness Pro

Complete commercial management and point-of-sale desktop application for Windows 10/11, built with Flutter and a persistent SQLite database.

- **Platform:** Windows desktop (offline-first, single-user)
- **Default currency:** Algerian Dinar (DZD), stored as integer minor units (centimes); financial accounting never uses floating point
- **Languages:** Arabic (full RTL) and French (LTR), switchable at runtime
- **Architecture:** feature-based clean architecture (app / core / data / features)

## Getting started

Requirements: Flutter stable with Windows desktop support (any platform that can run `flutter windows` builds).

```sh
flutter pub get
flutter run -d windows        # run in development
flutter build windows --release
```

On first launch an onboarding wizard collects business identity, language, currency, tax and receipt preferences. The business profile is saved permanently to SQLite and wizard is skipped on later launches. It can be edited later from **Settings**.

The database is created in the platform application-data directory (`getApplicationSupportDirectory`), never in the build directory, and is never reset on startup.

## Modules

| Module | Description |
|---|---|
| Dashboard | DB-driven KPIs, charts, quick actions, recent activity |
| POS | Cart, barcode entry, search, discounts, tax, cash/card/transfer/partial/credit payments, single-transaction checkout with full rollback |
| Products | Bilingual products, SKU/barcode, cost/retail/wholesale prices, stock limits, images, CSV export/import, archive |
| Inventory | Stock in/out, manual adjustments, full movement history, low-stock and out-of-stock alerts, valuation |
| Customers / Suppliers | Profiles, running balances, partial payments, purchase history, statements |
| Purchases | Supplier orders, stock input, cost updates, payables |
| Expenses | Categories, monthly/yearly analysis |
| Invoices & Returns | Unique numbering, PDF/print (A4, 80mm, 58mm), returns with stock and balance correction, audit-safe cancellation |
| Finance | Cash register (open/close/diff), cash movements, gross/net profit separation |
| Reports | Sales, purchases, expenses, profits, inventory, payments — CSV export |
| Settings & Backup | Profile editing, preferences, backup/restore with pre-restore safety copy |

## Technical design highlights

- **Money:** every monetary column is an integer in minor units (`..._c`). No floats touch financial math.
- **Transactions:** sales, purchases, returns and cancellations run in a single SQLite transaction; any failure fully rolls back (validated by tests).
- **Inventory:** the `stock_movements` table records every stock change with `balance_after`; stock is never modified outside a recorded movement.
- **Migrations:** schema versioning via `Migrations.migrate`; `PRAGMA integrity_check` runs on open.
- **Backup:** `VACUUM INTO` snapshots, backup history, pre-restore safety copy.
- **Audit:** destructive and commercial operations write `audit_logs` rows.

## Tests

```sh
flutter test
```

`test/financial_core_test.dart` covers schema creation and integrity, totals math (discount/tax on integer cents), product CRUD with movement audit, the full sale flow (totals, stock, payments, customer debt), insufficient-stock rollback, credit sales, purchases with tax and extra costs, supplier payables, returns (restock, refund, over-return rejection), sale cancellation, gross/net profit from real records, cash register open/close with expected-cash computation and difference, and backup/restore round-trip.

Analyze with `flutter analyze` (0 errors / 0 warnings; only SDK `material.dart` deprecation infos emitted by recent toolchains).

## Project layout

```
lib/app/        app bootstrap, router, shell, theme, l10n, app state
lib/core/       constants, formatting (money/dates), reusable UI kit, services
lib/data/       app_database, migrations, models, repositories
lib/features/   onboarding, dashboard, pos, products, categories, inventory,
                customers, suppliers, purchases, expenses, invoices,
                finance, reports, settings, backup
lib/printing/   PDF/receipt generation and printing services
```
