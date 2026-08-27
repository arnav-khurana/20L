-- Run this in the Supabase SQL editor (Project → SQL Editor → New query)
-- This WIPES existing tables and rebuilds everything from scratch, including
-- real customer accounts (via Supabase Auth) and an admin role.
--
-- IMPORTANT — do this first, in the Supabase dashboard, before running this file:
--   Authentication → Providers → make sure "Email" is enabled.
--   Authentication → Settings → turn OFF "Confirm email" (so signup logs
--   people straight in — hostel-scale MVP, no email server needed).
-- See SETUP.md for the full walkthrough, including how to make yourself an admin.

drop table if exists orders cascade;
drop table if exists admins cascade;
drop table if exists profiles cascade;

-- ---- Customer profiles (one per signed-up user) ----
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  hostel text not null,
  room_number text not null,
  wing text not null check (wing in ('A','B')),
  first_order_claimed boolean not null default false,
  created_at timestamptz default now()
);

-- ---- Admin allow-list: one row per admin user ----
-- Empty by default. Add yourself after you sign up on the site (see SETUP.md).
create table admins (
  id uuid primary key references auth.users(id) on delete cascade
);

-- ---- Orders ----
-- order_group_id ties together every line item placed in a single checkout
-- (e.g. 2 new bottles + a recurring refill added to one cart) so the admin
-- panel can show them as one order instead of separate unrelated rows.
create table orders (
  id uuid primary key default gen_random_uuid(),
  order_group_id uuid not null,
  created_at timestamptz default now(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  hostel text not null,
  room_number text not null,
  wing text not null check (wing in ('A','B')),
  phone text not null,
  item_type text not null check (item_type in ('new', 'refill', 'combo')),
  quantity int not null check (quantity > 0),
  order_mode text not null default 'once' check (order_mode in ('once', 'recurring')),
  delivery_date date,
  recurring_day text check (recurring_day in ('mon','tue','wed','thu','fri','sat','sun')),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'delivered', 'cancelled')),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'claimed', 'confirmed')),
  total_amount numeric not null,
  notes text,
  constraint order_mode_matches_fields check (
    (order_mode = 'once' and delivery_date is not null and recurring_day is null)
    or
    (order_mode = 'recurring' and recurring_day is not null and delivery_date is null)
  )
);

create index orders_customer_idx on orders (customer_id);
create index orders_group_idx on orders (order_group_id);
create index orders_phone_idx on orders (phone);

-- ---- Row Level Security ----
-- Ordering now requires a logged-in account: customers can only insert/read
-- their own rows, and admins (listed in the `admins` table) can read and
-- update everything. There is no public/anon access to any of this data.
alter table profiles enable row level security;
alter table admins enable row level security;
alter table orders enable row level security;

create policy "select own profile" on profiles for select to authenticated using (auth.uid() = id);
create policy "insert own profile" on profiles for insert to authenticated with check (auth.uid() = id);
create policy "update own profile" on profiles for update to authenticated using (auth.uid() = id);

create policy "users can check own admin row" on admins for select to authenticated using (auth.uid() = id);

create policy "customers can insert own orders" on orders for insert to authenticated with check (customer_id = auth.uid());
create policy "customers can select own orders" on orders for select to authenticated using (customer_id = auth.uid());
create policy "admins can select all orders" on orders for select to authenticated using (
  exists (select 1 from admins where admins.id = auth.uid())
);
create policy "admins can update orders" on orders for update to authenticated using (
  exists (select 1 from admins where admins.id = auth.uid())
);
