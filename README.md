# E-Resource Portal

A full-featured **Electronic Resources Management System** built with **Flutter** (**Web + Android**) and **Supabase** (Postgres, Auth, Storage, Realtime).

## Features

| Area | What's included |
|---|---|
| **Accounts & Auth** | Register, log in, log out, password reset, self-service profile editing |
| **Roles** | Admin, Librarian, Staff, User — managed by admins, enforced in the UI **and** the database (RLS) |
| **Resource management** | Add, edit, view, delete resources (PDF, docs, slides, video, audio, images, links) |
| **Categorization** | Multi-category tagging by subject / type / department / institution, with parent categories |
| **Upload** | Client-validated uploads (type + size) to a **private** Supabase Storage bucket |
| **Search** | Keyword search across title/description/author + filters by type and category |
| **View & download** | Short-lived signed URLs; every view/download is recorded |
| **Access control** | Role-based UI + Row Level Security policies at the database level |
| **Approval workflow** | Staff uploads stay *pending* until an admin/librarian approves; auto-notifications |
| **Versioning** | File replacement auto-snapshots a version; restore any prior version |
| **Access tracking** | Views and downloads logged per user (auditable usage history) |
| **Favorites** | Bookmark resources for quick access |
| **Notifications** | Realtime in-app notifications (new submissions, approvals, rejections, broadcasts) |
| **Reports & analytics** | Usage stats, 14-day download chart, most-downloaded list, recent activity |
| **User management** | Admins list/search users, change roles, deactivate/reactivate accounts |
| **Audit trail** | Automatic audit log of uploads, updates, approvals, deletions, broadcasts |
| **Availability** | Resources can be active, inactive, restricted, or archived |
| **System administration** | Site settings, category management, role/permission definitions, broadcast messages |

## Project layout

```
lib/
  core/          constants, env, theme, utils
  models/        data models + enums
  services/      auth, resources, admin (Supabase calls)
  app_state.dart global state (session, profile, favorites, notifications)
  router.dart    go_router config with auth guard
  shell.dart     responsive NavigationRail / Drawer shell
  widgets/       shared widgets
  screens/
    auth/        login, register
    admin/       approvals, categories, users, roles, reports, audit, settings
    ...          dashboard, resources, resource detail/form, favorites,
                 notifications, profile
supabase/
  schema.sql     the entire database schema — run this once
android/        Android platform (INTERNET permission pre-configured)
web/            Web platform (PWA manifest pre-configured)
```

## Setup

### 1. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) and create a project (free tier is fine).
2. Open **SQL Editor** → new query → paste the full contents of **`supabase/schema.sql`** → **Run**.
   This creates all tables, enums, RLS policies, triggers (profile creation, versioning,
   audit logging, notifications), the private `resources` storage bucket, and seed data
   (4 roles, default settings).

### 2. Create the first administrator

1. In the app (or Dashboard → Authentication → Users), sign up with e.g. `admin@yourorg.edu`.
2. In **SQL Editor**, run:

   ```sql
   update public.profiles set role = 'admin' where email = 'admin@yourorg.edu';
   ```

   That account now sees the full admin console. New self-registered users get the
   lowest-privilege role by default; promote them from **Users** in the app.

### 3. Configure the app

Create a `.env` file at the project root (or edit the existing placeholder):

```
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

Both values are in Supabase Dashboard → **Settings → API**.

> The `.env` file is loaded as a Flutter asset (already configured in `pubspec.yaml`).
> **Do not commit real keys** — `.env` is git-ignored by default; `.env.example` documents the format.

### 4. Run

```bash
flutter pub get

# Web (Chrome)
flutter run -d chrome

# Android device / emulator
flutter run -d android

# Release builds
flutter build web
flutter build apk --release
```

## How access control works

- **Users** see approved + active resources, can search, view, download, favorite.
- **Staff** can additionally upload (their submissions go to the approval queue) and edit their own items.
- **Librarians** manage resources and categories, approve/reject submissions, see reports and the audit trail.
- **Admins** do everything, including user roles, system settings, and broadcasts.
- All of this is enforced twice: in the Flutter UI (navigation/actions) and in Postgres via
  Row Level Security policies, so even direct API calls with the anon key cannot bypass it.

## Tech notes

- **State**: `AppState` (`ChangeNotifier`) + `InheritedNotifier`; no heavy frameworks.
- **Routing**: `go_router` with a redirect guard (unauthenticated users land on `/login`).
- **Realtime**: notifications arrive over a Supabase Postgres-Changes channel filtered to the signed-in user.
- **Files**: uploads go straight from the client to Storage; downloads use 5-minute signed URLs.
- **Versioning**: a DB trigger snapshots the previous file into `resource_versions` whenever a resource's file path changes; restore re-points the resource and snapshots first.
