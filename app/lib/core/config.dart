/// Compile-time configuration.
///
/// Mock mode talks to the local API and does not initialize Firebase.
/// Pass `--dart-define=USE_FIREBASE=true` only after `flutterfire configure`
/// has replaced [firebase_options.dart].
class TipoConfig {
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:8765',
  );
  static const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'tipo-placeholder',
  );
}
