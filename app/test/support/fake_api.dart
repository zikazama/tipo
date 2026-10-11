import 'package:tipo/core/api.dart';
import 'package:tipo/core/location.dart';
import 'package:tipo/domain/models.dart';

class FakeTipoApi extends TipoApi {
  FakeTipoApi({this.board}) : super(base: 'http://127.0.0.1:9');

  final BoardSnapshot? board;
  final decisions = <(String, Map<String, dynamic>)>[];

  @override
  Future<BoardSnapshot> state() async => board ?? emptyBoard();

  @override
  Future<List<ReportSample>> samples() async => const [];

  @override
  Future<void> presence({required String reporterId, required double lat, required double lng}) async {}

  @override
  Future<ReplayStatus> replay() async => const ReplayStatus();

  @override
  Future<void> reset() async {}

  @override
  Future<Incident> decide(String id, Map<String, dynamic> body) async {
    decisions.add((id, body));
    return (board ?? demoBoard()).incidents.firstWhere((i) => i.id == id);
  }

  @override
  Future<Map<String, dynamic>> bmkg({bool live = false}) async => {
        'recorded': {
          'areas': {
            'dayeuhkolot': {
              'name': 'Dayeuhkolot, Kab. Bandung',
              'weather_desc_en': 'Heavy rain',
              'tp_mm': 45.0,
              'period': '3h',
              'source': 'scenario_snapshot',
            },
          },
          'nowcast': [
            {'title': 'Hujan lebat disertai petir di Kab. Bandung'},
          ],
        },
      };
}

class NoGpsLocator extends Locator {
  const NoGpsLocator();
  @override
  Future<LocatedPoint?> locate() async => null;
}

BoardSnapshot emptyBoard() {
  return BoardSnapshot(
    incidents: const [],
    reports: const [],
    notifications: const [],
    replay: const ReplayStatus(total: 25),
    mode: 'mock',
    model: 'gemini-3.8-flash',
  );
}

BoardSnapshot demoBoard() {
  Incident incident({
    required String id,
    required String title,
    required String band,
    required int score,
    required int credibility,
    required List<String> reasons,
    String sitrep = '',
    List<String> reporters = const ['warga-01'],
  }) {
    return Incident(
      id: id,
      title: title,
      summary: 'Merged citizen reports.',
      hazardType: 'flood',
      placeLabel: 'Dayeuhkolot, Kabupaten Bandung',
      lat: -6.975,
      lng: 107.625,
      reportIds: const ['rpt-01'],
      channels: const ['app', 'voice'],
      reporterIds: reporters,
      credibility: credibility,
      credibilityReasons: reasons,
      priorityScore: score,
      priorityBand: band,
      priorityReasons: const ['Elderly residents are trapped.'],
      peopleAffected: 160,
      trapped: 8,
      vulnerable: const ['elderly'],
      needs: const ['boat'],
      severity: 5,
      status: 'open',
      logistics: const Logistics(waterLitersPerDay: 480, readyMeals: 320, boats: 2, familyKits: 40),
      suggestedTeam: TeamSuggestion(id: 'boat-dk-1', name: 'Rubber boat 1', posko: 'Posko Dayeuhkolot', etaMin: 12, kind: 'boat'),
      standbyTeam: null,
      shelter: null,
      sitrepMarkdown: sitrep,
      agentTrace: [
        AgentStep(agent: 'intake', mode: 'mock', model: 'gemini-3.8-flash', summary: 'Flood, severity 5.'),
        AgentStep(agent: 'triage', mode: 'mock', model: 'gemini-3.8-flash', summary: 'Priority 94 critical.'),
      ],
      decision: null,
      updatesSinceDecision: 0,
    );
  }

  return BoardSnapshot(
    incidents: [
      incident(
        id: 'inc-dk',
        title: 'Flood — Dayeuhkolot',
        band: 'critical',
        score: 94,
        credibility: 86,
        reasons: const ['BMKG heavy rain matches the reports. Weather is consistent with this hazard.'],
        sitrep: '# SITUATION REPORT (draft)\n## BNPB-style brief\n\n- **Event:** Flood\n\nA human operator must approve this draft before any warning is sent.',
      ),
      incident(
        id: 'inc-hoax',
        title: 'Flood — old photo',
        band: 'low',
        score: 17,
        credibility: 12,
        reporters: const ['warga-99'],
        reasons: const ['EXIF timestamp is 2024-02-11, long before this report (old-photo risk).'],
      ),
    ],
    reports: [
      CitizenReport(
        id: 'rpt-01',
        channel: 'voice',
        reporterId: 'warga-01',
        text: 'Punten, cai di Dayeuhkolot.',
        transcript: 'Punten, cai di Dayeuhkolot.',
        translationEn: 'Water has risen in Dayeuhkolot.',
        language: 'su',
        status: 'triaged',
        incidentId: 'inc-dk',
        lat: -6.97,
        lng: 107.62,
        placeName: 'Dayeuhkolot',
        photoUrl: null,
        audioUrl: null,
        credibility: 86,
        reasons: const [],
        languageName: 'Sundanese',
        steps: [
          AgentStep(agent: 'intake', mode: 'mock', model: 'gemini-3.8-flash', summary: 'Flood report in Dayeuhkolot.'),
          AgentStep(agent: 'verification', mode: 'mock', model: 'gemini-3.8-flash', summary: 'Credibility 86/100 (high).'),
        ],
      ),
    ],
    notifications: [
      Notice(
        id: 'ntf-1',
        type: 'reporter_status',
        title: 'Laporan Anda diverifikasi',
        body: 'Operator posko meninjau laporan Anda.',
        reporterId: 'warga-01',
        incidentId: 'inc-dk',
      ),
    ],
    presence: const [GeoPoint(id: 'standby-1', lat: -6.976, lng: 107.626)],
    replay: const ReplayStatus(ingested: 25, total: 25),
    mode: 'mock',
    model: 'gemini-3.8-flash',
  );
}
