import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../domain/models.dart';

final tipoApiProvider = Provider<TipoApi>((ref) => TipoApi());

/// Non-null in widget tests so the dashboard does not open a socket.
final boardSeedProvider = Provider<BoardSnapshot?>((ref) => null);

class BoardController extends AsyncNotifier<BoardSnapshot> {
  Timer? _timer;

  @override
  Future<BoardSnapshot> build() async {
    ref.onDispose(() => _timer?.cancel());
    final seed = ref.watch(boardSeedProvider);
    if (seed != null) return seed;
    final snap = await ref.read(tipoApiProvider).state();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    return snap;
  }

  Future<void> refresh() async {
    final seed = ref.read(boardSeedProvider);
    if (seed != null) {
      state = AsyncData(seed);
      return;
    }
    try {
      final snap = await ref.read(tipoApiProvider).state();
      state = AsyncData(snap);
    } catch (error, stack) {
      if (!state.hasValue) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> replay({String? scenarioId}) async {
    await ref.read(tipoApiProvider).replay(scenarioId: scenarioId);
    await refresh();
  }

  Future<void> reset() async {
    await ref.read(tipoApiProvider).reset();
    await refresh();
  }
}

final boardProvider = AsyncNotifierProvider<BoardController, BoardSnapshot>(BoardController.new);

/// Weather and hazard context for the citizen home card.
class BmkgBrief {
  const BmkgBrief({
    required this.area,
    required this.weatherEn,
    required this.rainMm,
    required this.period,
    required this.nowcast,
    required this.recorded,
    required this.quake,
  });
  final String area;
  final String weatherEn;
  final double rainMm;
  final String period;
  final String nowcast;
  final bool recorded;
  final String quake;

  factory BmkgBrief.fromJson(Map<String, dynamic> json) {
    final live = asMap(json['live']);
    final source = live.isNotEmpty && asMap(live['areas']).isNotEmpty ? live : asMap(json['recorded']);
    final area = asMap(asMap(source['areas'])['dayeuhkolot']);
    final nowcast = source['nowcast'] is List && (source['nowcast'] as List).isNotEmpty ? asMap((source['nowcast'] as List).first) : <String, dynamic>{};
    final quake = asMap(source['earthquake']);
    return BmkgBrief(
      area: '${area['name'] ?? 'Dayeuhkolot, Kab. Bandung'}'.split(',').first,
      weatherEn: '${area['weather_desc_en'] ?? 'No reading'}',
      rainMm: asDouble(area['tp_mm']),
      period: '${area['period'] ?? '3h'}',
      nowcast: '${nowcast['title'] ?? ''}',
      recorded: '${area['source'] ?? 'scenario_snapshot'}' == 'scenario_snapshot',
      quake: quake.isEmpty ? '' : 'M${quake['magnitude']} · ${quake['place'] ?? ''}',
    );
  }
}

final bmkgProvider = FutureProvider<BmkgBrief>((ref) async {
  final json = await ref.read(tipoApiProvider).bmkg();
  return BmkgBrief.fromJson(json);
});
