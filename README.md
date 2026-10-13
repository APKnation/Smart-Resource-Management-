# Hospital Resource Management System

This repository is being transitioned from an electronic resource portal into a hospital resource management system (HRMS) built with Flutter and Supabase.

## Current implementation status

The database foundation is in [`supabase/migrations/001_hrms_inventory_foundation.sql`](supabase/migrations/001_hrms_inventory_foundation.sql). It adds tenant-scoped hospitals, departments, memberships, warehouses, inventory items, medicine batches, stock balances, and movement history. [`002_hrms_workflows.sql`](supabase/migrations/002_hrms_workflows.sql) adds department requests and reviews, atomic stock transfers, suppliers and purchase requisitions, medical equipment and maintenance work orders, and hospital user/role administration.

The Flutter app has hospital-scoped inventory, stock movement, facilities, requests and approvals, transfers, procurement, equipment and maintenance, hospital user management, and operational inventory reports in the sidebar. Forms and actions are shown according to the signed-in user's active hospital roles, while RLS and database functions enforce access on the server. The dashboard shows hospital-specific stock, low-stock alerts, medicine expiry counts, recent movements, and role-based shortcuts. Public self-registration has been removed from the sign-in flow; membership assignment is for hospital administrators and only works for an existing account email. Notifications and offline synchronization are not implemented. Do not treat this repository as a production-ready hospital inventory system.

## Stack

- Flutter for Web and Android
- Supabase Auth, PostgreSQL, Storage, and Realtime
- PostgreSQL Row Level Security for tenant-scoped data
- `ChangeNotifier` app state and `go_router` navigation

## Database setup

1. Create a Supabase project and configure authentication.
2. Apply the existing profile/auth schema required by the current app, then apply `001_hrms_inventory_foundation.sql` followed by `002_hrms_workflows.sql` using the Supabase CLI or SQL editor.
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

## Scope notes

The current workflows provide request review, supplier and requisition tracking, asset registration, maintenance status tracking, stock transfers, and summary reporting. They do not yet provide full purchase orders/goods receiving, clinical patient records, alerts/notifications, offline mode, or a complete audit/report export. Review and exercise all RLS policies in a non-production project before using real hospital data.
