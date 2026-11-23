-- LEGALYNX initial schema. Every tenant-owned record belongs to its creator.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_number text not null default ('CL-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
  full_name text not null,
  email text,
  phone text,
  company text,
  purpose text,
  industry text,
  practice_area text,
  client_type text,
  assigned_lawyer text,
  related_matter text,
  address text,
  budget numeric(14,2) not null default 0 check (budget >= 0),
  payment_terms text,
  total_invoice numeric(14,2) not null default 0 check (total_invoice >= 0),
  paid_amount numeric(14,2) not null default 0 check (paid_amount >= 0),
  pending_amount numeric(14,2) not null default 0 check (pending_amount >= 0),
  status text not null default 'Pending' check (status in ('Active','Pending','Archived')),
  favorite boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, client_number),
  unique(owner_id, id)
);
create index if not exists clients_owner_created_idx on public.clients(owner_id, created_at desc);
create index if not exists clients_owner_name_idx on public.clients(owner_id, full_name);
drop trigger if exists clients_updated_at on public.clients;
create trigger clients_updated_at before update on public.clients for each row execute function public.set_updated_at();

create table if not exists public.matters (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid, title text not null, matter_number text,
  practice_area text, status text not null default 'Active', next_deadline date, created_at timestamptz not null default now(),
  unique(owner_id, id), foreign key (owner_id, client_id) references public.clients(owner_id, id) on delete cascade
);
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null, due_at timestamptz, status text not null default 'Pending', priority text, client_id uuid,
  foreign key (owner_id, client_id) references public.clients(owner_id, id) on delete cascade
);
create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null, starts_at timestamptz not null, event_type text not null default 'Meeting', status text not null default 'Scheduled', client_id uuid,
  foreign key (owner_id, client_id) references public.clients(owner_id, id) on delete cascade
);
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null, invoice_number text not null, invoice_date date not null default current_date,
  due_date date, next_payment_date date, total_amount numeric(14,2) not null check (total_amount >= 0), payment_conditions text, payment_method text, created_at timestamptz not null default now(),
  unique(owner_id, invoice_number), unique(owner_id, id), foreign key (owner_id, client_id) references public.clients(owner_id, id) on delete cascade
);
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  invoice_id uuid not null, amount numeric(14,2) not null check (amount > 0), paid_at timestamptz not null default now(), method text, reference text,
  foreign key (owner_id, invoice_id) references public.invoices(owner_id, id) on delete cascade
);
create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid, matter_id uuid,
  description text, hours numeric(8,2) not null default 0 check (hours >= 0), billable_amount numeric(14,2) not null default 0 check (billable_amount >= 0), work_date date not null default current_date,
  foreign key (owner_id, client_id) references public.clients(owner_id, id) on delete cascade,
  foreign key (owner_id, matter_id) references public.matters(owner_id, id) on delete cascade
);
create table if not exists public.public_overview (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label text not null, value text, approved boolean not null default false, updated_at timestamptz not null default now()
);
create table if not exists public.client_documents (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null, storage_path text not null unique,
  file_name text not null, mime_type text, file_size bigint, created_at timestamptz not null default now(),
  foreign key (owner_id, client_id) references public.clients(owner_id, id) on delete cascade
);
create table if not exists public.ai_usage (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists ai_usage_owner_created_idx on public.ai_usage(owner_id, created_at desc);

create or replace function public.enforce_invoice_payment_total()
returns trigger language plpgsql as $$
declare invoice_total numeric(14,2); already_paid numeric(14,2);
begin
  select total_amount into invoice_total from public.invoices where id = new.invoice_id and owner_id = new.owner_id for update;
  if not found then raise exception 'Invoice not found in this workspace.'; end if;
  select coalesce(sum(amount),0) into already_paid from public.payments where invoice_id = new.invoice_id and owner_id = new.owner_id and id <> new.id;
  if already_paid + new.amount > invoice_total then raise exception 'Payment exceeds the remaining invoice balance.'; end if;
  return new;
end; $$;
drop trigger if exists payments_enforce_invoice_total on public.payments;
create trigger payments_enforce_invoice_total before insert or update on public.payments for each row execute function public.enforce_invoice_payment_total();

alter table public.clients enable row level security;
alter table public.matters enable row level security;
alter table public.tasks enable row level security;
alter table public.calendar_events enable row level security;
alter table public.invoices enable row level security;
alter table public.payments enable row level security;
alter table public.time_entries enable row level security;
alter table public.public_overview enable row level security;
alter table public.client_documents enable row level security;
alter table public.ai_usage enable row level security;

do $$ declare t text; begin
  foreach t in array array['clients','matters','tasks','calendar_events','invoices','payments','time_entries','public_overview','client_documents','ai_usage'] loop
    execute format('drop policy if exists "Owners manage own %s" on public.%I', t, t);
    execute format('create policy "Owners manage own %s" on public.%I for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()))', t, t);
  end loop;
end $$;

drop policy if exists "Public can view approved overview" on public.public_overview;
create policy "Public can view approved overview" on public.public_overview for select to anon, authenticated using (approved is true);

insert into storage.buckets (id, name, public) values ('client-documents','client-documents',false) on conflict (id) do nothing;
drop policy if exists "Owners manage own client documents" on storage.objects;
create policy "Owners manage own client documents" on storage.objects for all to authenticated
  using (bucket_id = 'client-documents' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'client-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
