-- Execute once AFTER reviewing against the existing Supabase project.
-- This is additive: no existing Mercado Progresso tables are modified.

create table if not exists public.mindart_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mindart_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_key text not null,
  remind_at timestamptz not null,
  sent_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, item_key)
);

create index if not exists mindart_reminders_due_idx
  on public.mindart_reminders (remind_at)
  where sent_at is null;

alter table public.mindart_push_subscriptions enable row level security;
alter table public.mindart_reminders enable row level security;

grant select, insert, update, delete
  on public.mindart_push_subscriptions to authenticated;
grant select, insert, update, delete
  on public.mindart_reminders to authenticated;

drop policy if exists "MindArt push own subscriptions"
  on public.mindart_push_subscriptions;
create policy "MindArt push own subscriptions"
  on public.mindart_push_subscriptions for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "MindArt own reminders"
  on public.mindart_reminders;
create policy "MindArt own reminders"
  on public.mindart_reminders for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Concurrent-safe claims for the scheduled Edge Function. Only service_role
-- can call this function, never an authenticated app client.
create or replace function public.mindart_claim_reminders(batch_size integer default 50)
returns setof public.mindart_reminders
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  update public.mindart_reminders r
     set claimed_at = now()
   where r.id in (
     select x.id
       from public.mindart_reminders x
      where x.sent_at is null
        and x.remind_at <= now()
        and (x.claimed_at is null
             or x.claimed_at < now() - interval '5 minutes')
      order by x.remind_at asc
      limit least(greatest(batch_size, 1), 100)
      for update skip locked
   )
  returning r.*;
end;
$$;

revoke all on function public.mindart_claim_reminders(integer)
  from public, anon, authenticated;
grant execute on function public.mindart_claim_reminders(integer)
  to service_role;
