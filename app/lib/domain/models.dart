class Incident {
  Incident({
    required this.id,
    required this.title,
    required this.summary,
    required this.hazardType,
    required this.placeLabel,
    required this.lat,
    required this.lng,
    required this.reportIds,
    required this.channels,
    required this.reporterIds,
    required this.credibility,
    required this.credibilityReasons,
    required this.priorityScore,
    required this.priorityBand,
    required this.priorityReasons,
    required this.peopleAffected,
    required this.trapped,
    required this.vulnerable,
    required this.needs,
    required this.severity,
    required this.status,
    required this.logistics,
    required this.suggestedTeam,
    required this.standbyTeam,
    required this.shelter,
    required this.sitrepMarkdown,
    required this.agentTrace,
    required this.decision,
    required this.updatesSinceDecision,
    this.createdAt,
    this.updatedAt,
  });

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String id;
  final String title;
  final String summary;
  final String hazardType;
  final String placeLabel;
  final double lat;
  final double lng;
  final List<String> reportIds;
  final List<String> channels;
  final List<String> reporterIds;
  final int credibility;
  final List<String> credibilityReasons;
  final int priorityScore;
  final String priorityBand;
  final List<String> priorityReasons;
  final int peopleAffected;
  final int trapped;
  final List<String> vulnerable;
  final List<String> needs;
  final int severity;
  final String status;
  final Logistics logistics;
  final TeamSuggestion? suggestedTeam;
  final TeamSuggestion? standbyTeam;
  final ShelterSuggestion? shelter;
  final String sitrepMarkdown;
  final List<AgentStep> agentTrace;
  final Decision? decision;
  final int updatesSinceDecision;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: '${json['id']}',
      title: '${json['title'] ?? 'Incident'}',
      summary: '${json['summary'] ?? ''}',
      hazardType: '${json['hazard_type'] ?? 'other'}',
      placeLabel: '${json['place_label'] ?? ''}',
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
      reportIds: asStrings(json['report_ids']),
      channels: asStrings(json['channels']),
      reporterIds: asStrings(json['reporter_ids']),
      credibility: asInt(json['credibility']),
      credibilityReasons: asStrings(json['credibility_reasons']),
      priorityScore: asInt(json['priority_score']),
      priorityBand: '${json['priority_band'] ?? 'low'}',
      priorityReasons: asStrings(json['priority_reasons']),
      peopleAffected: asInt(json['people_affected']),
      trapped: asInt(json['trapped']),
      vulnerable: asStrings(json['vulnerable']),
      needs: asStrings(json['needs']),
      severity: asInt(json['severity']),
      status: '${json['status'] ?? 'open'}',
      logistics: Logistics.fromJson(asMap(json['logistics'])),
      suggestedTeam: json['suggested_team'] == null ? null : TeamSuggestion.fromJson(asMap(json['suggested_team'])),
      standbyTeam: json['standby_team'] == null ? null : TeamSuggestion.fromJson(asMap(json['standby_team'])),
      shelter: json['shelter'] == null ? null : ShelterSuggestion.fromJson(asMap(json['shelter'])),
      sitrepMarkdown: '${json['sitrep_markdown'] ?? ''}',
      agentTrace: (json['agent_trace'] as List? ?? const []).map((e) => AgentStep.fromJson(asMap(e))).toList(),
      decision: json['decision'] == null ? null : Decision.fromJson(asMap(json['decision'])),
      updatesSinceDecision: asInt(json['updates_since_decision']),
      createdAt: asTime(json['created_at']),
      updatedAt: asTime(json['updated_at']),
    );
  }
}

class Logistics {
  const Logistics({this.waterLitersPerDay = 0, this.readyMeals = 0, this.boats = 0, this.familyKits = 0});
  final int waterLitersPerDay;
  final int readyMeals;
  final int boats;
  final int familyKits;
  factory Logistics.fromJson(Map<String, dynamic> json) => Logistics(
        waterLitersPerDay: asInt(json['water_liters_per_day']),
        readyMeals: asInt(json['ready_meals']),
        boats: asInt(json['boats']),
        familyKits: asInt(json['family_kits']),
      );
}

class TeamSuggestion {
  TeamSuggestion({required this.id, required this.name, required this.posko, required this.etaMin, required this.kind});
  final String id;
  final String name;
  final String posko;
  final int etaMin;
  final String kind;
  factory TeamSuggestion.fromJson(Map<String, dynamic> json) => TeamSuggestion(
        id: '${json['id']}',
        name: '${json['name'] ?? 'Team'}',
        posko: '${json['posko'] ?? ''}',
        etaMin: asInt(json['eta_min']),
        kind: '${json['kind'] ?? ''}',
      );
}

