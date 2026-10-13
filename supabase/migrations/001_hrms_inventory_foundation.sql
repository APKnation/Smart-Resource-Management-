-- HRMS inventory foundation. Apply after the existing profile/auth schema.
-- Stock balances are changed only by record_stock_movement(), never by client updates.

create extension if not exists pgcrypto;

create type public.hrms_membership_role as enum (
  'hospital_admin', 'inventory_manager', 'storekeeper', 'pharmacist',
  'procurement_officer', 'department_head', 'healthcare_worker',
  'biomedical_engineer', 'finance_officer', 'auditor'
);
create type public.hrms_item_kind as enum ('supply', 'medicine');
create type public.hrms_movement_kind as enum ('receipt', 'issue', 'adjustment', 'transfer_in', 'transfer_out', 'return', 'wastage');

create table public.hospitals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  name text not null,
  code text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (hospital_id, name),
  unique (hospital_id, code),
  unique (id, hospital_id)
);

create table public.hrms_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  hospital_id uuid not null references public.hospitals(id) on delete cascade,
  department_id uuid,
  role public.hrms_membership_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, hospital_id, department_id, role),
  foreign key (department_id, hospital_id) references public.departments(id, hospital_id)
);
create index hrms_memberships_user_hospital_idx on public.hrms_memberships(user_id, hospital_id) where is_active;

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  department_id uuid,
  name text not null,
  location text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (hospital_id, name),
  unique (id, hospital_id),
  foreign key (department_id, hospital_id) references public.departments(id, hospital_id)
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  item_code text not null,
  name text not null,
  description text,
  kind public.hrms_item_kind not null default 'supply',
  unit text not null,
  minimum_stock numeric(14,3) not null default 0 check (minimum_stock >= 0),
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (hospital_id, item_code),
  unique (id, hospital_id)
);

create table public.inventory_batches (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  item_id uuid not null,
  batch_number text not null,
  manufactured_on date,
  expires_on date,
  unit_cost numeric(14,2) check (unit_cost is null or unit_cost >= 0),
  supplier_name text,
  is_quarantined boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (item_id, hospital_id) references public.inventory_items(id, hospital_id),
  unique (id, hospital_id),
  unique (item_id, batch_number)
);

create table public.stock_balances (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  warehouse_id uuid not null,
  item_id uuid not null,
  batch_id uuid,
  quantity numeric(14,3) not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (warehouse_id, item_id, batch_id),
  foreign key (warehouse_id, hospital_id) references public.warehouses(id, hospital_id),
  foreign key (item_id, hospital_id) references public.inventory_items(id, hospital_id),
  foreign key (batch_id, hospital_id) references public.inventory_batches(id, hospital_id)
);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  warehouse_id uuid not null,
  item_id uuid not null,
  batch_id uuid,
  kind public.hrms_movement_kind not null,
  quantity numeric(14,3) not null check (quantity > 0),
  reference text,
  reason text,
  actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (warehouse_id, hospital_id) references public.warehouses(id, hospital_id),
  foreign key (item_id, hospital_id) references public.inventory_items(id, hospital_id),
  foreign key (batch_id, hospital_id) references public.inventory_batches(id, hospital_id)
);
create index stock_movements_hospital_created_idx on public.stock_movements(hospital_id, created_at desc);
create index stock_balances_item_idx on public.stock_balances(hospital_id, item_id);

create or replace function public.hrms_has_membership(p_hospital_id uuid, p_roles public.hrms_membership_role[] default null)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.hrms_memberships m
    where m.user_id = auth.uid() and m.hospital_id = p_hospital_id and m.is_active
      and (p_roles is null or m.role = any(p_roles))
  );
$$;
revoke all on function public.hrms_has_membership(uuid, public.hrms_membership_role[]) from public;
grant execute on function public.hrms_has_membership(uuid, public.hrms_membership_role[]) to authenticated;

