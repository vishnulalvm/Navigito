-- In-app feedback. Users can only send; reading is for the team, in the
-- dashboard (the service role bypasses row security). Deleted with the
-- account, like everything else the user made.

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('idea', 'bug', 'other')),
  message text not null check (char_length(message) between 5 and 2000),
  app_version text check (char_length(app_version) <= 40),
  platform text check (char_length(platform) <= 20),
  created_at timestamptz not null default now()
);
create index feedback_created_idx on public.feedback (created_at desc);

alter table public.feedback enable row level security;

create policy "send feedback as self" on public.feedback for insert
  to authenticated with check (user_id = (select auth.uid()));

revoke all on public.feedback from anon, authenticated;
grant insert on public.feedback to authenticated;
