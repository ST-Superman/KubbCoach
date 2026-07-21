-- Add 4m leaderboard metric columns
-- Run in Dashboard → SQL Editor after 20260721_leaderboard_entries.sql

alter table public.leaderboard_entries
  add column if not exists best_score_30d    float8,
  add column if not exists best_score_90d    float8,
  add column if not exists under_par_pct_30d float8,
  add column if not exists under_par_pct_90d float8,
  add column if not exists session_count_30d integer,
  add column if not exists session_count_90d integer;

create index if not exists idx_lb_best_score_30d
  on public.leaderboard_entries (mode, best_score_30d    asc  nulls last);
create index if not exists idx_lb_best_score_90d
  on public.leaderboard_entries (mode, best_score_90d    asc  nulls last);
create index if not exists idx_lb_under_par_pct_30d
  on public.leaderboard_entries (mode, under_par_pct_30d desc nulls last);
create index if not exists idx_lb_under_par_pct_90d
  on public.leaderboard_entries (mode, under_par_pct_90d desc nulls last);
create index if not exists idx_lb_session_count_30d
  on public.leaderboard_entries (mode, session_count_30d desc nulls last);
create index if not exists idx_lb_session_count_90d
  on public.leaderboard_entries (mode, session_count_90d desc nulls last);
