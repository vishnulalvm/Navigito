-- Stop photos: up to 3 the author uploaded (stored in the trip-photos bucket,
-- kept forever). Google photos are never stored: Google's terms forbid
-- caching them, so the app loads them live from the stop's place_id.

alter table public.trip_stops
  add column if not exists photo_urls text[] not null default '{}'
  check (cardinality(photo_urls) <= 3);

update public.trip_stops
set photo_urls = array[photo_url]
where photo_url is not null and photo_urls = '{}';

-- Functions reading the old column are replaced below before it goes.
drop function if exists public.trip_detail(uuid);
drop function if exists public.create_trip(jsonb, jsonb);
alter table public.trip_stops drop column if exists photo_url;

-- ------------------------------------------------------------- trip cards
-- Adds cover_place_id: the first stop with a Google place, for a live cover
-- when the trip has no uploaded one. New columns go last, as views require.
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
  ) as is_saved,
  s.cover_place_id
from public.trips t
join public.profiles p on p.id = t.author_id
cross join lateral (
  select
    count(*)::int as stops_count,
    coalesce(
      array_agg(lower(st.title || coalesce(' ' || st.subtitle, '')) order by st.day, st.position),
      '{}'
    ) as places,
    (array_agg(st.place_id order by st.day, st.position)
       filter (where st.place_id is not null))[1] as cover_place_id
  from public.trip_stops st
  where st.trip_id = t.id
) s;

-- ------------------------------------------------------------- trip detail
create function public.trip_detail(trip_id uuid)
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
        'photo_urls', s.photo_urls,
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
--   stops: [{..., photo_urls?: [url, ...]}, ...]
-- The cover is the first uploaded photo, unless one is given.
create function public.create_trip(trip jsonb, stops jsonb)
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
    coalesce(
      nullif(trip ->> 'cover_url', ''),
      (select x.s -> 'photo_urls' ->> 0
       from jsonb_array_elements(stops) with ordinality as x(s, i)
       where jsonb_array_length(coalesce(x.s -> 'photo_urls', '[]')) > 0
       order by x.i limit 1)
    ),
    coalesce((trip ->> 'days')::int, 1),
    coalesce((trip ->> 'distance_km')::int, 0),
    coalesce(array(select jsonb_array_elements_text(trip -> 'tags')), '{}'),
    coalesce((trip ->> 'is_public')::boolean, true)
  )
  returning id into new_id;

  insert into public.trip_stops
    (trip_id, day, position, time, title, subtitle, type, latitude, longitude, place_id, photo_urls)
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
    coalesce(array(select jsonb_array_elements_text(s -> 'photo_urls')), '{}')
  from jsonb_array_elements(stops) with ordinality as x(s, i);

  return new_id;
end $$;

revoke execute on function public.create_trip(jsonb, jsonb) from public, anon;
grant execute on function public.create_trip(jsonb, jsonb) to authenticated;
grant execute on function public.trip_detail(uuid) to anon, authenticated;
