# Hospital Resource Management System

This repository is being transitioned from an electronic resource portal into a hospital resource management system (HRMS) built with Flutter and Supabase.

## Current implementation status

The first HRMS database foundation is in [`supabase/migrations/001_hrms_inventory_foundation.sql`](supabase/migrations/001_hrms_inventory_foundation.sql). It adds tenant-scoped hospitals, departments, memberships, warehouses, inventory items, medicine batches, stock balances, and an append-only movement history. A PostgreSQL function applies stock movements atomically, checks membership and permissions, prevents negative stock, and blocks issue of expired or quarantined batches.

The Flutter app now has hospital-scoped inventory browsing, item creation, medicine batch registration, stock receipt/issue/adjustment/return/wastage entry with movement history, and hospital administrator screens for departments and warehouses. Its role-based dashboard shows hospital-specific stock, low-stock alerts, medicine expiry counts, recent movements, and shortcuts based on active membership roles. Data-entry forms use grouped sections, responsive field grids, input validation, and date pickers. Public self-registration has been removed from the sign-in flow; hospital access must be provisioned by an administrator. The original e-resource screens remain in the source but are no longer part of the main navigation. Procurement, department requests/approvals, equipment maintenance, membership administration, operational reports, durable notifications, and offline synchronization still need implementation. Do not treat this repository as a production-ready hospital inventory system.

## Stack

- Flutter for Web and Android
- Supabase Auth, PostgreSQL, Storage, and Realtime
- PostgreSQL Row Level Security for tenant-scoped data
- `ChangeNotifier` app state and `go_router` navigation

## Database setup

1. Create a Supabase project and configure authentication.
2. Apply the existing profile/auth schema required by the current app, then apply migrations in order from `supabase/migrations/` using the Supabase CLI or SQL editor.
3. Provision the initial hospital, department, warehouse, and administrator membership through a trusted administrative process. Membership changes are intentionally not exposed to ordinary client users.
4. Keep the Supabase service-role key and database credentials out of Flutter and Web builds. Configure only the project URL and publishable/anon key in the local environment.
5. Review and test all RLS policies in a non-production project before adding real operational data.

The inventory tables are isolated by `hospital_id`. Authenticated users can read records only for hospitals where they have an active membership. Stock balances and movement records cannot be directly inserted, updated, or deleted by client roles; use `record_stock_movement(...)` for receipts, issues, adjustments, returns, wastage, and transfer legs.

## Run the Flutter app

```bash
flutter pub get
flutter run -d chrome
flutter run -d android
```

Configure the Supabase project URL and publishable client key using the environment mechanism in `lib/core/env.dart`. Never include a service-role key in the client.

## Planned delivery sequence

1. Hospital onboarding, memberships, roles, and location administration.
2. Inventory screens and validated receiving, issue, transfer, count, and adjustment workflows.
3. Medicine FEFO, expiry, recall, quarantine, and disposal workflows.
4. Department requests, approvals, suppliers, requisitions, purchase orders, and goods receipts.
5. Equipment registry, maintenance, alerts, reports, audit views, and notifications.
6. Offline behavior, accessibility, security/concurrency coverage, and production operations.

Each module needs matching Flutter screens and services, database authorization, validation and error states, audit behavior, and automated coverage before it should be considered complete.
