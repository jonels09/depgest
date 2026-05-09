-- Run this in Supabase SQL Editor for a fresh DepGest cloud schema.
-- Then enable Auth > Providers > Anonymous sign-ins in the Supabase dashboard.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.unites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  categorie_id uuid not null references public.categories(id),
  nom text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.revenus (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source text not null,
  montant numeric not null,
  date_revenu date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.depenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  unite_id uuid not null references public.unites(id),
  quantite numeric not null,
  prix_unitaire numeric not null,
  total numeric not null,
  date_depense date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  categorie_id uuid references public.categories(id),
  mois text not null,
  montant numeric not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.saving_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom text not null,
  target_amount numeric not null,
  current_amount numeric not null default 0,
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists categories_user_updated_idx on public.categories(user_id, updated_at);
create index if not exists unites_user_updated_idx on public.unites(user_id, updated_at);
create index if not exists articles_user_updated_idx on public.articles(user_id, updated_at);
create index if not exists revenus_user_updated_idx on public.revenus(user_id, updated_at);
create index if not exists depenses_user_updated_idx on public.depenses(user_id, updated_at);
create index if not exists budgets_user_updated_idx on public.budgets(user_id, updated_at);
create index if not exists saving_goals_user_updated_idx on public.saving_goals(user_id, updated_at);

create unique index if not exists categories_user_nom_active_idx
  on public.categories(user_id, lower(nom))
  where deleted_at is null;

create unique index if not exists unites_user_nom_active_idx
  on public.unites(user_id, lower(nom))
  where deleted_at is null;

create unique index if not exists articles_user_categorie_nom_active_idx
  on public.articles(user_id, categorie_id, lower(nom))
  where deleted_at is null;

create unique index if not exists budgets_user_mois_categorie_active_idx
  on public.budgets(user_id, mois, coalesce(categorie_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where deleted_at is null;

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists unites_set_updated_at on public.unites;
create trigger unites_set_updated_at
before update on public.unites
for each row execute function public.set_updated_at();

drop trigger if exists articles_set_updated_at on public.articles;
create trigger articles_set_updated_at
before update on public.articles
for each row execute function public.set_updated_at();

drop trigger if exists revenus_set_updated_at on public.revenus;
create trigger revenus_set_updated_at
before update on public.revenus
for each row execute function public.set_updated_at();

drop trigger if exists depenses_set_updated_at on public.depenses;
create trigger depenses_set_updated_at
before update on public.depenses
for each row execute function public.set_updated_at();

drop trigger if exists budgets_set_updated_at on public.budgets;
create trigger budgets_set_updated_at
before update on public.budgets
for each row execute function public.set_updated_at();

drop trigger if exists saving_goals_set_updated_at on public.saving_goals;
create trigger saving_goals_set_updated_at
before update on public.saving_goals
for each row execute function public.set_updated_at();

alter table public.categories enable row level security;
alter table public.unites enable row level security;
alter table public.articles enable row level security;
alter table public.revenus enable row level security;
alter table public.depenses enable row level security;
alter table public.budgets enable row level security;
alter table public.saving_goals enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['categories', 'unites', 'articles', 'revenus', 'depenses', 'budgets', 'saving_goals']
  loop
    execute format('drop policy if exists "%s own rows" on public.%I', t, t);
    execute format(
      'create policy "%s own rows" on public.%I for all using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      t,
      t
    );
  end loop;
end;
$$;
