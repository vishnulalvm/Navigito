-- Trip data API: what the app reads and writes, each in one round trip.
-- Everything runs as the caller (security invoker), so the row-level
-- policies from the initial schema still decide what each user sees.

-- Google place id of a stop: keeps a trip from listing a place twice and lets
-- the app fetch its photo later.
alter table public.trip_stops add column if not exists place_id text;

-- Users who signed up before the profile trigger existed have no profile,
-- and every trip needs one as its author.
insert into public.profiles (id, username, name, avatar_url)
select
  u.id,
  'user_' || substr(replace(u.id::text, '-', ''), 1, 8),
  coalesce(u.raw_user_meta_data ->> 'name', split_part(u.email, '@', 1), 'Traveller'),
  u.raw_user_meta_data ->> 'avatar_url'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- Saved and liked lists read newest first per user.
create index if not exists trip_saves_user_idx on public.trip_saves (user_id, created_at desc);
create index if not exists trip_likes_user_idx on public.trip_likes (user_id, created_at desc);

-- -------------------------------------------------------------- trip cards
-- One row per trip with everything a list card shows. The stop summary and
-- the caller's like/save flags are index lookups per row, so pages stay
-- cheap without counters to keep in sync.
create or replace view public.trip_cards with (security_invoker = true) as
select
  t.id,
  t.author_id,
  t.title,
  t.cover_url,
  t.days,
  t.distance_km,
  t.tags,
  t.is_public,
  t.likes_count,
  t.created_at,
  p.name as author_name,
  p.avatar_url as author_avatar_url,
  s.stops_count,
  s.places,
  exists (
    select 1 from public.trip_likes l
    where l.trip_id = t.id and l.user_id = (select auth.uid())
  ) as is_liked,
  exists (
    select 1 from public.trip_saves v
    where v.trip_id = t.id and v.user_id = (select auth.uid())
  ) as is_saved
from public.trips t
join public.profiles p on p.id = t.author_id
cross join lateral (
  select
    count(*)::int as stops_count,
    -- Lower-cased names and addresses, for matching a searched place.
    coalesce(
      array_agg(lower(st.title || coalesce(' ' || st.subtitle, '')) order by st.day, st.position),
      '{}'
    ) as places
  from public.trip_stops st
  where st.trip_id = t.id
) s;

grant select on public.trip_cards to anon, authenticated;

-- -------------------------------------------------------------------- feed
-- Public trips for the home sheet. With a point, trips are ranked by their
-- stop nearest to it (a GiST nearest-neighbour scan); with within_m too, only
-- trips passing that close are kept. Without a point, the most liked first.
create or replace function public.feed_trips(
  lat double precision default null,
  lng double precision default null,
  within_m int default null,
  max_rows int default 30
)
returns setof public.trip_cards
language plpgsql stable security invoker
set search_path = public, extensions
as $$
begin
  if lat is null or lng is null then
    return query
      select c.* from public.trip_cards c
      where c.is_public
      order by c.likes_count desc, c.created_at desc
      limit max_rows;
    return;
  end if;

  return query
    with nearest_stops as (
      select s.trip_id,
             s.location <-> st_setsrid(st_makepoint(lng, lat), 4326)::geography as d
      from public.trip_stops s
      order by s.location <-> st_setsrid(st_makepoint(lng, lat), 4326)::geography
      limit greatest(max_rows * 20, 200)
    ),
    near as (
      select n.trip_id, min(n.d) as d from nearest_stops n group by n.trip_id
    )
    select c.* from public.trip_cards c
    left join near on near.trip_id = c.id
    where c.is_public
      and (within_m is null or near.d <= within_m)
    order by near.d nulls last, c.likes_count desc, c.created_at desc
    limit max_rows;
end $$;

-- ---------------------------------------------------------------- my trips
-- The caller's own trips, or the ones they saved or liked, newest first.
create or replace function public.my_trips(tab text)
returns setof public.trip_cards
language plpgsql stable security invoker
set search_path = public
as $$
begin
  case tab
    when 'mine' then
      return query
        select c.* from public.trip_cards c
        where c.author_id = (select auth.uid())
        order by c.created_at desc;
    when 'saved' then
      return query
        select c.* from public.trip_saves v
        join public.trip_cards c on c.id = v.trip_id
        where v.user_id = (select auth.uid())
        order by v.created_at desc;
    when 'liked' then
      return query
        select c.* from public.trip_likes l
        join public.trip_cards c on c.id = l.trip_id
        where l.user_id = (select auth.uid())
        order by l.created_at desc;
    else
      raise exception 'unknown tab %', tab using errcode = '22023';
  end case;
