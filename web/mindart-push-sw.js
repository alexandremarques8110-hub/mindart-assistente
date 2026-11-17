'use strict';

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = {};
  }
  // No financial details or private notes are embedded in notifications.
  event.waitUntil(self.registration.showNotification('MindArt', {
    body: typeof payload.body === 'string' ? payload.body : 'Você tem um lembrete.',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: typeof payload.tag === 'string' ? payload.tag : 'mindart-reminder',
    data: { url: self.registration.scope },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const url = new URL(self.registration.scope);
    const clients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    const existing = clients.find((client) =>
      client.url.startsWith(url.href) && 'focus' in client);
    if (existing) {
      await existing.focus();
    } else if (self.clients.openWindow) {
      await self.clients.openWindow(url.href);
    }
  })());
});
