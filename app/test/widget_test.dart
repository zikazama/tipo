import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipo/core/theme.dart';
import 'package:tipo/domain/models.dart';
import 'package:tipo/presentation/routing/app_router.dart';
import 'package:tipo/presentation/state/citizen_providers.dart';
import 'package:tipo/presentation/state/providers.dart';

import 'support/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'tipo_reporter_id': 'warga-01'});
  });

  Future<GoRouter> pumpApp(WidgetTester tester, {BoardSnapshot? seed, FakeTipoApi? api, String? at, Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    final router = createRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tipoApiProvider.overrideWithValue(api ?? FakeTipoApi(board: seed)),
          locatorProvider.overrideWithValue(const NoGpsLocator()),
          reporterIdProvider.overrideWith(TestReporterController.new),
          if (seed != null) boardSeedProvider.overrideWithValue(seed),
        ],
        child: MaterialApp.router(theme: citizenTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    if (at != null) router.go(at);
    // Extra pumps finish deferred citizen loadLibrary() and route transitions.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Citizen route transitions are 240ms; allow extra frames when the deferred
    // library was already loaded by an earlier test in this file.
    await tester.pump(const Duration(milliseconds: 300));
    return router;
  }

  testWidgets('citizen home leads with the report button', (tester) async {
    await pumpApp(tester, seed: emptyBoard(), at: '/', size: const Size(412, 915));
    expect(find.text('Lapor sekarang'), findsOneWidget);
    expect(find.text('Report now'), findsOneWidget);
    expect(find.text('Read the signs. Act first.'), findsOneWidget);
    // Let citizen presence / BMKG microtasks finish before the next test reuses the isolate.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('empty report explains what is missing', (tester) async {
    await pumpApp(tester, seed: emptyBoard(), at: '/report', size: const Size(420, 1600));
    await tester.tap(find.byKey(const Key('send-report')));
    await tester.pump();
    expect(find.text('Add a description, a photo, or a voice note before sending.'), findsOneWidget);
  });

  testWidgets('operator queue shows priority and credibility', (tester) async {
    await pumpApp(tester, seed: demoBoard(), at: '/ops', size: const Size(1400, 900));
    expect(find.text('Flood — Dayeuhkolot'), findsWidgets);
    expect(find.textContaining('CRITICAL'), findsWidgets);
    expect(find.textContaining('Low credibility'), findsWidgets);
    expect(find.text('Approve and send alert', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('BMKG', skipOffstage: false), findsWidgets);
    expect(find.text('Agent activity'), findsOneWidget);
  });

  testWidgets('hoax ticket shows a warning with reasons', (tester) async {
    await pumpApp(tester, seed: demoBoard(), at: '/ops', size: const Size(1400, 900));
    await tester.tap(find.text('Flood — old photo').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Possible hoax. Do not alert yet.'), findsOneWidget);
    expect(find.textContaining('old-photo risk'), findsWidgets);
  });

  testWidgets('approving shows a preview and sends only after confirmation', (tester) async {
    final api = FakeTipoApi(board: demoBoard());
    await pumpApp(tester, seed: demoBoard(), api: api, at: '/ops', size: const Size(1400, 900));
    await tester.tap(find.text('Approve and send alert'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Send this alert?'), findsOneWidget);
    expect(find.text('Flood near Dayeuhkolot'), findsOneWidget);
    expect(find.text('Send alert to 1 device'), findsOneWidget);
    expect(api.decisions, isEmpty);

    await tester.tap(find.text('Send alert to 1 device'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.decisions.single.$1, 'inc-dk');
    expect(api.decisions.single.$2['send_alert'], isTrue);
  });

  testWidgets('sitrep draft is readable', (tester) async {
    await pumpApp(tester, seed: demoBoard(), at: '/ops/sitrep/inc-dk');
    expect(find.textContaining('SITUATION REPORT'), findsOneWidget);
    expect(find.textContaining('human operator'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('status page shows the timeline and English rendering', (tester) async {
    await pumpApp(tester, seed: demoBoard(), at: '/mine/rpt-01', size: const Size(412, 1800));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Diterima'), findsOneWidget);
    expect(find.textContaining('Diverifikasi'), findsOneWidget);
    expect(find.text('ENGLISH RENDERING'), findsOneWidget);
    expect(find.textContaining('Water has risen in Dayeuhkolot.'), findsOneWidget);
  });

  testWidgets('inbox lists messages for this reporter', (tester) async {
    await pumpApp(tester, seed: demoBoard(), at: '/inbox', size: const Size(412, 915));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Laporan Anda diverifikasi'), findsOneWidget);
  });
}