end $$;

-- ------------------------------------------------------------- trip detail
-- A trip with its author, stops in order and the caller's like/save/follow
-- state, as one JSON document. Null when the trip doesn't exist or isn't
-- visible to the caller.
create or replace function public.trip_detail(trip_id uuid)
returns json
language sql stable security invoker
set search_path = public
as $$
  select json_build_object(
    'id', t.id,
    'title', t.title,
    'description', t.description,
    'cover_url', t.cover_url,
    'tags', t.tags,
    'days', t.days,
    'distance_km', t.distance_km,
    'likes_count', t.likes_count,
    'comments_count', t.comments_count,
    'is_public', t.is_public,
    'start_date', coalesce(t.start_date, t.created_at::date),
    'author', json_build_object('id', p.id, 'name', p.name, 'avatar_url', p.avatar_url),
    'is_liked', exists (
      select 1 from public.trip_likes l
      where l.trip_id = t.id and l.user_id = (select auth.uid())
    ),
    'is_saved', exists (
      select 1 from public.trip_saves v
      where v.trip_id = t.id and v.user_id = (select auth.uid())
    ),
    'is_following', exists (
      select 1 from public.follows f
      where f.following_id = t.author_id and f.follower_id = (select auth.uid())
    ),
    'stops', coalesce((
      select json_agg(json_build_object(
        'id', s.id,
        'day', s.day,
        'time', to_char(s.time, 'HH24:MI'),
        'title', s.title,
        'subtitle', s.subtitle,
        'type', s.type,
        'latitude', s.latitude,
        'longitude', s.longitude,
        'photo_url', s.photo_url,
        'place_id', s.place_id,
        'travel_minutes', s.travel_minutes,
        'distance_km', s.distance_km
      ) order by s.day, s.position)
      from public.trip_stops s
      where s.trip_id = t.id
    ), '[]'::json)
  )
  from public.trips t
  join public.profiles p on p.id = t.author_id
  where t.id = trip_detail.trip_id;
$$;

-- ------------------------------------------------------------- create trip
-- Inserts a trip and all its stops atomically; returns the new trip's id.
--   trip:  {title, description?, cover_url?, days, distance_km?, tags?, is_public?}
--   stops: [{day, time?, title, subtitle?, type, latitude, longitude,
--            place_id?, photo_url?}, ...] in visiting order
create or replace function public.create_trip(trip jsonb, stops jsonb)
returns uuid
language plpgsql volatile security invoker
set search_path = ''
as $$
declare
  new_id uuid;
  author uuid := (select auth.uid());
begin
  if author is null then
    raise exception 'sign in to create trips' using errcode = '42501';
  end if;
  if jsonb_typeof(stops) <> 'array' or jsonb_array_length(stops) not between 1 and 100 then
    raise exception 'a trip needs 1 to 100 stops' using errcode = '22023';
  end if;

  insert into public.trips (author_id, title, description, cover_url, days, distance_km, tags, is_public)
  values (
    author,
    trim(trip ->> 'title'),
    coalesce(trip ->> 'description', ''),
    nullif(trip ->> 'cover_url', ''),
    coalesce((trip ->> 'days')::int, 1),
    coalesce((trip ->> 'distance_km')::int, 0),
    coalesce(array(select jsonb_array_elements_text(trip -> 'tags')), '{}'),
    coalesce((trip ->> 'is_public')::boolean, true)
  )
  returning id into new_id;

  insert into public.trip_stops
    (trip_id, day, position, time, title, subtitle, type, latitude, longitude, place_id, photo_url)
  select
    new_id,
    coalesce((s ->> 'day')::int, 1),
    (i - 1)::int,
    (s ->> 'time')::time,
    trim(s ->> 'title'),
    nullif(s ->> 'subtitle', ''),
    coalesce(s ->> 'type', 'attraction'),
    (s ->> 'latitude')::double precision,
    (s ->> 'longitude')::double precision,
    nullif(s ->> 'place_id', ''),
    nullif(s ->> 'photo_url', '')
  from jsonb_array_elements(stops) with ordinality as x(s, i);

  return new_id;
end $$;

-- Only signed-in users write; anyone may read what the policies allow.
revoke execute on function public.create_trip(jsonb, jsonb) from public, anon;
grant execute on function public.create_trip(jsonb, jsonb) to authenticated;
grant execute on function public.feed_trips(double precision, double precision, int, int) to anon, authenticated;
grant execute on function public.trip_detail(uuid) to anon, authenticated;
grant execute on function public.my_trips(text) to authenticated;
