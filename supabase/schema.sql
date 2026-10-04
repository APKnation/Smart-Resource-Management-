-- ============================================================
-- E-Resources Management System - Supabase Schema
-- Run this whole file in: Supabase Dashboard -> SQL Editor
-- ============================================================

-- ---------- 1. ENUM TYPES ----------
create type public.user_role as enum ('admin', 'librarian', 'staff', 'user');
create type public.resource_status as enum ('pending', 'approved', 'rejected', 'archived');
create type public.resource_availability as enum ('active', 'inactive', 'restricted', 'archived');
create type public.resource_type as enum ('pdf', 'document', 'presentation', 'video', 'audio', 'image', 'link', 'other');
create type public.audit_action as enum ('create', 'update', 'delete', 'download', 'view', 'approve', 'reject', 'login', 'logout', 'restore', 'archive');
create type public.notification_type as enum ('new_resource', 'approved', 'rejected', 'updated', 'system');

-- ---------- 2. PROFILES (user accounts + roles) ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  role public.user_role not null default 'user',
  department text,
  institution text,
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 3. ROLES (managed by admins; mirrors user_role enum + extras) ----------
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  permissions jsonb not null default '[]'::jsonb,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 4. CATEGORIES ----------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  type text not null default 'subject', -- subject | type | department | institution | other
  parent_id uuid references public.categories(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (name, type)
);

-- ---------- 5. RESOURCES ----------
create table public.resources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  author text,
  resource_type public.resource_type not null default 'pdf',
  status public.resource_status not null default 'pending',
  availability public.resource_availability not null default 'active',
  storage_path text,              -- path in the private 'resources' storage bucket
  file_name text,
  file_size bigint,
  mime_type text,
  external_url text,              -- for 'link' resources
  version int not null default 1,
  current_version_id uuid,        -- set below (fk added after resource_versions exists)
  uploaded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 6. RESOURCE <-> CATEGORY ----------
create table public.resource_categories (
  resource_id uuid not null references public.resources(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  primary key (resource_id, category_id)
);

-- ---------- 7. RESOURCE VERSIONS ----------
create table public.resource_versions (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid not null references public.resources(id) on delete cascade,
  version int not null,
  storage_path text,
  file_name text,
  file_size bigint,
  mime_type text,
  notes text,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (resource_id, version)
);

alter table public.resources
  add constraint resources_current_version_fkey
  foreign key (current_version_id) references public.resource_versions(id) on delete set null;

-- ---------- 8. FAVORITES / BOOKMARKS ----------
create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  resource_id uuid not null references public.resources(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, resource_id)
);

-- ---------- 9. ACCESS LOG (views / downloads / borrowing) ----------
create table public.access_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  resource_id uuid references public.resources(id) on delete set null,
  action public.audit_action not null, -- 'view' | 'download'
  created_at timestamptz not null default now()
);

-- ---------- 10. NOTIFICATIONS ----------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text,
  type public.notification_type not null default 'system',
  link text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- 11. AUDIT TRAIL ----------
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  actor_email text,
  action public.audit_action not null,
  entity text not null,            -- 'resource', 'user', 'role', 'category', 'settings'
  entity_id text,
  entity_label text,
  details jsonb,
  created_at timestamptz not null default now()
);

-- ---------- 12. SYSTEM SETTINGS ----------
create table public.settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- SEED DATA
-- ============================================================
insert into public.roles (name, description, permissions, is_system) values
  ('admin',     'Full system administration',      '["*"]', true),
  ('librarian', 'Resource manager: upload, edit, approve, categorize', '["resource.upload","resource.update","resource.delete","resource.approve","category.manage","reports.view","audit.view"]', true),
  ('staff',     'Institutional staff: upload and manage own resources', '["resource.upload","resource.update"]', true),
  ('user',      'Regular user: search, view, download', '["resource.view","resource.download","favorites.manage"]', true);

insert into public.settings (key, value) values
  ('site_name', '"E-Resource Portal"'),
  ('allow_self_registration', 'true'),
  ('require_approval', 'true'),
  ('max_file_size_mb', '100'),
  ('allowed_file_types', '["pdf","doc","docx","ppt","pptx","xls","xlsx","txt","mp4","mp3","jpg","png","zip"]');

-- ============================================================
-- HELPERS
-- ============================================================
create or replace function public.current_role()
returns public.user_role
language sql stable security definer set search_path = public
as $$ select coalesce((select role from public.profiles where id = auth.uid()), null) $$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$ select public.current_role() = 'admin' $$;

create or replace function public.is_staff_level()
returns boolean
language sql stable security definer set search_path = public
as $$ select public.current_role() in ('admin','librarian','staff') $$;

create or replace function public.can_manage_resources()
returns boolean
language sql stable security definer set search_path = public
as $$ select public.current_role() in ('admin','librarian') $$;

-- ============================================================
-- TRIGGER FUNCTIONS
-- ============================================================
-- Auto-create a profile whenever a user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql
as $$ begin new.updated_at := now(); return new; end $$;

