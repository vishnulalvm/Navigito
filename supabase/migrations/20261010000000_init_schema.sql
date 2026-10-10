-- Navigito initial schema: profiles, trips, stops, likes, saves, follows,
-- comments, notifications, plus place search and storage buckets.

create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  name text not null,
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------------- trips
create table public.trips (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  description text not null default '',
  cover_url text,
  days int not null default 1 check (days between 1 and 30),
  distance_km int not null default 0,
  tags text[] not null default '{}',
  is_public boolean not null default true,
  start_date date,
  likes_count int not null default 0,
  comments_count int not null default 0,
  created_at timestamptz not null default now()
);
create index trips_author_idx on public.trips (author_id);
create index trips_public_created_idx on public.trips (is_public, created_at desc);

-- ------------------------------------------------------------------- stops
create table public.trip_stops (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  day int not null default 1,
  position int not null default 0,
  time time,
  title text not null,
  subtitle text,
  type text not null check (type in ('start', 'food', 'attraction', 'stay')),
  latitude double precision not null,
  longitude double precision not null,
  location extensions.geography (Point, 4326) generated always as (
    extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography
  ) stored,
  photo_url text,
  travel_minutes int,
  distance_km int
);
create index trip_stops_trip_idx on public.trip_stops (trip_id, day, position);
create index trip_stops_location_idx on public.trip_stops using gist (location);

-- ----------------------------------------------------- likes, saves, follows
create table public.trip_likes (
  user_id uuid not null references public.profiles (id) on delete cascade,
  trip_id uuid not null references public.trips (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, trip_id)
);

create table public.trip_saves (
  user_id uuid not null references public.profiles (id) on delete cascade,
  trip_id uuid not null references public.trips (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, trip_id)
);

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table public.trip_comments (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index trip_comments_trip_idx on public.trip_comments (trip_id, created_at);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid not null references public.profiles (id) on delete cascade,
  type text not null check (type in ('like', 'comment', 'follow', 'save')),
  trip_id uuid references public.trips (id) on delete cascade,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

-- ---------------------------------------------------------------- triggers
-- Create a profile whenever someone signs up.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, username, name, avatar_url)
  values (
    new.id,
    'user_' || substr(replace(new.id::text, '-', ''), 1, 8),
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1), 'Traveller'),
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Like counter + notification.
create function public.on_trip_like() returns trigger
language plpgsql security definer set search_path = '' as $$
declare author uuid; trip_title text;
begin
  if tg_op = 'INSERT' then
    update public.trips set likes_count = likes_count + 1 where id = new.trip_id
      returning author_id, title into author, trip_title;
    if author is not null and author <> new.user_id then
      insert into public.notifications (user_id, actor_id, type, trip_id, message)
      values (author, new.user_id, 'like', new.trip_id, 'liked your trip ' || trip_title);
    end if;
    return new;
  else
    update public.trips set likes_count = greatest(likes_count - 1, 0) where id = old.trip_id;
    return old;
  end if;
end $$;

create trigger trip_likes_counter
after insert or delete on public.trip_likes
for each row execute function public.on_trip_like();

-- Save notification.
create function public.on_trip_save() returns trigger
language plpgsql security definer set search_path = '' as $$
declare author uuid; trip_title text;
begin
  select author_id, title into author, trip_title from public.trips where id = new.trip_id;
  if author is not null and author <> new.user_id then
    insert into public.notifications (user_id, actor_id, type, trip_id, message)
    values (author, new.user_id, 'save', new.trip_id, 'saved your trip ' || trip_title);
  end if;
  return new;
end $$;

create trigger trip_saves_notify
after insert on public.trip_saves
for each row execute function public.on_trip_save();

-- Comment counter + notification.
create function public.on_trip_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare author uuid; trip_title text;
begin
  if tg_op = 'INSERT' then
    update public.trips set comments_count = comments_count + 1 where id = new.trip_id
      returning author_id, title into author, trip_title;
    if author is not null and author <> new.user_id then
      insert into public.notifications (user_id, actor_id, type, trip_id, message)
      values (author, new.user_id, 'comment', new.trip_id,
              'commented on ' || trip_title || ': "' || left(new.body, 60) || '"');
    end if;
    return new;
  else
    update public.trips set comments_count = greatest(comments_count - 1, 0) where id = old.trip_id;
    return old;
  end if;