class ShelterSuggestion {
  ShelterSuggestion({required this.name, required this.bedsFree, required this.distanceM});
  final String name;
  final int bedsFree;
  final int distanceM;
  factory ShelterSuggestion.fromJson(Map<String, dynamic> json) => ShelterSuggestion(
        name: '${json['name'] ?? 'Shelter'}',
        bedsFree: asInt(json['beds_free']),
        distanceM: asInt(json['distance_m']),
      );
}

class AgentStep {
  AgentStep({required this.agent, required this.mode, required this.model, required this.summary});
  final String agent;
  final String mode;
  final String model;
  final String summary;
  factory AgentStep.fromJson(Map<String, dynamic> json) => AgentStep(
        agent: '${json['agent'] ?? ''}',
        mode: '${json['mode'] ?? ''}',
        model: '${json['model'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
      );
}

class Decision {
  Decision({required this.action, required this.operatorName, required this.note, required this.alertSent, this.decidedAt});
  final DateTime? decidedAt;
  final String action;
  final String operatorName;
  final String note;
  final bool alertSent;
  factory Decision.fromJson(Map<String, dynamic> json) => Decision(
        action: '${json['action'] ?? ''}',
        operatorName: '${json['operator_name'] ?? ''}',
        note: '${json['note'] ?? ''}',
        alertSent: json['alert_sent'] == true,
        decidedAt: asTime(json['decided_at']),
      );
}

class CitizenReport {
  CitizenReport({
    required this.id,
    required this.channel,
    required this.reporterId,
    required this.text,
    required this.transcript,
    required this.translationEn,
    required this.language,
    required this.status,
    required this.incidentId,
    required this.lat,
    required this.lng,
    required this.placeName,
    required this.photoUrl,
    required this.audioUrl,
    required this.credibility,
    required this.reasons,
    this.createdAt,
    this.photoFile,
    this.audioFile,
    this.exif,
    this.imageCues = const [],
    this.hazardType = 'other',
    this.severity = 0,
    this.languageName = '',
    this.simulated = false,
    this.steps = const [],
  });
  final DateTime? createdAt;
  final String? photoFile;
  final String? audioFile;
  final Map<String, dynamic>? exif;
  final List<String> imageCues;
  final String hazardType;
  final int severity;
  final String languageName;
  final bool simulated;

  /// Intake, verification, and dedup steps the agents recorded for this report.
  final List<AgentStep> steps;
  final String id;
  final String channel;
  final String reporterId;
  final String text;
  final String transcript;
  final String translationEn;
  final String language;
  final String status;
  final String? incidentId;
  final double lat;
  final double lng;
  final String placeName;
  final String? photoUrl;
  final String? audioUrl;
  final int? credibility;
  final List<String> reasons;

  factory CitizenReport.fromJson(Map<String, dynamic> json) {
    final verification = asMap(json['verification']);
    final intake = asMap(json['intake']);
    final dedup = asMap(json['dedup']);
    return CitizenReport(
      createdAt: asTime(json['created_at']),
      photoFile: json['photo_file']?.toString(),
      audioFile: json['audio_file']?.toString(),
      exif: json['exif'] == null ? null : asMap(json['exif']),
      imageCues: asStrings(json['image_cues']),
      hazardType: '${intake['hazard_type'] ?? 'other'}',
      severity: asInt(intake['severity']),
      languageName: '${intake['language_name'] ?? ''}',
      simulated: json['simulated'] == true,
      steps: [
        if (intake.isNotEmpty) AgentStep.fromJson({...intake, 'summary': intake['summary']}),
        if (verification.isNotEmpty)
          AgentStep.fromJson({
            ...verification,
            'summary': 'Credibility ${verification['credibility']}/100 (${verification['band']}). ${asStrings(verification['reasons']).take(1).join()}',
          }),
        if (dedup.isNotEmpty) AgentStep.fromJson({...dedup, 'summary': dedup['reason'] ?? dedup['action']}),
      ],
      id: '${json['id']}',
      channel: '${json['channel'] ?? 'app'}',
      reporterId: '${json['reporter_id'] ?? ''}',
      text: '${json['text'] ?? ''}',
      transcript: '${json['transcript'] ?? ''}',
      translationEn: '${json['translation_en'] ?? ''}',
      language: '${json['language'] ?? ''}',
      status: '${json['status'] ?? 'received'}',
      incidentId: json['incident_id']?.toString(),
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
      placeName: '${json['place_name'] ?? ''}',
      photoUrl: json['photo_url']?.toString(),
      audioUrl: json['audio_url']?.toString(),
      credibility: verification.isEmpty ? null : asInt(verification['credibility']),
      reasons: asStrings(verification['reasons']),
    );
  }
}