drop trigger if exists touch_profiles on public.profiles;
create trigger touch_profiles before update on public.profiles
  for each row execute function public.touch_updated_at();
drop trigger if exists touch_resources on public.resources;
create trigger touch_resources before update on public.resources
  for each row execute function public.touch_updated_at();
drop trigger if exists touch_categories on public.categories;
create trigger touch_categories before update on public.categories
  for each row execute function public.touch_updated_at();
drop trigger if exists touch_roles on public.roles;
create trigger touch_roles before update on public.roles
  for each row execute function public.touch_updated_at();

-- Auto-versioning: when a resource's file is replaced, insert a version row
create or replace function public.resource_version_snapshot()
returns trigger language plpgsql security definer set search_path = public
as $$
declare new_ver int;
begin
  if new.storage_path is distinct from old.storage_path then
    select coalesce(max(version), 0) + 1 into new_ver from public.resource_versions where resource_id = new.id;
    insert into public.resource_versions (resource_id, version, storage_path, file_name, file_size, mime_type, notes, uploaded_by)
    values (new.id, new_ver, new.storage_path, new.file_name, new.file_size, new.mime_type, 'Auto-saved version', new.uploaded_by)
    returning id into new.current_version_id;
  end if;
  return new;
end $$;

drop trigger if exists resource_version_snapshot_trg on public.resources;
create trigger resource_version_snapshot_trg
  before update on public.resources
  for each row execute function public.resource_version_snapshot();

-- ---------- Notification automation ----------
-- Notify admins/librarians when a new resource awaits approval
create or replace function public.notify_approvers_on_upload()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.status = 'pending' then
    insert into public.notifications (user_id, title, body, type, link)
    select id, 'Resource awaiting approval',
           'New resource "' || new.title || '" was submitted and needs review.',
           'new_resource', '/resources?status=pending'
    from public.profiles where role in ('admin','librarian') and is_active;
  end if;
  return new;
end $$;

drop trigger if exists notify_approvers_trg on public.resources;
create trigger notify_approvers_trg
  after insert on public.resources
  for each row execute function public.notify_approvers_on_upload();

-- Notify uploader on approve/reject; notify users on availability change
create or replace function public.notify_on_resource_change()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if new.status <> old.status then
    if new.status = 'approved' then
      insert into public.notifications (user_id, title, body, type, link)
      values (old.uploaded_by, 'Resource approved',
              'Your resource "' || new.title || '" has been approved and is now available.',
              'approved', '/resources/' || new.id::text);
    elsif new.status = 'rejected' then
      insert into public.notifications (user_id, title, body, type, link)
      values (old.uploaded_by, 'Resource rejected',
              'Your resource "' || new.title || '" was rejected during review.',
              'rejected', '/resources/' || new.id::text);
    elsif new.status = 'archived' then
      insert into public.notifications (user_id, title, body, type, link)
      values (old.uploaded_by, 'Resource archived',
              'Your resource "' || new.title || '" has been archived.',
              'system', '/resources/' || new.id::text);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists notify_resource_change_trg on public.resources;
create trigger notify_resource_change_trg
  after update on public.resources
  for each row execute function public.notify_on_resource_change();

-- ---------- Audit automation ----------
create or replace function public.audit_resource_changes()
returns trigger language plpgsql security definer set search_path = public
as $$
declare actor uuid; actor_email text;
begin
  actor := coalesce(new.uploaded_by, auth.uid());
  select email into actor_email from public.profiles where id = actor;
  if tg_op = 'INSERT' then
    insert into public.audit_logs (actor_id, actor_email, action, entity, entity_id, entity_label)
    values (actor, actor_email, 'create', 'resource', new.id::text, new.title);
  elsif tg_op = 'UPDATE' then
    if new.status is distinct from old.status then
      insert into public.audit_logs (actor_id, actor_email, action, entity, entity_id, entity_label, details)
      values (coalesce(auth.uid(), actor), actor_email,
              case new.status when 'approved' then 'approve' when 'rejected' then 'reject' when 'archived' then 'archive' else 'update' end,
              'resource', new.id::text, new.title,
              jsonb_build_object('from', old.status, 'to', new.status));
    end if;
  elsif tg_op = 'DELETE' then
    insert into public.audit_logs (actor_id, actor_email, action, entity, entity_id, entity_label)
    values (auth.uid(), null, 'delete', 'resource', old.id::text, old.title);
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists audit_resource_trg on public.resources;
create trigger audit_resource_trg
  after insert or update or delete on public.resources
  for each row execute function public.audit_resource_changes();

-- ============================================================
-- FUNCTIONS (callable from the app via rpc)
-- ============================================================
-- Log a view or download (any authenticated user)
create or replace function public.log_access(p_resource_id uuid, p_action public.audit_action)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_action not in ('view','download') then raise exception 'Invalid action'; end if;
  insert into public.access_logs (user_id, resource_id, action) values (auth.uid(), p_resource_id, p_action);
