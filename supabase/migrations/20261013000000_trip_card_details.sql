-- ------------------------------------------------------------- trip cards
-- Adds description and photos_count (photos the author uploaded across all
-- stops) for the redesigned home card. New columns go last, as views require.
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
  s.cover_place_id,
  t.description,
  s.photos_count
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
       filter (where st.place_id is not null))[1] as cover_place_id,
    coalesce(sum(cardinality(st.photo_urls)), 0)::int as photos_count
  from public.trip_stops st
  where st.trip_id = t.id
) s;
