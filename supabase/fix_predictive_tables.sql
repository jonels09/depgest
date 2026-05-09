-- Drop existing tables to recreate with correct columns
DROP TABLE IF EXISTS public.anomalies;
DROP TABLE IF EXISTS public.prophet_insights;
DROP TABLE IF EXISTS public.predictions;
DROP TABLE IF EXISTS public.financial_scores;

-- Table for financial health scores (matching backend code)
create table if not exists public.financial_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  month text not null,
  discipline_score numeric,
  stability_score numeric,
  savings_score numeric,
  risk_score numeric,
  overall_score numeric,
  insights jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists financial_scores_user_month_idx 
  on public.financial_scores(user_id, month);

-- Table for XGBoost predictions
create table if not exists public.predictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  month text not null,
  predicted_spending numeric,
  predicted_balance numeric,
  deficit_risk numeric,
  recommended_budget jsonb,
  model_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists predictions_user_month_idx 
  on public.predictions(user_id, month);

-- Table for Prophet insights
create table if not exists public.prophet_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  analysis_month text not null,
  forecast_next_3_months jsonb,
  seasonal_pattern jsonb,
  trend_direction text,
  trend_percent numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists prophet_insights_user_month_idx 
  on public.prophet_insights(user_id, analysis_month);

-- Table for detected anomalies
create table if not exists public.anomalies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  depense_id uuid,
  anomaly_type text not null,
  severity text not null,
  description text,
  metadata jsonb,
  detected_at timestamptz not null default now(),
  is_confirmed boolean default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists anomalies_user_detected_idx 
  on public.anomalies(user_id, detected_at desc);

-- Enable RLS
alter table public.financial_scores enable row level security;
alter table public.predictions enable row level security;
alter table public.prophet_insights enable row level security;
alter table public.anomalies enable row level security;

-- RLS Policies
drop policy if exists "financial_scores own rows" on public.financial_scores;
create policy "financial_scores own rows" on public.financial_scores 
  for all using (true);

drop policy if exists "predictions own rows" on public.predictions;
create policy "predictions own rows" on public.predictions 
  for all using (true);

drop policy if exists "prophet_insights own rows" on public.prophet_insights;
create policy "prophet_insights own rows" on public.prophet_insights 
  for all using (true);

drop policy if exists "anomalies own rows" on public.anomalies;
create policy "anomalies own rows" on public.anomalies 
  for all using (true);