-- Add Inkasting leaderboard metric columns
-- Run in Dashboard → SQL Editor after 20260721_leaderboard_4m_metrics.sql

alter table public.leaderboard_entries
  add column if not exists tightest_cluster_30d float8,
  add column if not exists tightest_cluster_90d float8,
  add column if not exists spread_ratio_30d     float8,
  add column if not exists spread_ratio_90d     float8,
  add column if not exists inkast_count_30d     integer,
  add column if not exists inkast_count_90d     integer;

create index if not exists idx_lb_tightest_cluster_30d
  on public.leaderboard_entries (mode, tightest_cluster_30d asc  nulls last);
create index if not exists idx_lb_tightest_cluster_90d
  on public.leaderboard_entries (mode, tightest_cluster_90d asc  nulls last);
create index if not exists idx_lb_spread_ratio_30d
  on public.leaderboard_entries (mode, spread_ratio_30d     asc  nulls last);
create index if not exists idx_lb_spread_ratio_90d
  on public.leaderboard_entries (mode, spread_ratio_90d     asc  nulls last);
create index if not exists idx_lb_inkast_count_30d
  on public.leaderboard_entries (mode, inkast_count_30d     desc nulls last);
create index if not exists idx_lb_inkast_count_90d
  on public.leaderboard_entries (mode, inkast_count_90d     desc nulls last);
