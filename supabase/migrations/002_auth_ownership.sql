-- Upgrade an existing LaunchLoop schema to authenticated ownership.
alter table public.applications add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.creator_profiles add column if not exists user_id uuid references auth.users(id) on delete cascade;
create unique index if not exists creator_profiles_user_id_idx on public.creator_profiles(user_id);
create index if not exists applications_user_created_idx on public.applications(user_id, created_at desc);
alter table public.creator_profiles add column if not exists updated_at timestamptz not null default now();
-- Session key makes showcase-view and outbound-click writes idempotent per browser tab session.
alter table public.application_events add column if not exists session_id uuid;
create unique index if not exists events_session_dedupe_idx on public.application_events(application_id,event_type,session_id) where session_id is not null;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.creator_profiles (user_id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name',''), split_part(new.email,'@',1)))
  on conflict (user_id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

drop policy if exists "visitors can submit applications" on public.applications;
drop policy if exists "creators read their own applications" on public.applications;
create policy "creators read their own applications" on public.applications
for select to authenticated using (auth.uid() = user_id);
drop policy if exists "creators insert their own applications" on public.applications;
create policy "creators insert their own applications" on public.applications
for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "creators update their own applications" on public.applications;
create policy "creators update their own applications" on public.applications
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "creators delete their own applications" on public.applications;
create policy "creators delete their own applications" on public.applications
for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "events can be read" on public.application_events;
drop policy if exists "application owners read their events" on public.application_events;
create policy "application owners read their events" on public.application_events
for select to authenticated using (
  exists (select 1 from public.applications a where a.id = application_id and a.user_id = auth.uid())
);
drop policy if exists "visitors can submit feedback" on public.feedback;
drop policy if exists "visitors can record events" on public.application_events;
revoke insert on public.feedback from public, anon, authenticated;
revoke insert on public.application_events from public, anon, authenticated;
grant insert on public.feedback to service_role;
grant insert on public.application_events to service_role;

drop policy if exists "visitors can create creator profiles" on public.creator_profiles;
drop policy if exists "owners update their profile" on public.creator_profiles;
create policy "owners update their profile" on public.creator_profiles
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

revoke insert, update, delete on public.applications from public, anon;
grant select on public.applications to anon, authenticated;
grant insert, update, delete on public.applications to authenticated;
grant select on public.feedback to anon, authenticated;
grant usage on schema public to service_role;
grant select on public.applications, public.feedback to service_role;

revoke all on public.application_events from public, anon;
grant select on public.application_events to authenticated;
revoke insert, delete on public.creator_profiles from public, anon, authenticated;
grant select on public.creator_profiles to anon, authenticated;
grant update on public.creator_profiles to authenticated;
