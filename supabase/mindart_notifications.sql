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
