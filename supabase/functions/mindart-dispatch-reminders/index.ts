// Invoke this function from a trusted cron runner, never from the browser.
// Deploy with --no-verify-jwt; MINDART_CRON_SECRET is mandatory authorization.
import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

type Reminder = { id: string; user_id: string; remind_at: string };
type Subscription = {
  id: string; endpoint: string; p256dh: string; auth: string;
};

Deno.serve(async (request) => {
  const cronSecret = Deno.env.get('MINDART_CRON_SECRET');
  const supplied = request.headers.get('x-mindart-cron-secret');
  if (!cronSecret || !supplied || supplied !== cronSecret) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 });
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const publicKey = Deno.env.get('MINDART_VAPID_PUBLIC_KEY');
  const privateKey = Deno.env.get('MINDART_VAPID_PRIVATE_KEY');
  const subject = Deno.env.get('MINDART_VAPID_SUBJECT');
  if (!supabaseUrl || !serviceKey || !publicKey || !privateKey || !subject) {
    return Response.json({ error: 'Incomplete server configuration' },
      { status: 503 });
  }

  const db = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  webpush.setVapidDetails(subject, publicKey, privateKey);

  const { data: claimed, error } = await db.rpc('mindart_claim_reminders', {
    batch_size: 50,
  });
  if (error) {
    console.error('Failed to claim reminders', error.message);
    return Response.json({ error: 'Reminder query failed' }, { status: 500 });
  }

  const now = Date.now();
  let delivered = 0;
  let failed = 0;
  for (const reminder of (claimed ?? []) as Reminder[]) {
    const { data: subscriptions, error: subscriptionError } = await db
      .from('mindart_push_subscriptions')
      .select('id,endpoint,p256dh,auth')
      .eq('user_id', reminder.user_id);
    if (subscriptionError) {
      failed += 1;
      await db.from('mindart_reminders')
        .update({ claimed_at: null }).eq('id', reminder.id);
      continue;
    }
    // Avoid sending an outdated reminder after an outage or missed cron.
    const stale = Date.parse(reminder.remind_at) < now - 30 * 60 * 1000;
    let retry = false;
    if (!stale) {
      for (const sub of (subscriptions ?? []) as Subscription[]) {
        try {
          await webpush.sendNotification({
            endpoint: sub.endpoint,
            keys: { p256dh: sub.p256dh, auth: sub.auth },
          }, JSON.stringify({
            body: 'Você tem um compromisso próximo.',
            tag: reminder.id,
          }), { TTL: 300 });
          delivered += 1;
        } catch (pushError) {
          const status = (pushError as { statusCode?: number }).statusCode;
          if (status === 404 || status === 410) {
            await db.from('mindart_push_subscriptions')
              .delete().eq('id', sub.id);
          } else {
            retry = true;
            failed += 1;
            console.warn('Push delivery failed', status ?? 'unknown');
          }
        }
      }
    }
    const update = retry
      ? { claimed_at: null }
      : { claimed_at: null, sent_at: new Date().toISOString() };
    const { error: updateError } = await db.from('mindart_reminders')
      .update(update).eq('id', reminder.id);
    if (updateError) {
      console.error('Failed to finalize a reminder', updateError.message);
    }
  }
  return Response.json({
    claimed: (claimed ?? []).length,
    delivered,
    failed,
  }, { headers: { 'cache-control': 'no-store' } });
});
