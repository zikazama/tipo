import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:record/record.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../domain/citizen_context.dart';
import '../../domain/insights.dart';
import '../../domain/models.dart';
import '../state/citizen_providers.dart';
import '../state/providers.dart';
import '../widgets/citizen_layout.dart';
import '../widgets/states.dart';
import '../widgets/waveform.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  static const _hazards = [
    ('flood', 'Banjir', 'Flood'),
    ('landslide', 'Longsor', 'Landslide'),
    ('earthquake', 'Gempa', 'Earthquake'),
    ('fire', 'Karhutla / kebakaran', 'Fire'),
    ('other', 'Lainnya', 'Other'),
  ];

  CitizenContext _ctx = CitizenContext.flood;
  String? _hazard;
  String _place = CitizenContext.flood.placeShort;
  (double, double) _pin = (CitizenContext.flood.lat, CitizenContext.flood.lng);
  String _gps = 'locating';
  double? _gpsAccuracy;
  String _language = 'auto';
  String _channel = 'app';
  String? _photoB64;
  Uint8List? _photoBytes;
  String? _photoLabel;
  String? _audioB64;
  String? _audioLabel;
  String? _photoFile;
  String? _audioFile;
  List<String> _cues = const [];
  Map<String, dynamic>? _exif;
  String? _translation;
  String? _error;
  var _busy = false;
  var _recording = false;
  var _elapsed = Duration.zero;
  Duration? _clipLength;
  final _levels = <double>[];
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amp;
  List<ReportSample> _samples = const [];
  var _syncedScenario = false;

  Map<String, (double, double)> get _places => _ctx.places;

  @override
  void initState() {
    super.initState();
    Future.microtask(_syncScenario);
    Future.microtask(_loadSamples);
    Future.microtask(_locate);
  }

  void _syncScenario() {
    final snap = ref.read(boardProvider).value;
    final next = CitizenContext.fromScenario(snap?.activeScenario);
    if (!mounted) return;
    setState(() {
      _ctx = next;
      if (!_syncedScenario || !_places.containsKey(_place)) {
        _place = next.placeShort;
        if (_gps != 'gps') _pin = (next.lat, next.lng);
        if (_hazard == null && next.isFire) _hazard = 'fire';
      }
      _syncedScenario = true;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _ticker?.cancel();
    unawaited(_amp?.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _loadSamples() async {
    try {
      final samples = await ref.read(tipoApiProvider).samples();
      if (mounted) setState(() => _samples = samples);
    } catch (_) {}
  }

  Future<void> _locate() async {
    setState(() => _gps = 'locating');
    final point = await ref.read(locatorProvider).locate();
    if (!mounted) return;
    if (point == null) {
      setState(() => _gps = 'unavailable');
      return;
    }
    final inDrill = haversineM(point.lat, point.lng, _ctx.lat, _ctx.lng) < 40000;
    setState(() {
      if (inDrill) {
        _pin = (point.lat, point.lng);
        _gpsAccuracy = point.accuracyM;
        _gps = 'gps';
        _place = _nearestPlace(point.lat, point.lng);
      } else {
        _gps = 'outside';
      }
    });
  }

  String _nearestPlace(double lat, double lng) {
    var best = _place;
    var bestM = double.infinity;
    for (final entry in _places.entries) {
      final d = haversineM(lat, lng, entry.value.$1, entry.value.$2);
      if (d < bestM) {
        bestM = d;
        best = entry.key;
      }
    }
    return best;
  }

  void _applySample(ReportSample sample) {
    HapticFeedback.selectionClick();
    final hint = sample.hazardHint.toLowerCase();
    final placeLower = sample.placeName.toLowerCase();
    var place = _ctx.placeShort;
    for (final name in _places.keys) {
      if (placeLower.contains(name.toLowerCase().split(' ').first.toLowerCase())) {
        place = name;
        break;
      }
    }
    setState(() {
      _text.text = sample.text;
      _channel = sample.channel;
      _translation = sample.translationEn;
      _photoFile = sample.photoFile;
      _audioFile = sample.audioFile;
      _photoB64 = null;
      _photoBytes = null;
      _audioB64 = null;
      _photoLabel = sample.photoFile == null ? null : 'Foto simulasi';
      _audioLabel = sample.audioFile == null ? null : 'Pesan suara contoh';
      _clipLength = sample.audioFile == null ? null : const Duration(seconds: 9);
      _cues = sample.imageCues;
      _exif = sample.exif;
      _hazard = hint.isNotEmpty ? hint : (_ctx.isFire ? 'fire' : 'flood');
      _error = null;
      _place = place;
      _pin = sample.lat != 0 ? (sample.lat, sample.lng) : _places[_place]!;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    HapticFeedback.selectionClick();
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photoB64 = base64Encode(bytes);
        _photoBytes = bytes;
        _photoFile = null;
        _photoLabel = file.name;
        _cues = const [];
        _exif = null;
      });
    } catch (_) {
      _toast('Kamera atau galeri tidak tersedia. Coba foto contoh di bawah.');
    }
  }

  void _clearPhoto() => setState(() {
    _photoB64 = null;
    _photoBytes = null;
    _photoFile = null;
    _photoLabel = null;
    _cues = const [];
    _exif = null;
  });

  void _clearAudio() => setState(() {
    _audioB64 = null;
    _audioFile = null;
    _audioLabel = null;
    _clipLength = null;
    _levels.clear();
  });

  Future<void> _pickAudioFile() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['wav', 'm4a', 'mp3', 'aac']);
      if (picked.isEmpty) return;
      final file = picked.first;
      final bytes = await file.readAsBytes();
      setState(() {
        _audioB64 = base64Encode(bytes);
        _audioFile = null;
        _audioLabel = file.name;
        _clipLength = null;
      });
    } catch (_) {
      _toast('File audio tidak bisa dibaca.');
    }
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    try {
      if (!await _recorder.hasPermission()) {
        _toast('Izin mikrofon ditolak. Gunakan pesan suara contoh.');
        return;
      }
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: 'tipo-voice.wav');
      HapticFeedback.mediumImpact();
      _levels.clear();
      _amp = _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
        if (!mounted) return;
        setState(() => _levels.add(((a.current + 50) / 50).clamp(0.05, 1.0)));
      });
      final started = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() => _elapsed = DateTime.now().difference(started));
      });
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
    } catch (_) {
      setState(() => _recording = false);
      _toast('Perekaman tidak tersedia di peramban ini. Coba contoh Sunda atau Jawa.');
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    _ticker?.cancel();
    await _amp?.cancel();
    try {
      final path = await _recorder.stop();
      HapticFeedback.lightImpact();
      _recording = false;
      if (path != null && path.isNotEmpty) {
        final bytes = await XFile(path).readAsBytes();
        setState(() {
          _audioB64 = base64Encode(bytes);
          _audioFile = null;
          _audioLabel = 'Rekaman suara';
          _clipLength = _elapsed;
        });
      } else if (mounted) {
        setState(() {});
      }
    } catch (_) {
      setState(() => _recording = false);
    }
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty && _photoB64 == null && _audioB64 == null && _photoFile == null && _audioFile == null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Add a description, a photo, or a voice note before sending.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reporterId = await ref.read(reporterIdProvider.notifier).ready();
      if (!mounted) return;
      final result = await ref.read(tipoApiProvider).submit({
        'reporter_id': reporterId,
        'channel': _channel,
        'text': text,
        'translation_en': _translation,
        'language': _language == 'auto' ? null : _language,
        'hazard_hint': _hazard,
        'lat': _pin.$1,
        'lng': _pin.$2,
        'place_name': _place,
        'photo_base64': _photoB64,
        'audio_base64': _audioB64,
        'photo_file': _photoFile,
        'audio_file': _audioFile,
        'image_cues': _cues,
        'exif': _exif,
        'simulated': _photoFile != null || _audioFile != null,
      });
      if (!mounted) return;
      await ref.read(boardProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/mine/${result.report.id}?sent=1');
    } on TipoException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Posko tidak terjangkau. Could not reach the posko API.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(boardProvider, (prev, next) {
      final id = next.value?.activeScenario?.id;
      final prevId = prev?.value?.activeScenario?.id;
      if (id != prevId) _syncScenario();
    });
    final text = Theme.of(context).textTheme;
    final narrow = CitizenLayout.isNarrow(context);
    final tight = CitizenLayout.isTight(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(_ctx.isFire ? 'Laporan karhutla' : 'Laporan baru'),
      ),
      body: ListView(
        padding: CitizenLayout.pagePadding(context).copyWith(top: Space.xs),
        children: [
          Semantics(
            header: true,
            child: Text(
              _ctx.isFire ? 'Laporkan asap atau api di sekitar Anda.' : 'Ceritakan apa yang terjadi.',
              style: CitizenLayout.pageHeadlineStyle(context),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            _ctx.isFire
                ? 'Tell the posko about smoke or peatland fire. Contoh suara dan foto asap tersedia di Mode demo.'
                : 'Tell the posko what is happening. Pesan suara Sunda dan Jawa dibaca ke tiket yang sama.',
            style: text.bodyMedium?.copyWith(color: context.muted, height: 1.4),
          ),
          const SizedBox(height: Space.xl),
          const SectionTitle('Jenis bahaya', step: 1),
          LayoutBuilder(
            builder: (context, constraints) {
              final fullWidth = narrow ? constraints.maxWidth : null;
              return Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final h in _hazards)
                    SizedBox(
                      width: fullWidth,
                      child: _BigChoice(
                        icon: hazardIcon(h.$1),
                        label: h.$2,
                        sublabel: h.$3,
                        selected: _hazard == h.$1,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _hazard = _hazard == h.$1 ? null : h.$1);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: Space.xl),
          const SectionTitle('Foto', step: 2),
          _photoSection(),
          const SizedBox(height: Space.xl),
          const SectionTitle('Pesan suara', step: 3),
          _voiceSection(),
          const SizedBox(height: Space.xl),
          const SectionTitle('Ceritakan (opsional)', step: 4),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            style: text.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Apa yang Anda lihat? · What do you see?',
              alignLabelWithHint: true,
              hintText: 'Tinggi air, siapa yang terjebak, apa yang dibutuhkan',
            ),
          ),
          const SizedBox(height: Space.xl),
          const SectionTitle('Lokasi', step: 5),
          _locationSection(),
          const SizedBox(height: Space.xl),
          const SectionTitle('Bahasa pesan', step: 6),
          _LanguagePicker(
            value: _language,
            compact: narrow,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _language = v);
            },
          ),
          const SizedBox(height: Space.sm),
          Text('Agen intake menerjemahkan ke bahasa Inggris untuk posko.', style: text.bodySmall),
          const SizedBox(height: Space.xl),
          _demoSection(),
        ],
      ),
      bottomNavigationBar: _SendBar(busy: _busy, error: _error, compact: tight, onSend: _busy ? null : _submit),
    );
  }

  Widget _photoSection() {
    final hasPhoto = _photoBytes != null || _photoFile != null;
    if (!hasPhoto) {
      final narrow = CitizenLayout.isNarrow(context);
      final camera = _TileButton(icon: Icons.photo_camera_rounded, label: 'Kamera', sublabel: 'Take photo', onTap: () => _pickPhoto(ImageSource.camera));
      final gallery = _TileButton(icon: Icons.photo_library_rounded, label: 'Galeri', sublabel: 'Choose photo', onTap: () => _pickPhoto(ImageSource.gallery));
      if (narrow) {
        return Column(
          children: [
            camera,
            const SizedBox(height: Space.md),
            gallery,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: camera),
          const SizedBox(width: Space.md),
          Expanded(child: gallery),
        ],
      );
    }
    final api = ref.read(tipoApiProvider);
    final image = _photoBytes != null
        ? Image.memory(_photoBytes!, fit: BoxFit.cover)
        : Image.network(
            api.mediaUrl(_photoFile!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: TipoColors.navyRaised, child: Center(child: Icon(Icons.image_rounded, color: TipoColors.muted, size: 40))),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: SizedBox(
        height: 196,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(image: true, label: 'Foto terlampir', child: image),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x00000000), Color(0xB3000000)], begin: Alignment.center, end: Alignment.bottomCenter),
              ),
            ),
            Positioned(
              left: Space.md,
              bottom: Space.md,
              right: 64,
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: TipoColors.lowOnDark, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(_photoLabel ?? 'Foto terlampir', style: const TextStyle(color: TipoColors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Positioned(
              right: Space.sm,
              top: Space.sm,
              child: IconButton.filled(
                tooltip: 'Hapus foto',
                style: IconButton.styleFrom(backgroundColor: const Color(0x99000000), foregroundColor: TipoColors.white),
                onPressed: _clearPhoto,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              right: Space.sm,
              bottom: Space.sm,
              child: IconButton.filled(
                tooltip: 'Ambil ulang',
                style: IconButton.styleFrom(backgroundColor: const Color(0x99000000), foregroundColor: TipoColors.white),
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceSection() {
    final hasClip = _audioB64 != null || _audioFile != null;
    final t = _recording ? _elapsed : (_clipLength ?? Duration.zero);
    final clock = '${t.inMinutes.toString().padLeft(2, '0')}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
    final narrow = CitizenLayout.isNarrow(context);
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: _recording ? TipoColors.critical.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
        border: Border.all(color: _recording ? TipoColors.critical : context.line, width: _recording ? 2 : 1),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: [
          if (narrow) ...[
            Center(child: _HoldToRecord(recording: _recording, onStart: _startRecording, onStop: _stopRecording)),
            const SizedBox(height: Space.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!narrow) ...[
                _HoldToRecord(recording: _recording, onStart: _startRecording, onStop: _stopRecording),
                const SizedBox(width: Space.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recording ? 'Merekam… lepas untuk selesai' : hasClip ? (_audioLabel ?? 'Pesan suara') : 'Tahan untuk merekam',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _recording ? 'Recording · release to finish' : hasClip ? 'Siap dikirim · ready to send' : 'Hold to record · or tap to start/stop',
                      style: TextStyle(color: context.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Waveform(
                            levels: _recording ? _levels : null,
                            seed: (_audioLabel ?? 'x').hashCode,
                            color: _recording ? TipoColors.critical : hasClip ? context.link : context.line,
                            height: 30,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Semantics(
                          label: 'Durasi $clock',
                          child: ExcludeSemantics(
                            child: Text(clock, style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], fontWeight: FontWeight.w700, color: _recording ? TipoColors.critical : null)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(onPressed: _pickAudioFile, icon: const Icon(Icons.audio_file_rounded), label: Text(narrow ? 'File audio' : 'Pilih file audio')),
              if (hasClip) TextButton.icon(onPressed: _clearAudio, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Hapus')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationSection() {
    final (label, icon, band) = switch (_gps) {
      'gps' => ('GPS aktif · ±${(_gpsAccuracy ?? 10).round()} m', Icons.gps_fixed_rounded, 'low'),
      'locating' => ('Mencari GPS…', Icons.gps_not_fixed_rounded, 'medium'),
      'outside' => ('Di luar area drill · pin demo', Icons.wrong_location_rounded, 'medium'),
      _ => ('GPS tidak tersedia · pilih tempat', Icons.location_disabled_rounded, 'medium'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: SizedBox(
            height: 150,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: FlutterMap(
                    key: ValueKey(_pin),
                    options: MapOptions(
                      initialCenter: LatLng(_pin.$1, _pin.$2),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      // Static pin preview only — OSM tiles keep widget tests from settling.
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_pin.$1, _pin.$2),
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_on_rounded, color: TipoColors.orange, size: 44, shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: Space.sm,
                  right: Space.sm,
                  top: Space.sm,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 6),
                      decoration: BoxDecoration(color: TipoColors.navy.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(Radii.pill)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 15, color: bandColor(band)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(label, style: const TextStyle(color: TipoColors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 6,
                  bottom: 4,
                  child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final name in _places.keys)
              ChoiceChip(
                avatar: Icon(Icons.place_rounded, size: 18, color: _place == name ? Theme.of(context).colorScheme.onSecondaryContainer : context.muted),
                label: Text(name),
                showCheckmark: false,
                selected: name == _place,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _place = name;
                    if (_gps != 'gps') _pin = _places[name]!;
                  });
                },
              ),
            ActionChip(
              avatar: Icon(Icons.my_location_rounded, size: 18, color: context.link),
              label: const Text('Gunakan GPS'),
              onPressed: _locate,
            ),
          ],
        ),
      ],
    );
  }

  Widget _demoSection() {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(),
          leading: Icon(Icons.science_rounded, color: context.link),
          title: const Text('Mode demo', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Contoh laporan & kanal untuk juri · samples for judges', style: TextStyle(color: context.muted, fontSize: 12.5)),
          childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final sample in _samples)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _applySample(sample),
                  icon: Icon(sample.audioFile != null ? Icons.record_voice_over_rounded : Icons.image_rounded),
                  label: Text(sample.label, textAlign: TextAlign.left),
                ),
              ),
            if (_samples.isEmpty) Text('Contoh dimuat dari posko API.', style: TextStyle(color: context.muted)),
            const SizedBox(height: Space.sm),
            const Text('Kanal · channel', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final channel in const ['app', 'whatsapp_sim', 'voice', 'petabencana'])
                  ChoiceChip(
                    label: Text(channelLabel(channel)),
                    selected: _channel == channel,
                    onSelected: (_) => setState(() => _channel = channel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.compact, required this.onChanged});
  final String value;
  final bool compact;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('auto', 'Otomatis'),
    ('id', 'Bahasa'),
    ('su', 'Sunda'),
    ('jv', 'Jawa'),
  ];

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final (code, label) in _options)
            FilterChip(
              label: Text(label),
              selected: value == code,
              showCheckmark: false,
              onSelected: (_) => onChanged(code),
            ),
        ],
      );
    }
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [for (final (code, label) in _options) ButtonSegment(value: code, label: Text(label))],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

class _SendBar extends StatelessWidget {
  const _SendBar({required this.busy, required this.error, this.compact = false, required this.onSend});
  final bool busy;
  final String? error;
  final bool compact;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: Motion.base,
                child: error == null
                    ? const SizedBox(width: double.infinity)
                    : Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: Space.md),
                          padding: const EdgeInsets.all(Space.md),
                          decoration: BoxDecoration(color: TipoColors.critical.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: context.bandText('critical')),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (error!.startsWith('Add a description'))
                                      Text('Tambahkan cerita, foto, atau pesan suara dulu.', style: TextStyle(color: context.bandText('critical'), fontWeight: FontWeight.w700)),
                                    Text(error!, style: TextStyle(color: context.bandText('critical'), fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              FilledButton.icon(
                key: const Key('send-report'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), textStyle: const TextStyle(fontFamily: bodyFont, fontSize: 17, fontWeight: FontWeight.w800)),
                onPressed: onSend,
                icon: busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: TipoColors.navy))
                    : const Icon(Icons.send_rounded),
                label: Text(busy ? 'Mengirim…' : compact ? 'Kirim ke posko' : 'Kirim ke posko · Send'),
              ),
              const SizedBox(height: 6),
              Text('Petugas posko meninjau sebelum ada peringatan publik.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.icon, required this.label, required this.sublabel, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $sublabel',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: Motion.fast,
          decoration: BoxDecoration(
            color: selected ? TipoColors.orange.withValues(alpha: context.isDark ? 0.24 : 0.16) : scheme.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: selected ? TipoColors.orange : context.line, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md + 2, vertical: Space.md),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: selected ? context.link : scheme.onSurface),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(sublabel, style: TextStyle(color: context.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({required this.icon, required this.label, required this.sublabel, required this.onTap});
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $sublabel',
      child: ExcludeSemantics(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: context.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.lg),
            onTap: onTap,
            child: SizedBox(
              height: 104,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: context.link),
                  const SizedBox(height: Space.sm),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(sublabel, style: TextStyle(color: context.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big round mic. Hold to record, release to stop. A tap also toggles, so it
/// works with switch access and screen readers.
class _HoldToRecord extends StatefulWidget {
  const _HoldToRecord({required this.recording, required this.onStart, required this.onStop});
  final bool recording;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  @override
  State<_HoldToRecord> createState() => _HoldToRecordState();
}

class _HoldToRecordState extends State<_HoldToRecord> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _HoldToRecord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.recording ? TipoColors.critical : TipoColors.navy;
    return Semantics(
      button: true,
      label: widget.recording ? 'Berhenti merekam. Stop recording.' : 'Rekam pesan suara. Record a voice note.',
      child: GestureDetector(
        onTap: () => widget.recording ? widget.onStop() : widget.onStart(),
        onLongPressStart: (_) => widget.onStart(),
        onLongPressEnd: (_) => widget.onStop(),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35 + 0.25 * _pulse.value), blurRadius: 10 + 14 * _pulse.value, spreadRadius: 2 + 6 * _pulse.value),
              ],
            ),
            child: child,
          ),
          child: Icon(widget.recording ? Icons.stop_rounded : Icons.mic_rounded, color: TipoColors.white, size: 34),
        ),
      ),
    );
  }
}
