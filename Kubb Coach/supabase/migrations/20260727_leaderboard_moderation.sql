-- Leaderboard moderation + self-delete
-- Run in Dashboard → SQL Editor

-- 1. Own-row DELETE so users can remove their leaderboard entry from the app
create policy "own row delete"
    on public.leaderboard_entries
    for delete
    using (auth.uid() = user_id);

-- 2. Moderator-hidden flag — set to true from the Supabase dashboard to
--    suppress offensive display names without deleting the underlying stats.
--    service_role (used by the Supabase dashboard) bypasses RLS, so no extra
--    policy is needed for moderator writes.
alter table public.leaderboard_entries
    add column if not exists moderator_hidden boolean not null default false;

-- 3. Replace the open SELECT policy so hidden rows are invisible to all clients
drop policy if exists "public read" on public.leaderboard_entries;
create policy "public read"
    on public.leaderboard_entries
    for select
    using (moderator_hidden = false);
