import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location.dart';

/// GPS + reporter id live here so the posko console does not pull geolocator
/// or shared_preferences into the initial desktop bundle.
final locatorProvider = Provider<Locator>((ref) => const Locator());

class ReporterController extends Notifier<String> {
  late Future<void> _restored;

  @override
  String build() {
    _restored = Future.microtask(_restore);
    return 'citizen-demo';
  }

  /// The persisted id. Use this before sending anything, so the first report
  /// is not filed under the placeholder.
  Future<String> ready() async {
    await _restored;
    return state;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('tipo_reporter_id');
      if (existing != null && existing.isNotEmpty) {
        state = existing;
        return;
      }
      final created = 'citizen-${DateTime.now().millisecondsSinceEpoch.remainder(100000)}';
      await prefs.setString('tipo_reporter_id', created);
      state = created;
    } catch (_) {
      // Widget tests and locked-down browsers can skip persistence.
    }
  }
}

final reporterIdProvider = NotifierProvider<ReporterController, String>(ReporterController.new);
