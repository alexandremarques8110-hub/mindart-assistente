import 'dart:js_interop';

@JS('mindartPushSubscribe')
external JSPromise<JSString> _mindartPushSubscribe(JSString vapidPublicKey);

Future<String> subscribeToWebPush(String vapidPublicKey) async {
  final response = await _mindartPushSubscribe(vapidPublicKey.toJS).toDart;
  return response.toDart;
}

@JS('mindartPushUnsubscribe')
external JSPromise<JSString> _mindartPushUnsubscribe();

Future<String> unsubscribeFromWebPush() async {
  final response = await _mindartPushUnsubscribe().toDart;
  return response.toDart;
}
