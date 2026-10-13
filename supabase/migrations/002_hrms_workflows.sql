-- Operational modules used by the HRMS sidebar. Apply after 001_hrms_inventory_foundation.sql.

create type public.hrms_request_status as enum ('pending', 'approved', 'rejected', 'fulfilled', 'cancelled');
create type public.hrms_transfer_status as enum ('completed', 'cancelled');
create type public.hrms_procurement_status as enum ('draft', 'submitted', 'approved', 'rejected', 'received', 'cancelled');
create type public.hrms_asset_status as enum ('available', 'assigned', 'under_maintenance', 'out_of_service', 'quarantined', 'decommissioned');
create type public.hrms_maintenance_status as enum ('open', 'in_progress', 'completed', 'cancelled');

create table public.resource_requests (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  department_id uuid not null,
  requested_by uuid not null references auth.users(id),
  purpose text not null,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  required_by date,
  status public.hrms_request_status not null default 'pending',
  reviewed_by uuid references auth.users(id),
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (department_id, hospital_id) references public.departments(id, hospital_id),
  unique (id, hospital_id)
);
create table public.resource_request_lines (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  request_id uuid not null,
  item_id uuid not null,
  quantity numeric(14,3) not null check (quantity > 0),
  approved_quantity numeric(14,3) check (approved_quantity is null or approved_quantity >= 0),
  created_at timestamptz not null default now(),
  foreign key (request_id, hospital_id) references public.resource_requests(id, hospital_id) on delete cascade,
  foreign key (item_id, hospital_id) references public.inventory_items(id, hospital_id)
);

create table public.stock_transfers (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  source_warehouse_id uuid not null,
  destination_warehouse_id uuid not null,
  item_id uuid not null,
  batch_id uuid,
  quantity numeric(14,3) not null check (quantity > 0),
  reason text not null,
  reference text,
  status public.hrms_transfer_status not null default 'completed',
  actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  check (source_warehouse_id <> destination_warehouse_id),
  foreign key (source_warehouse_id, hospital_id) references public.warehouses(id, hospital_id),
  foreign key (destination_warehouse_id, hospital_id) references public.warehouses(id, hospital_id),
  foreign key (item_id, hospital_id) references public.inventory_items(id, hospital_id),
  foreign key (batch_id, hospital_id) references public.inventory_batches(id, hospital_id)
);

create table public.hrms_suppliers (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  name text not null,
  contact_name text,
  email text,
  phone text,
  address text,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (hospital_id, name),
  unique (id, hospital_id)
);
create table public.purchase_requisitions (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  department_id uuid,
  supplier_id uuid,
  title text not null,
  justification text not null,
  estimated_cost numeric(14,2) check (estimated_cost is null or estimated_cost >= 0),
  required_by date,
  status public.hrms_procurement_status not null default 'draft',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (department_id, hospital_id) references public.departments(id, hospital_id),
  foreign key (supplier_id, hospital_id) references public.hrms_suppliers(id, hospital_id)
);

create table public.medical_assets (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  department_id uuid,
  asset_tag text not null,
  name text not null,
  serial_number text,
  manufacturer text,
  model text,
  location text,
  purchased_on date,
  warranty_until date,
  status public.hrms_asset_status not null default 'available',
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (hospital_id, asset_tag),
  unique (id, hospital_id),
  foreign key (department_id, hospital_id) references public.departments(id, hospital_id)
);
create table public.maintenance_work_orders (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id),
  asset_id uuid not null,
  title text not null,
  description text not null,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  scheduled_for date,
  status public.hrms_maintenance_status not null default 'open',
  reported_by uuid not null references auth.users(id),
  assigned_to uuid references auth.users(id),
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (asset_id, hospital_id) references public.medical_assets(id, hospital_id)
);

