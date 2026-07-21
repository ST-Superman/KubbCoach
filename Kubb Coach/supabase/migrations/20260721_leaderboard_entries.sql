-- leaderboard_entries
-- One row per user per mode. Upserted on leaderboard view.
-- Auth: anonymous sign-in (Supabase generates a stable UUID per device).
--
-- Prerequisites:
--   Enable Anonymous sign-ins in Dashboard → Authentication → Providers.

create table public.leaderboard_entries (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    display_name    text not null check (char_length(display_name) between 1 and 30),
    mode            text not null check (mode in ('8m', '4m', 'Ink')),

    -- Pre-aggregated stats for both recency windows (null = no data yet)
    accuracy_30d    double precision,
    accuracy_90d    double precision,
    streak_30d      integer,
    streak_90d      integer,
    throws_30d      integer,
    throws_90d      integer,
    avg_score_30d   double precision,
    avg_score_90d   double precision,
    avg_cluster_30d double precision,
    avg_cluster_90d double precision,

    updated_at      timestamptz not null default now(),

    -- Upsert target: one row per user per mode
    unique (user_id, mode)
);

-- ─── Indexes ───────────────────────────────────────────────────────────────────
create index idx_lb_accuracy_30d    on public.leaderboard_entries (mode, accuracy_30d    desc nulls last);
create index idx_lb_accuracy_90d    on public.leaderboard_entries (mode, accuracy_90d    desc nulls last);
create index idx_lb_streak_30d      on public.leaderboard_entries (mode, streak_30d      desc nulls last);
create index idx_lb_streak_90d      on public.leaderboard_entries (mode, streak_90d      desc nulls last);
create index idx_lb_throws_30d      on public.leaderboard_entries (mode, throws_30d      desc nulls last);
create index idx_lb_throws_90d      on public.leaderboard_entries (mode, throws_90d      desc nulls last);
create index idx_lb_avg_score_30d   on public.leaderboard_entries (mode, avg_score_30d   asc  nulls last);
create index idx_lb_avg_score_90d   on public.leaderboard_entries (mode, avg_score_90d   asc  nulls last);
create index idx_lb_cluster_30d     on public.leaderboard_entries (mode, avg_cluster_30d asc  nulls last);
create index idx_lb_cluster_90d     on public.leaderboard_entries (mode, avg_cluster_90d asc  nulls last);

-- ─── Row Level Security ────────────────────────────────────────────────────────
alter table public.leaderboard_entries enable row level security;

create policy "public read"
    on public.leaderboard_entries
    for select
    using (true);

create policy "own row write"
    on public.leaderboard_entries
    for insert
    with check (auth.uid() = user_id);

create policy "own row update"
    on public.leaderboard_entries
    for update
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- ─── Auto-update updated_at ───────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger trg_lb_updated_at
    before update on public.leaderboard_entries
    for each row execute function public.set_updated_at();
