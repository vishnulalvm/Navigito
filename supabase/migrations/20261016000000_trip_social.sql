-- Trip screen social features: likes, saves, follows and comments always
-- belong to the signed-in user, and a trip's author can moderate the
-- comments on it.

-- Rows default to the caller, so a client can't file them under anyone else
-- (the insert policies already reject a mismatched id).
alter table public.trip_likes alter column user_id set default auth.uid();
alter table public.trip_saves alter column user_id set default auth.uid();
alter table public.follows alter column follower_id set default auth.uid();
alter table public.trip_comments alter column user_id set default auth.uid();

-- Comments are trimmed and never blank.
alter table public.trip_comments drop constraint if exists trip_comments_body_check;
alter table public.trip_comments add constraint trip_comments_body_check
  check (char_length(btrim(body)) between 1 and 1000);

-- Only visible trips take comments, likes and saves (a private trip is
-- invisible to everyone but its author, so this keeps strangers out).
drop policy if exists "comment as self" on public.trip_comments;
create policy "comment as self" on public.trip_comments for insert
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.trips t where t.id = trip_id)
  );

drop policy if exists "add own likes" on public.trip_likes;
create policy "add own likes" on public.trip_likes for insert
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.trips t where t.id = trip_id)
  );

drop policy if exists "add own saves" on public.trip_saves;
create policy "add own saves" on public.trip_saves for insert
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.trips t where t.id = trip_id)
  );

-- The trip's author may remove any comment on it.
drop policy if exists "trip author deletes comments" on public.trip_comments;
create policy "trip author deletes comments" on public.trip_comments for delete
  using (
    exists (
      select 1 from public.trips t
      where t.id = trip_id and t.author_id = (select auth.uid())
    )
  );

-- Comment pages read newest first per trip.
drop index if exists public.trip_comments_trip_idx;
create index if not exists trip_comments_trip_created_idx
  on public.trip_comments (trip_id, created_at desc);