create or replace function public.hrms_transfer_stock(
  p_hospital_id uuid, p_source_warehouse_id uuid, p_destination_warehouse_id uuid,
  p_item_id uuid, p_batch_id uuid, p_quantity numeric, p_reason text, p_reference text default null
) returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_transfer_id uuid; v_qty numeric(14,3);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  if p_source_warehouse_id = p_destination_warehouse_id then raise exception 'Choose two different warehouses'; end if;
  if not public.hrms_has_membership(p_hospital_id, array['hospital_admin','inventory_manager','storekeeper']::public.hrms_membership_role[]) then
    raise exception 'Not authorized to transfer stock';
  end if;
  if p_batch_id is not null then
    perform 1 from public.inventory_batches where id = p_batch_id and hospital_id = p_hospital_id
      and not is_quarantined and (expires_on is null or expires_on >= current_date) for update;
    if not found then raise exception 'Batch is unavailable for transfer'; end if;
  elsif exists (select 1 from public.inventory_items where id = p_item_id and hospital_id = p_hospital_id and kind = 'medicine') then
    raise exception 'Medicine transfers require a valid batch';
  end if;
  select quantity into v_qty from public.stock_balances
    where warehouse_id = p_source_warehouse_id and item_id = p_item_id and batch_id is not distinct from p_batch_id for update;
  if coalesce(v_qty, 0) < p_quantity then raise exception 'Insufficient stock at source warehouse'; end if;
  update public.stock_balances set quantity = quantity - p_quantity, updated_at = now()
    where warehouse_id = p_source_warehouse_id and item_id = p_item_id and batch_id is not distinct from p_batch_id;
  insert into public.stock_balances(hospital_id, warehouse_id, item_id, batch_id, quantity)
    values (p_hospital_id, p_destination_warehouse_id, p_item_id, p_batch_id, 0)
    on conflict (warehouse_id, item_id, batch_id) do nothing;
  update public.stock_balances set quantity = quantity + p_quantity, updated_at = now()
    where warehouse_id = p_destination_warehouse_id and item_id = p_item_id and batch_id is not distinct from p_batch_id;
  insert into public.stock_movements(hospital_id, warehouse_id, item_id, batch_id, kind, quantity, reference, reason, actor_id)
    values (p_hospital_id, p_source_warehouse_id, p_item_id, p_batch_id, 'transfer_out', p_quantity, p_reference, p_reason, auth.uid()),
           (p_hospital_id, p_destination_warehouse_id, p_item_id, p_batch_id, 'transfer_in', p_quantity, p_reference, p_reason, auth.uid());
  insert into public.stock_transfers(hospital_id, source_warehouse_id, destination_warehouse_id, item_id, batch_id, quantity, reason, reference, actor_id)
    values (p_hospital_id, p_source_warehouse_id, p_destination_warehouse_id, p_item_id, p_batch_id, p_quantity, p_reason, p_reference, auth.uid())
    returning id into v_transfer_id;
  return v_transfer_id;
end;
$$;
revoke all on function public.hrms_transfer_stock(uuid,uuid,uuid,uuid,uuid,numeric,text,text) from public;
grant execute on function public.hrms_transfer_stock(uuid,uuid,uuid,uuid,uuid,numeric,text,text) to authenticated;

create or replace function public.hrms_add_member(p_hospital_id uuid, p_email text, p_role public.hrms_membership_role, p_department_id uuid default null)
returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_user_id uuid; v_membership_id uuid;
begin
  if not public.hrms_has_membership(p_hospital_id, array['hospital_admin']::public.hrms_membership_role[]) then
    raise exception 'Only a hospital administrator can assign memberships';
  end if;
  select id into v_user_id from auth.users where lower(email) = lower(trim(p_email));
  if v_user_id is null then raise exception 'No registered account found for this email'; end if;
  select id into v_membership_id from public.hrms_memberships
    where user_id=v_user_id and hospital_id=p_hospital_id
      and department_id is not distinct from p_department_id and role=p_role;
  if v_membership_id is null then
    insert into public.hrms_memberships(user_id,hospital_id,department_id,role,is_active)
      values(v_user_id,p_hospital_id,p_department_id,p_role,true) returning id into v_membership_id;
  else
    update public.hrms_memberships set is_active=true where id=v_membership_id;
  end if;
  return v_membership_id;
end;
$$;
revoke all on function public.hrms_add_member(uuid,text,public.hrms_membership_role,uuid) from public;
grant execute on function public.hrms_add_member(uuid,text,public.hrms_membership_role,uuid) to authenticated;

create or replace function public.hrms_list_hospital_users(p_hospital_id uuid)
returns table(id uuid, user_id uuid, email text, role public.hrms_membership_role, department_id uuid, is_active boolean, created_at timestamptz)
language sql stable security definer
set search_path = public, pg_temp
as $$
  select m.id, m.user_id, u.email::text, m.role, m.department_id, m.is_active, m.created_at
  from public.hrms_memberships m join auth.users u on u.id = m.user_id
  where m.hospital_id = p_hospital_id
    and public.hrms_has_membership(p_hospital_id, array['hospital_admin']::public.hrms_membership_role[])
  order by u.email, m.role;
$$;
revoke all on function public.hrms_list_hospital_users(uuid) from public;
grant execute on function public.hrms_list_hospital_users(uuid) to authenticated;