end $$;

create trigger trip_comments_counter
after insert or delete on public.trip_comments
for each row execute function public.on_trip_comment();

-- Follow notification.
create function public.on_follow() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, actor_id, type, message)
  values (new.following_id, new.follower_id, 'follow', 'started following you');
  return new;
end $$;

create trigger follows_notify
after insert on public.follows
for each row execute function public.on_follow();

-- ------------------------------------------------------------ place search
-- Public trips with at least one stop within radius_m of a point.
create function public.trips_near(lat double precision, lng double precision, radius_m int default 30000)
returns setof public.trips
language sql stable security invoker set search_path = public, extensions as $$
  select t.*
  from public.trips t
  where t.is_public
    and exists (
      select 1 from public.trip_stops s
      where s.trip_id = t.id
        and st_dwithin(s.location, st_setsrid(st_makepoint(lng, lat), 4326)::geography, radius_m)
    )
  order by t.likes_count desc;
$$;

-- ------------------------------------------------------------ row security
alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.trip_stops enable row level security;
alter table public.trip_likes enable row level security;
alter table public.trip_saves enable row level security;
alter table public.follows enable row level security;
alter table public.trip_comments enable row level security;
alter table public.notifications enable row level security;

-- profiles: readable by everyone, editable by owner.
create policy "profiles are public" on public.profiles for select using (true);
create policy "own profile update" on public.profiles for update
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- trips: public ones are visible to all, private only to the author.
create policy "read public or own trips" on public.trips for select
  using (is_public or author_id = (select auth.uid()));
create policy "create own trips" on public.trips for insert
  with check (author_id = (select auth.uid()));
create policy "update own trips" on public.trips for update
  using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
create policy "delete own trips" on public.trips for delete
  using (author_id = (select auth.uid()));

-- stops follow the visibility and ownership of their trip.
create policy "read stops of visible trips" on public.trip_stops for select
  using (exists (select 1 from public.trips t where t.id = trip_id));
create policy "manage stops of own trips" on public.trip_stops for all
  using (exists (select 1 from public.trips t where t.id = trip_id and t.author_id = (select auth.uid())))
  with check (exists (select 1 from public.trips t where t.id = trip_id and t.author_id = (select auth.uid())));

-- likes / saves: users manage and read their own.
create policy "read own likes" on public.trip_likes for select using (user_id = (select auth.uid()));
create policy "add own likes" on public.trip_likes for insert with check (user_id = (select auth.uid()));
create policy "remove own likes" on public.trip_likes for delete using (user_id = (select auth.uid()));

create policy "read own saves" on public.trip_saves for select using (user_id = (select auth.uid()));
create policy "add own saves" on public.trip_saves for insert with check (user_id = (select auth.uid()));
create policy "remove own saves" on public.trip_saves for delete using (user_id = (select auth.uid()));

-- follows: public graph, users manage their own follows.
create policy "follows are public" on public.follows for select using (true);
create policy "follow as self" on public.follows for insert with check (follower_id = (select auth.uid()));
create policy "unfollow as self" on public.follows for delete using (follower_id = (select auth.uid()));

-- comments: visible with the trip, written and deleted by their author.
create policy "read comments of visible trips" on public.trip_comments for select
  using (exists (select 1 from public.trips t where t.id = trip_id));
create policy "comment as self" on public.trip_comments for insert
  with check (user_id = (select auth.uid()));
create policy "delete own comments" on public.trip_comments for delete
  using (user_id = (select auth.uid()));

-- notifications: only the recipient sees and updates them (inserts come from triggers).
create policy "read own notifications" on public.notifications for select
  using (user_id = (select auth.uid()));
create policy "update own notifications" on public.notifications for update
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ----------------------------------------------------------------- storage
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true), ('trip-photos', 'trip-photos', true)
on conflict (id) do nothing;

-- Anyone can view; users upload/modify only inside a folder named after their user id.
create policy "public read media" on storage.objects for select
  using (bucket_id in ('avatars', 'trip-photos'));
create policy "upload to own folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars', 'trip-photos') and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "update own files" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'trip-photos') and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "delete own files" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'trip-photos') and (storage.foldername(name))[1] = (select auth.uid())::text);
