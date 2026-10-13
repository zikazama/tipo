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
    this.fireRisk = '',
    this.areaKey = '',
    this.areas = const {},
  });
  final String area;
  final String weatherEn;
  final double rainMm;
  final String period;
  final String nowcast;
  final bool recorded;
  final String quake;
  final String fireRisk;
  final String areaKey;
  final Map<String, BmkgBrief> areas;

  BmkgBrief forArea(String key) {
    if (key.isEmpty) return this;
    return areas[key] ?? this;
  }

  factory BmkgBrief.fromJson(Map<String, dynamic> json) {
    final live = asMap(json['live']);
    final source = live.isNotEmpty && asMap(live['areas']).isNotEmpty ? live : asMap(json['recorded']);
    final rawAreas = asMap(source['areas']);
    final nowcast = source['nowcast'] is List && (source['nowcast'] as List).isNotEmpty ? asMap((source['nowcast'] as List).first) : <String, dynamic>{};
    final quake = asMap(source['earthquake']);
    final nowcastTitle = '${nowcast['title'] ?? ''}';
    final quakeLabel = quake.isEmpty ? '' : 'M${quake['magnitude']} · ${quake['place'] ?? ''}';

    BmkgBrief parseArea(String key, Map<String, dynamic> area) {
      return BmkgBrief(
        area: '${area['name'] ?? key}'.split(',').first,
        weatherEn: '${area['weather_desc_en'] ?? 'No reading'}',
        rainMm: asDouble(area['tp_mm']),
        period: '${area['period'] ?? '3h'}',
        nowcast: nowcastTitle,
        recorded: '${area['source'] ?? 'scenario_snapshot'}' == 'scenario_snapshot',
        quake: quakeLabel,
        fireRisk: '${area['fire_risk'] ?? ''}',
        areaKey: key,
      );
    }

    final parsed = <String, BmkgBrief>{};
    for (final entry in rawAreas.entries) {
      parsed[entry.key] = parseArea(entry.key, asMap(entry.value));
    }

    // Prefer flood then karhutla primary keys; otherwise first area in the snapshot.
    BmkgBrief? primary;
    for (final key in const ['dayeuhkolot', 'segati']) {
      if (parsed.containsKey(key)) {
        primary = parsed[key];
        break;
      }
    }
    primary ??= parsed.isNotEmpty ? parsed.values.first : null;
    primary ??= BmkgBrief(
      area: 'Area drill',
      weatherEn: 'No reading',
      rainMm: 0,
      period: '3h',
      nowcast: nowcastTitle,
      recorded: true,
      quake: quakeLabel,
    );

    return BmkgBrief(
      area: primary.area,
      weatherEn: primary.weatherEn,
      rainMm: primary.rainMm,
      period: primary.period,
      nowcast: primary.nowcast,
      recorded: primary.recorded,
      quake: primary.quake,
      fireRisk: primary.fireRisk,
      areaKey: primary.areaKey,
      areas: parsed,
    );
  }
}

final bmkgProvider = FutureProvider<BmkgBrief>((ref) async {
  // Refresh BMKG when the active drill changes (flood ↔ karhutla).
  ref.watch(boardProvider.select((async) => async.value?.activeScenario?.id));
  final json = await ref.read(tipoApiProvider).bmkg();
  return BmkgBrief.fromJson(json);
});
