import 'dart:js_interop';
import 'package:web/web.dart' as web;

void Function() watchConnectivity(void Function() resume) {
  final listener = ((web.Event _) {
    resume();
  }).toJS;
  final visible = ((web.Event _) {
    if (web.document.visibilityState == 'visible') resume();
  }).toJS;
  web.window.addEventListener('online', listener);
  web.document.addEventListener('visibilitychange', visible);
  return () {
    web.window.removeEventListener('online', listener);
    web.document.removeEventListener('visibilitychange', visible);
  };
}

@JS('sgActivateUpdate')
external void _activateUpdate();
void activateUpdate() => _activateUpdate();
void requestPersistentStorage() {
  web.window.navigator.storage.persist().toDart.catchError(
    (Object _) => false.toJS,
  );
}
