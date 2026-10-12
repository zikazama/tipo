import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'config.dart';

class TipoException implements Exception {
  TipoException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TipoApi {
  TipoApi({http.Client? client, String? base})
      : _client = client ?? http.Client(),
        base = base ?? TipoConfig.apiBase;

  final http.Client _client;
  final String base;

  /// Absolute URL for `/media/...` paths and seeded scenario file names.
  String mediaUrl(String pathOrFile) {
    if (pathOrFile.startsWith('http')) return pathOrFile;
    if (pathOrFile.startsWith('/')) return '$base$pathOrFile';
    return '$base/media/$pathOrFile';
  }

  Future<BoardSnapshot> state() async {
    final json = await _get('/api/state');
    return BoardSnapshot.fromJson(json);
  }

  Future<List<ReportSample>> samples() async {
    final json = await _get('/api/samples');
    return (json['samples'] as List? ?? const []).map((e) => ReportSample.fromJson(asMap(e))).toList();
  }

  Future<SubmitResult> submit(Map<String, dynamic> body) async {
    final json = await _send('POST', '/api/reports', body);
    return SubmitResult.fromJson(json);
  }

  Future<Incident> decide(String id, Map<String, dynamic> body) async {
    final json = await _send('POST', '/api/incidents/$id/decision', body);
    return Incident.fromJson(json);
  }

  Future<ReplayStatus> replay({String? scenarioId}) async {
    final body = <String, dynamic>{};
    if (scenarioId != null && scenarioId.isNotEmpty) {
      body['scenario_id'] = scenarioId;
    }
    final json = await _send('POST', '/api/replay', body);
    return ReplayStatus.fromJson(json);
  }

  Future<List<ScenarioInfo>> scenarios() async {
    final json = await _get('/api/scenarios');
    return (json['scenarios'] as List? ?? const []).map((e) => ScenarioInfo.fromJson(asMap(e))).toList();
  }

  Future<void> reset() async {
    await _send('POST', '/api/replay/reset', {});
  }

  Future<void> presence({required String reporterId, required double lat, required double lng}) async {
    await _send('POST', '/api/presence', {'reporter_id': reporterId, 'lat': lat, 'lng': lng, 'label': 'Citizen device'});
  }

  Future<Map<String, dynamic>> bmkg({bool live = false}) => _get('/api/bmkg?live=$live');

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client.get(Uri.parse('$base$path'));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$base$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final raw = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(raw);
    if (response.statusCode >= 400) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw TipoException(detail?.toString() ?? 'The posko API returned ${response.statusCode}.');
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.map((k, v) => MapEntry('$k', v));
    return {'data': decoded};
  }
}
