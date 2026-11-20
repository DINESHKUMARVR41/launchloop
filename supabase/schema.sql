-- LaunchLoop production schema (fresh project). Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.creator_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  bio text check (bio is null or char_length(bio) <= 500),
  website_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  description text not null check (char_length(trim(description)) between 20 and 500),
  url text not null check (url ~* '^https?://[^[:space:]]+$'),
  category text not null check (char_length(category) between 1 and 60),
  creator_name text not null check (char_length(creator_name) between 1 and 80),
  tech_stack text[] not null default '{}',
  screenshot_url text not null default '',
  tags text[] not null default '{}',
  status text not null default 'published' check (status in ('draft','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  type text not null check (type in ('experience','bug','feature')),
  rating smallint not null check (rating between 1 and 5),
  message text not null check (char_length(trim(message)) between 8 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.application_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  event_type text not null check (event_type in ('showcase_view','outbound_click')),
  session_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists applications_created_at_idx on public.applications(created_at desc);
create index if not exists applications_category_idx on public.applications(category);
create index if not exists applications_user_created_idx on public.applications(user_id, created_at desc);
create index if not exists feedback_application_created_idx on public.feedback(application_id,created_at desc);
create index if not exists events_application_created_idx on public.application_events(application_id,created_at desc);
create unique index if not exists events_session_dedupe_idx on public.application_events(application_id,event_type,session_id) where session_id is not null;

alter table public.creator_profiles enable row level security;
alter table public.applications enable row level security;
alter table public.feedback enable row level security;
alter table public.application_events enable row level security;

-- Profile is provisioned from the authenticated identity, never from a claimed creator name.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.creator_profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name',''), split_part(new.email,'@',1)))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Applications: public discovery, authenticated ownership for every mutation.
drop policy if exists "published applications are public" on public.applications;
create policy "published applications are public" on public.applications
for select to anon, authenticated using (status = 'published');
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

-- Feedback stays public and does not require a visitor account.
drop policy if exists "feedback is public to read" on public.feedback;
create policy "feedback is public to read" on public.feedback
for select to anon, authenticated using (
  exists (select 1 from public.applications a where a.id = application_id and a.status = 'published')
);
-- Event reads are restricted to owners; writes are accepted only through the rate-limited server API using a server-only service key.
drop policy if exists "events can be read" on public.application_events;
drop policy if exists "application owners read their events" on public.application_events;
create policy "application owners read their events" on public.application_events
for select to authenticated using (
  exists (select 1 from public.applications a where a.id = application_id and a.user_id = auth.uid())
);
drop policy if exists "visitors can record events" on public.application_events;

-- Profiles are visible as public creator cards; only the owner can update theirs.
drop policy if exists "creator profiles are public" on public.creator_profiles;
create policy "creator profiles are public" on public.creator_profiles
for select to anon, authenticated using (true);
drop policy if exists "visitors can create creator profiles" on public.creator_profiles;
drop policy if exists "owners update their profile" on public.creator_profiles;
create policy "owners update their profile" on public.creator_profiles
for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

grant usage on schema public to anon, authenticated;
grant select on public.applications to anon, authenticated;
grant insert, update, delete on public.applications to authenticated;
grant select on public.feedback to anon, authenticated;
grant usage on schema public to service_role;
grant select on public.applications, public.feedback to service_role;
revoke insert on public.feedback from public, anon, authenticated;
grant insert on public.feedback to service_role;
revoke insert on public.application_events from public, anon, authenticated;
grant insert on public.application_events to service_role;
grant select on public.application_events to authenticated;
revoke insert, delete on public.creator_profiles from public, anon, authenticated;
grant select on public.creator_profiles to anon, authenticated;
grant update on public.creator_profiles to authenticated;