class Notice {
  Notice({required this.id, required this.type, required this.title, required this.body, required this.reporterId, required this.incidentId, this.createdAt});
  final DateTime? createdAt;
  final String id;
  final String type;
  final String title;
  final String body;
  final String? reporterId;
  final String? incidentId;
  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: '${json['id']}',
        type: '${json['type'] ?? ''}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        reporterId: json['reporter_id']?.toString(),
        incidentId: json['incident_id']?.toString(),
        createdAt: asTime(json['created_at']),
      );
}

class ReportSample {
  ReportSample({
    required this.id,
    required this.label,
    required this.channel,
    required this.text,
    required this.translationEn,
    required this.lat,
    required this.lng,
    required this.placeName,
    required this.photoFile,
    required this.audioFile,
    required this.imageCues,
    required this.exif,
  });
  final String id;
  final String label;
  final String channel;
  final String text;
  final String translationEn;
  final double lat;
  final double lng;
  final String placeName;
  final String? photoFile;
  final String? audioFile;
  final List<String> imageCues;
  final Map<String, dynamic>? exif;
  factory ReportSample.fromJson(Map<String, dynamic> json) => ReportSample(
        id: '${json['id']}',
        label: '${json['label'] ?? 'Sample'}',
        channel: '${json['channel'] ?? 'app'}',
        text: '${json['text'] ?? json['transcript'] ?? ''}',
        translationEn: '${json['translation_en'] ?? ''}',
        lat: asDouble(json['lat']),
        lng: asDouble(json['lng']),
        placeName: '${json['place_name'] ?? ''}',
        photoFile: json['photo_file']?.toString(),
        audioFile: json['audio_file']?.toString(),
        imageCues: asStrings(json['image_cues']),
        exif: json['exif'] == null ? null : asMap(json['exif']),
      );
}

class ReplayStatus {
  const ReplayStatus({this.running = false, this.ingested = 0, this.total = 25});
  final bool running;
  final int ingested;
  final int total;
  factory ReplayStatus.fromJson(Map<String, dynamic> json) => ReplayStatus(
        running: json['running'] == true,
        ingested: asInt(json['ingested']),
        total: asInt(json['total'], 25),
      );
}

class BoardSnapshot {
  BoardSnapshot({
    required this.incidents,
    required this.reports,
    required this.notifications,
    required this.replay,
    required this.mode,
    required this.model,
    this.presence = const [],
  });

  /// Standby devices the posko can reach with a nearby alert.
  final List<GeoPoint> presence;
  final List<Incident> incidents;
  final List<CitizenReport> reports;
  final List<Notice> notifications;
  final ReplayStatus replay;
  final String mode;
  final String model;

  factory BoardSnapshot.fromJson(Map<String, dynamic> json) {
    final meta = asMap(json['meta']);
    final models = asMap(meta['models']);
    return BoardSnapshot(
      incidents: (json['incidents'] as List? ?? const []).map((e) => Incident.fromJson(asMap(e))).toList(),
      reports: (json['reports'] as List? ?? const []).map((e) => CitizenReport.fromJson(asMap(e))).toList(),
      notifications: (json['notifications'] as List? ?? const []).map((e) => Notice.fromJson(asMap(e))).toList(),
      replay: ReplayStatus.fromJson(asMap(json['replay'])),
      mode: '${meta['mode'] ?? 'mock'}',
      model: '${models['main'] ?? 'gemini-3.8-flash'}',
      presence: (json['presence'] as List? ?? const [])
          .map((e) => asMap(e))
          .map((m) => GeoPoint(id: '${m['reporter_id'] ?? ''}', lat: asDouble(m['lat']), lng: asDouble(m['lng'])))
          .toList(),
    );
  }
}

class SubmitResult {
  SubmitResult({required this.report, required this.incident});
  final CitizenReport report;
  final Incident? incident;
  factory SubmitResult.fromJson(Map<String, dynamic> json) => SubmitResult(
        report: CitizenReport.fromJson(asMap(json['report'])),
        incident: json['incident'] == null ? null : Incident.fromJson(asMap(json['incident'])),
      );
}

class GeoPoint {
  const GeoPoint({required this.id, required this.lat, required this.lng});
  final String id;
  final double lat;
  final double lng;
}

DateTime? asTime(dynamic value) => value == null ? null : DateTime.tryParse('$value');

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

List<String> asStrings(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).toList();
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return {};
}