end $$;

-- Create a notification for a user
create or replace function public.send_notification(p_user_id uuid, p_title text, p_body text, p_type public.notification_type, p_link text default null)
returns void
language sql security definer set search_path = public
as $$ insert into public.notifications (user_id, title, body, type, link) values (p_user_id, p_title, p_body, p_type, p_link) $$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.categories enable row level security;
alter table public.resources enable row level security;
alter table public.resource_categories enable row level security;
alter table public.resource_versions enable row level security;
alter table public.favorites enable row level security;
alter table public.access_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;
alter table public.settings enable row level security;

-- profiles: read everyone (needed for directory); update self; admins full
create policy "profiles_read" on public.profiles for select using (true);
create policy "profiles_insert_self" on public.profiles for insert with check (id = auth.uid());
create policy "profiles_update_self" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));
create policy "profiles_admin_all" on public.profiles for all using (public.is_admin()) with check (public.is_admin());

-- roles: everyone reads; only admin writes
create policy "roles_read" on public.roles for select using (true);
create policy "roles_admin_write" on public.roles for all using (public.is_admin()) with check (public.is_admin());

-- categories: everyone reads; can_manage_resources writes
create policy "categories_read" on public.categories for select using (true);
create policy "categories_write" on public.categories for all using (public.can_manage_resources()) with check (public.can_manage_resources());

-- resources: published+active visible to all authenticated; staff-level sees all (incl. pending/rejected/archived)
create policy "resources_read" on public.resources for select using (
  public.is_staff_level()
  or (status = 'approved' and availability in ('active','restricted'))
);
create policy "resources_insert" on public.resources for insert with check (
  auth.uid() = uploaded_by and public.is_staff_level()
);
create policy "resources_update" on public.resources for update using (
  public.can_manage_resources() or (public.is_staff_level() and uploaded_by = auth.uid())
) with check (
  public.can_manage_resources() or (public.is_staff_level() and uploaded_by = auth.uid())
);
create policy "resources_delete" on public.resources for delete using (public.can_manage_resources());

-- resource_categories: mirror resource visibility
create policy "rc_read" on public.resource_categories for select using (
  exists (select 1 from public.resources r where r.id = resource_id and (public.is_staff_level() or (r.status = 'approved' and r.availability in ('active','restricted'))))
);
create policy "rc_write" on public.resource_categories for all using (public.can_manage_resources()) with check (public.can_manage_resources());

-- resource_versions: visible like resources; insert by staff
create policy "rv_read" on public.resource_versions for select using (
  exists (select 1 from public.resources r where r.id = resource_id and (public.is_staff_level() or (r.status = 'approved' and r.availability in ('active','restricted'))))
);
create policy "rv_insert" on public.resource_versions for insert with check (
  exists (select 1 from public.resources r where r.id = resource_id and (public.is_staff_level() and r.uploaded_by = auth.uid() or public.can_manage_resources()))
);

-- favorites: user's own
create policy "fav_all" on public.favorites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- access_logs: insert own via rpc (log_access), staff-level can read
create policy "al_insert" on public.access_logs for insert with check (auth.uid() = user_id);
create policy "al_read" on public.access_logs for select using (public.is_staff_level() or user_id = auth.uid());

-- notifications: user's own; admins can insert (via trigger functions)
create policy "notif_read" on public.notifications for select using (auth.uid() = user_id);
create policy "notif_update_own" on public.notifications for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "notif_admin_insert" on public.notifications for insert with check (public.is_admin());

-- audit_logs: read for admin+librarian
create policy "audit_read" on public.audit_logs for select using (public.current_role() in ('admin','librarian'));

-- settings: everyone reads, admin writes
create policy "settings_read" on public.settings for select using (true);
create policy "settings_write" on public.settings for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- STORAGE: private 'resources' bucket
-- ============================================================
insert into storage.buckets (id, name, public) values ('resources', 'resources', false);

create policy "storage_upload" on storage.objects for insert to authenticated with check (
  bucket_id = 'resources' and public.is_staff_level()
);
create policy "storage_read" on storage.objects for select to authenticated using (
  bucket_id = 'resources'
  and (public.is_staff_level()
       or exists (
         select 1 from public.resources r
         where r.storage_path = name
           and r.status = 'approved' and r.availability in ('active','restricted')
       ))
);
create policy "storage_update" on storage.objects for update to authenticated using (
  bucket_id = 'resources' and public.is_staff_level()
);
create policy "storage_delete" on storage.objects for delete to authenticated using (
  bucket_id = 'resources' and public.can_manage_resources()
);

-- ============================================================
-- DEFAULT ADMIN
-- ============================================================
-- 1) Sign up the user in the app (or Dashboard -> Authentication -> Add user)
--    with email: admin@eresource.local  password: Admin@12345
-- 2) Then run this to grant the admin role:
--    update public.profiles set role = 'admin' where email = 'admin@eresource.local';
-- ============================================================
