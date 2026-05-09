-- Add these tables to your Supabase schema for predictive analytics
-- Run this in Supabase SQL Editor

-- Table for financial health scores
create table if not exists public.financial_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  month text not null,
  score numeric,
  stability_score numeric,
  savings_rate numeric,
  budget_adherence numeric,
  income_variance numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists financial_scores_user_month_idx on public.financial_scores(user_id, month desc);

-- Table for XGBoost predictions
create table if not exists public.predictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  month text not null,
  predicted_expenses numeric,
  confidence_low numeric,
  confidence_high numeric,
  risk_level text,
  top_categories jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists predictions_user_month_idx on public.predictions(user_id, month desc);

-- Table for Prophet insights
create table if not exists public.prophet_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  analysis_month text not null,
  forecast_next_3_months jsonb,
  seasonal_pattern jsonb,
  trend_direction text,
  trend_percent numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists prophet_insights_user_month_idx on public.prophet_insights(user_id, analysis_month desc);

-- Table for detected anomalies
create table if not exists public.anomalies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  depense_id uuid references public.depenses(id),
  anomaly_type text not null,
  severity text not null,
  description text,
  detected_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists anomalies_user_detected_idx on public.anomalies(user_id, detected_at desc);

-- Enable RLS
alter table public.financial_scores enable row level security;
alter table public.predictions enable row level security;
alter table public.prophet_insights enable row level security;
alter table public.anomalies enable row level security;

-- RLS Policies
do $$
declare
  t text;
begin
  foreach t in array array['financial_scores', 'predictions', 'prophet_insights', 'anomalies']
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

-- Triggers for updated_at
drop trigger if exists financial_scores_set_updated_at on public.financial_scores;
create trigger financial_scores_set_updated_at
before update on public.financial_scores
for each row execute function public.set_updated_at();

drop trigger if exists predictions_set_updated_at on public.predictions;
create trigger predictions_set_updated_at
before update on public.predictions
for each row execute function public.set_updated_at();

drop trigger if exists prophet_insights_set_updated_at on public.prophet_insights;
create trigger prophet_insights_set_updated_at
before update on public.prophet_insights
for each row execute function public.set_updated_at();

drop trigger if exists anomalies_set_updated_at on public.anomalies;
create trigger anomalies_set_updated_at
before update on public.anomalies
for each row execute function public.set_updated_at();