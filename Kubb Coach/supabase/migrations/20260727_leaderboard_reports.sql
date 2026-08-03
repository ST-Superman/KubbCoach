-- leaderboard_reports
-- Users can submit reports against offensive display names.
-- Clients can INSERT only; nobody can SELECT via the API.
-- Moderators review reports in the Supabase dashboard (service_role bypasses RLS).

create table public.leaderboard_reports (
    id                    uuid primary key default gen_random_uuid(),
    reporter_user_id      uuid not null references auth.users(id) on delete cascade,
    reported_display_name text not null,
    reported_mode         text not null,
    reported_at           timestamptz not null default now(),

    -- one report per user per entry — prevents duplicate submissions
    unique (reporter_user_id, reported_display_name, reported_mode)
);

alter table public.leaderboard_reports enable row level security;

-- Authenticated users can insert their own reports; no client reads allowed
create policy "own insert"
    on public.leaderboard_reports
    for insert
    with check (auth.uid() = reporter_user_id);
