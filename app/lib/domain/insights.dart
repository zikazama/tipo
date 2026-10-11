import 'dart:math' as math;

import 'models.dart';

/// Same default radius the API uses for nearby alerts (TIPO_NEARBY_RADIUS_M).
const nearbyRadiusM = 2000.0;

double haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

/// Devices the API will reach if the operator approves with an alert.
/// Mirrors `Pipeline._nearby_recipients`: standby devices plus other reporters
/// inside the radius, minus the people who reported this incident.
List<String> nearbyRecipients(Incident incident, BoardSnapshot snap, {double radiusM = nearbyRadiusM}) {
  final originators = incident.reporterIds.toSet();
  final seen = <String>{};
  final points = [
    ...snap.presence,
    ...snap.reports.map((r) => GeoPoint(id: r.reporterId, lat: r.lat, lng: r.lng)),
  ];
  for (final p in points) {
    if (p.id.isEmpty || originators.contains(p.id) || seen.contains(p.id)) continue;
    if (haversineM(incident.lat, incident.lng, p.lat, p.lng) <= radiusM) seen.add(p.id);
  }
  return seen.toList();
}

class AlertPreview {
  const AlertPreview(this.title, this.body);
  final String title;
  final String body;
}

AlertPreview alertPreview(Incident incident) {
  final hazard = incident.hazardType.isEmpty ? 'hazard' : incident.hazardType;
  final place = incident.placeLabel.split(',').first;
  return AlertPreview(
    '${hazard[0].toUpperCase()}${hazard.substring(1)} near $place',
    'A posko operator confirmed a $hazard near ${incident.placeLabel}. '
        'Avoid low ground and follow posko instructions. This alert was sent by a human, not by the model.',
  );
}

enum ReasonTone { risk, support, neutral }

/// Sorts a verification reason into a flag, a supporting signal, or context.
ReasonTone reasonTone(String reason) {
  final low = reason.toLowerCase();
  const risk = ['old-photo', 'may not', 'visual cue', 'far from', 'does not support', 'km from the pin', 'mismatch', 'capped'];
  const support = ['consistent', 'already open', 'merged', 'matches', 'corroborat'];
  if (risk.any(low.contains)) return ReasonTone.risk;
  if (support.any(low.contains)) return ReasonTone.support;
  return ReasonTone.neutral;
}

class EvidenceFlag {
  const EvidenceFlag(this.label, this.risk);
  final String label;
  final bool risk;
}

/// EXIF checks shown on each piece of evidence. Thresholds match the
/// verification agent: older than 14 days, or more than 25 km from the pin.
List<EvidenceFlag> evidenceFlags(CitizenReport report) {
  final flags = <EvidenceFlag>[];
  final exif = report.exif;
  final hasPhoto = report.photoUrl != null || report.photoFile != null;
  if (hasPhoto && (exif == null || exif.isEmpty)) {
    flags.add(const EvidenceFlag('No EXIF · neutral', false));
  }
  if (exif != null && exif.isNotEmpty) {
    final taken = asTime(exif['taken_at']);
    final reportedAt = report.createdAt ?? DateTime.now();
    if (taken != null) {
      final days = reportedAt.difference(taken).inDays;
      final date = '${taken.year}-${taken.month.toString().padLeft(2, '0')}-${taken.day.toString().padLeft(2, '0')}';
      flags.add(days > 14 ? EvidenceFlag('EXIF $date · $days days old', true) : EvidenceFlag('EXIF time $date · fresh', false));
    }
    if (exif['lat'] != null && exif['lng'] != null) {
      final km = haversineM(asDouble(exif['lat']), asDouble(exif['lng']), report.lat, report.lng) / 1000;
      flags.add(km > 25 ? EvidenceFlag('EXIF GPS ${km.round()} km from pin', true) : EvidenceFlag('EXIF GPS matches pin', false));
    }
  }
  for (final cue in report.imageCues) {
    flags.add(EvidenceFlag(cue, true));
  }
  return flags;
}

class PriorityFactor {
  const PriorityFactor(this.label, this.weight, this.value);
  final String label;
  final double weight;
  final double value;
  double get points => 100 * weight * value;
}

/// The triage weights, so the operator sees how the score was built.
List<PriorityFactor> priorityFactors(Incident i) {
  final urgent = i.trapped > 0 || i.needs.any((n) => const ['evacuation', 'boat', 'medicine'].contains(n));
  return [
    PriorityFactor('Severity ${i.severity}/5', 0.34, (i.severity / 5).clamp(0, 1).toDouble()),
    PriorityFactor('People affected ${i.peopleAffected}', 0.24, (i.peopleAffected / 150).clamp(0, 1).toDouble()),
    PriorityFactor(i.vulnerable.isEmpty ? 'No vulnerable groups named' : 'Vulnerable: ${i.vulnerable.join(', ')}', 0.16, i.vulnerable.isEmpty ? 0 : 1),
    PriorityFactor('Credibility ${i.credibility}/100', 0.18, (i.credibility / 100).clamp(0, 1).toDouble()),
    PriorityFactor(urgent ? 'Urgent need (trapped, boat, evacuation)' : 'No urgent need named', 0.08, urgent ? 1 : 0),
  ];
}

String languageLabel(String code) {
  switch (code) {
    case 'su':
      return 'Basa Sunda';
    case 'jv':
      return 'Basa Jawa';
    case 'en':
      return 'English';
    case 'id':
      return 'Bahasa Indonesia';
    default:
      return code.isEmpty ? 'Auto' : code;
  }
}

String channelLabel(String channel) {
  switch (channel) {
    case 'whatsapp_sim':
      return 'WhatsApp (sim)';
    case 'voice':
      return 'Voice note';
    case 'petabencana':
      return 'PetaBencana';
    default:
      return 'TIPO app';
  }
}
