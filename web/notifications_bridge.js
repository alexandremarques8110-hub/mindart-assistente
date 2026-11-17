'use strict';

// Called directly by the Flutter button handler so the iOS permission prompt
// remains tied to an explicit user gesture.
window.mindartPushSubscribe = async function mindartPushSubscribe(vapidPublicKey) {
  if (!('serviceWorker' in navigator) ||
      !('PushManager' in window) ||
      !('Notification' in window)) {
    throw new Error('Web Push não é suportado neste navegador.');
  }

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    throw new Error('Permissão para notificações não concedida.');
  }
  const worker = await navigator.serviceWorker.register(
    'mindart-push-sw.js', { scope: './' }
  );
  function decodeKey(base64url) {
    const padding = '='.repeat((4 - base64url.length % 4) % 4);
    const base64 = (base64url + padding).replace(/-/g, '+').replace(/_/g, '/');
    return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
  }
  let subscription = await worker.pushManager.getSubscription();
  if (!subscription) {
    subscription = await worker.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: decodeKey(vapidPublicKey),
    });
  }
  const record = subscription.toJSON();
  return JSON.stringify({
    endpoint: record.endpoint,
    keys: record.keys,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
  });
};

window.mindartPushUnsubscribe = async function mindartPushUnsubscribe() {
  if (!('serviceWorker' in navigator)) return '';
  const worker = await navigator.serviceWorker.getRegistration('./');
  if (!worker || !worker.pushManager) return '';
  const subscription = await worker.pushManager.getSubscription();
  if (!subscription) return '';
  const endpoint = subscription.endpoint;
  await subscription.unsubscribe();
  return endpoint;
};
