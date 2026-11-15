-- Additive setup for MindArt in the existing Supabase project. Run once.
-- The app stores a JSON snapshot per signed-in user. RLS prevents users from
-- reading or changing another user's data.

create table public.mindart_user_data (
  user_id uuid primary key references auth.users (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.mindart_user_data enable row level security;

grant select, insert, update, delete on public.mindart_user_data to authenticated;

create policy "Users manage their own MindArt data"
  on public.mindart_user_data
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'mindart_user_data'
  ) then
    alter publication supabase_realtime add table public.mindart_user_data;
  end if;
end
$$;
