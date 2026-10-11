import 'core/config.dart';

/// Placeholder for FlutterFire output.
///
/// Run `flutterfire configure` inside `app/` and let it replace this file.
/// The app builds and runs in mock mode without that step because nothing
/// imports `firebase_core` unless you add it after configuring a real project.
class DefaultFirebaseOptions {
  static const enabled = TipoConfig.useFirebase;
  static const projectId = TipoConfig.firebaseProjectId;
  static const androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:000000000000:android:placeholder',
  );
  static const webAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '1:000000000000:web:placeholder',
  );
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '000000000000',
  );

  static void assertConfigured() {
    if (!enabled) {
      throw StateError(
        'Firebase is off. The mock inbox polls /api/notifications. '
        'Set --dart-define=USE_FIREBASE=true after flutterfire configure.',
      );
    }
    if (projectId == 'tipo-placeholder') {
      throw StateError('Replace lib/firebase_options.dart with flutterfire configure output.');
    }
  }
}
