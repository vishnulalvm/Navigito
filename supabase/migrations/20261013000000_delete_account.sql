-- Account deletion, which both app stores require for apps with sign-up.
-- Deleting the auth user cascades through profiles to everything the user
-- made or did: trips (with their stops), likes, saves, follows, comments and
-- notifications. Uploaded photo files are removed by the app first, through
-- the Storage API, since rows deleted here would leave the files behind.

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'sign in to delete your account' using errcode = '42501';
  end if;
  -- Only ever the caller's own account.
  delete from auth.users where id = uid;
end $$;

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