-- Atomic receipt/issue/adjustment. The row lock and nonnegative check prevent
-- concurrent issues from overspending stock. Expired/quarantined batches cannot be issued.
create or replace function public.record_stock_movement(
  p_hospital_id uuid,
  p_warehouse_id uuid,
  p_item_id uuid,
  p_batch_id uuid,
  p_kind public.hrms_movement_kind,
  p_quantity numeric,
  p_reason text default null,
  p_reference text default null
) returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_balance numeric(14,3);
  v_roles public.hrms_membership_role[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;

  v_roles := case when p_kind in ('receipt', 'adjustment', 'wastage')
    then array['hospital_admin','inventory_manager','pharmacist']::public.hrms_membership_role[]
    else array['hospital_admin','inventory_manager','storekeeper','pharmacist']::public.hrms_membership_role[] end;
  if not public.hrms_has_membership(p_hospital_id, v_roles) then raise exception 'Not authorized for this hospital operation'; end if;

  if p_batch_id is not null then
    perform 1 from public.inventory_batches b
    where b.id = p_batch_id and b.hospital_id = p_hospital_id
      and (p_kind <> 'issue' or (not b.is_quarantined and (b.expires_on is null or b.expires_on >= current_date)))
    for update;
    if not found then raise exception 'Batch not found or unavailable for issue'; end if;
  elsif exists (select 1 from public.inventory_items i where i.id = p_item_id and i.hospital_id = p_hospital_id and i.kind = 'medicine') then
    raise exception 'Medicine movements require a batch';
  end if;

  insert into public.stock_balances(hospital_id, warehouse_id, item_id, batch_id, quantity)
  values (p_hospital_id, p_warehouse_id, p_item_id, p_batch_id, 0)
  on conflict (warehouse_id, item_id, batch_id) do nothing;

  select quantity into v_balance from public.stock_balances
  where warehouse_id = p_warehouse_id and item_id = p_item_id and batch_id is not distinct from p_batch_id
  for update;

  if p_kind in ('issue', 'wastage', 'transfer_out') and v_balance < p_quantity then
    raise exception 'Insufficient stock';
  end if;

  update public.stock_balances
  set quantity = case when p_kind in ('issue','wastage','transfer_out') then quantity - p_quantity else quantity + p_quantity end,
      updated_at = now()
  where warehouse_id = p_warehouse_id and item_id = p_item_id and batch_id is not distinct from p_batch_id;

  insert into public.stock_movements(hospital_id, warehouse_id, item_id, batch_id, kind, quantity, reason, reference, actor_id)
  values (p_hospital_id, p_warehouse_id, p_item_id, p_batch_id, p_kind, p_quantity, p_reason, p_reference, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.record_stock_movement(uuid, uuid, uuid, uuid, public.hrms_movement_kind, numeric, text, text) from public;
grant execute on function public.record_stock_movement(uuid, uuid, uuid, uuid, public.hrms_movement_kind, numeric, text, text) to authenticated;

alter table public.hospitals enable row level security;
alter table public.departments enable row level security;
alter table public.hrms_memberships enable row level security;
alter table public.warehouses enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_batches enable row level security;
alter table public.stock_balances enable row level security;
alter table public.stock_movements enable row level security;

create policy "members read hospitals" on public.hospitals for select to authenticated
  using (public.hrms_has_membership(id));
create policy "members read departments" on public.departments for select to authenticated
  using (public.hrms_has_membership(hospital_id));
create policy "hospital admins manage departments" on public.departments for all to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin']::public.hrms_membership_role[]));
create policy "users read own memberships" on public.hrms_memberships for select to authenticated
  using (user_id = auth.uid() or public.hrms_has_membership(hospital_id, array['hospital_admin']::public.hrms_membership_role[]));
create policy "members read warehouses" on public.warehouses for select to authenticated
  using (public.hrms_has_membership(hospital_id));
create policy "hospital admins manage warehouses" on public.warehouses for all to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin']::public.hrms_membership_role[]));
create policy "members read inventory items" on public.inventory_items for select to authenticated
  using (public.hrms_has_membership(hospital_id));
create policy "inventory managers maintain items" on public.inventory_items for all to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','pharmacist']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','pharmacist']::public.hrms_membership_role[]));
create policy "members read batches" on public.inventory_batches for select to authenticated
  using (public.hrms_has_membership(hospital_id));
create policy "inventory managers maintain batches" on public.inventory_batches for all to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','pharmacist']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','pharmacist']::public.hrms_membership_role[]));
create policy "members read stock balances" on public.stock_balances for select to authenticated
  using (public.hrms_has_membership(hospital_id));
create policy "members read stock movements" on public.stock_movements for select to authenticated
  using (public.hrms_has_membership(hospital_id));

revoke insert, update, delete on public.stock_balances, public.stock_movements from anon, authenticated;
grant select on public.hospitals, public.departments, public.hrms_memberships, public.warehouses,
  public.inventory_items, public.inventory_batches, public.stock_balances, public.stock_movements to authenticated;
grant insert, update, delete on public.inventory_items, public.inventory_batches to authenticated;
grant insert, update, delete on public.departments, public.warehouses to authenticated;