alter table public.resource_requests enable row level security;
alter table public.resource_request_lines enable row level security;
alter table public.stock_transfers enable row level security;
alter table public.hrms_suppliers enable row level security;
alter table public.purchase_requisitions enable row level security;
alter table public.medical_assets enable row level security;
alter table public.maintenance_work_orders enable row level security;

create policy "hospital members read requests" on public.resource_requests for select to authenticated using (public.hrms_has_membership(hospital_id));
create policy "members submit own requests" on public.resource_requests for insert to authenticated with check (public.hrms_has_membership(hospital_id) and requested_by = auth.uid());
create policy "authorized staff review requests" on public.resource_requests for update to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','department_head','storekeeper','pharmacist']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','department_head','storekeeper','pharmacist']::public.hrms_membership_role[]));
create policy "members read request lines" on public.resource_request_lines for select to authenticated
  using (public.hrms_has_membership(hospital_id));
create policy "members create request lines" on public.resource_request_lines for insert to authenticated
  with check (exists (select 1 from public.resource_requests r where r.id=request_id and r.hospital_id=resource_request_lines.hospital_id and r.requested_by=auth.uid() and r.status='pending') and public.hrms_has_membership(hospital_id));
create policy "authorized staff update request lines" on public.resource_request_lines for update to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','department_head','storekeeper','pharmacist']::public.hrms_membership_role[]));

create policy "members read transfers" on public.stock_transfers for select to authenticated using (public.hrms_has_membership(hospital_id));
create policy "authorized members create transfers" on public.stock_transfers for insert to authenticated
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','inventory_manager','storekeeper']::public.hrms_membership_role[]) and actor_id=auth.uid());
create policy "members read suppliers" on public.hrms_suppliers for select to authenticated using (public.hrms_has_membership(hospital_id));
create policy "procurement manage suppliers" on public.hrms_suppliers for all to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','procurement_officer']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','procurement_officer']::public.hrms_membership_role[]));
create policy "members read requisitions" on public.purchase_requisitions for select to authenticated using (public.hrms_has_membership(hospital_id));
create policy "members submit requisitions" on public.purchase_requisitions for insert to authenticated
  with check (public.hrms_has_membership(hospital_id) and created_by=auth.uid());
create policy "authorized staff update requisitions" on public.purchase_requisitions for update to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','procurement_officer','finance_officer']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','procurement_officer','finance_officer']::public.hrms_membership_role[]));
create policy "members read assets" on public.medical_assets for select to authenticated using (public.hrms_has_membership(hospital_id));
create policy "biomed manage assets" on public.medical_assets for all to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','biomedical_engineer']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','biomedical_engineer']::public.hrms_membership_role[]));
create policy "members read maintenance" on public.maintenance_work_orders for select to authenticated using (public.hrms_has_membership(hospital_id));
create policy "members report maintenance" on public.maintenance_work_orders for insert to authenticated
  with check (public.hrms_has_membership(hospital_id) and reported_by=auth.uid());
create policy "biomed manage maintenance" on public.maintenance_work_orders for update to authenticated
  using (public.hrms_has_membership(hospital_id, array['hospital_admin','biomedical_engineer']::public.hrms_membership_role[]))
  with check (public.hrms_has_membership(hospital_id, array['hospital_admin','biomedical_engineer']::public.hrms_membership_role[]));

grant select, insert, update on public.resource_requests, public.resource_request_lines to authenticated;
grant select, insert on public.stock_transfers to authenticated;
grant select, insert, update, delete on public.hrms_suppliers, public.purchase_requisitions to authenticated;
grant select, insert, update, delete on public.medical_assets, public.maintenance_work_orders to authenticated;

create or replace function public.hrms_set_membership_active(p_membership_id uuid, p_is_active boolean)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_hospital_id uuid; v_user_id uuid;
begin
  select hospital_id,user_id into v_hospital_id,v_user_id
  from public.hrms_memberships where id=p_membership_id;
  if v_hospital_id is null then raise exception 'Membership not found'; end if;
  if not public.hrms_has_membership(v_hospital_id, array['hospital_admin']::public.hrms_membership_role[]) then
    raise exception 'Only a hospital administrator can change membership status';
  end if;
  if v_user_id=auth.uid() and not p_is_active then raise exception 'You cannot deactivate your own membership'; end if;
  update public.hrms_memberships set is_active=p_is_active where id=p_membership_id;
end;
$$;
revoke all on function public.hrms_set_membership_active(uuid,boolean) from public;
grant execute on function public.hrms_set_membership_active(uuid,boolean) to authenticated;
