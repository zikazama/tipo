import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../domain/insights.dart';
import '../../domain/models.dart';

const _drillCenter = LatLng(-6.985, 107.628);

bool isSuspect(Incident i) => i.credibility < 40;

class IncidentMap extends StatefulWidget {
  const IncidentMap({super.key, required this.incidents, required this.selectedId, required this.onSelect, this.presence = const []});
  final List<Incident> incidents;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final List<GeoPoint> presence;

  @override
  State<IncidentMap> createState() => _IncidentMapState();
}

class _IncidentMapState extends State<IncidentMap> {
  final _controller = MapController();
  var _ready = false;

  @override
  void didUpdateWidget(covariant IncidentMap old) {
    super.didUpdateWidget(old);
    if (_ready && widget.selectedId != null && widget.selectedId != old.selectedId) {
      final match = widget.incidents.where((i) => i.id == widget.selectedId);
      if (match.isNotEmpty) {
        final zoom = math.max(_controller.camera.zoom, 13.2);
        _controller.move(LatLng(match.first.lat, match.first.lng), zoom);
      }
    }
  }

  void _zoom(double delta) {
    if (!_ready) return;
    _controller.move(_controller.camera.center, (_controller.camera.zoom + delta).clamp(9, 18));
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.incidents.where((i) => i.id == widget.selectedId).firstOrNull;
    // Draw low priority first so critical markers sit on top.
    final ordered = [...widget.incidents]..sort((a, b) => a.priorityScore.compareTo(b.priorityScore));
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _drillCenter,
            initialZoom: 12.8,
            backgroundColor: TipoColors.navyDeep,
            onMapReady: () => _ready = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'id.go.bpbd.tipo',
              tileBuilder: _navyTiles,
            ),
            if (selected != null && !isSuspect(selected))
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(selected.lat, selected.lng),
                    radius: nearbyRadiusM,
                    useRadiusInMeter: true,
                    color: TipoColors.orange.withValues(alpha: 0.08),
                    borderColor: TipoColors.orange.withValues(alpha: 0.7),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final p in widget.presence)
                  Marker(
                    point: LatLng(p.lat, p.lng),
                    width: 10,
                    height: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TipoColors.info.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: TipoColors.navyDeep, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final incident in ordered)
                  Marker(
                    point: LatLng(incident.lat, incident.lng),
                    width: 84,
                    height: 84,
                    child: _ClusterMarker(
                      incident: incident,
                      selected: incident.id == widget.selectedId,
                      onTap: () => widget.onSelect(incident.id),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              alignment: Alignment.bottomRight,
              backgroundColor: Color(0xCC071529),
              source: Text('OpenStreetMap', style: TextStyle(color: TipoColors.muted, fontSize: 11)),
            ),
          ],
        ),
        const Positioned(left: Space.md, bottom: Space.md, child: _Legend()),
        Positioned(
          right: Space.md,
          top: Space.md,
          child: Column(
            children: [
              _MapButton(icon: Icons.add_rounded, label: 'Zoom in', onTap: () => _zoom(1)),
              const SizedBox(height: Space.xs),
              _MapButton(icon: Icons.remove_rounded, label: 'Zoom out', onTap: () => _zoom(-1)),
              const SizedBox(height: Space.xs),
              _MapButton(
                icon: Icons.center_focus_strong_rounded,
                label: 'Recenter on Dayeuhkolot',
                onTap: () {
                  if (_ready) _controller.move(_drillCenter, 12.8);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dims the OSM tiles into the navy palette so markers carry the colour.
Widget _navyTiles(BuildContext context, Widget tile, TileImage image) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      -0.20, -0.45, -0.10, 0, 168, //
      -0.20, -0.45, -0.10, 0, 178,
      -0.15, -0.35, -0.08, 0, 196,
      0, 0, 0, 1, 0,
    ]),
    child: tile,
  );
}

class _ClusterMarker extends StatefulWidget {
  const _ClusterMarker({required this.incident, required this.selected, required this.onTap});
  final Incident incident;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ClusterMarker> createState() => _ClusterMarkerState();
}

class _ClusterMarkerState extends State<_ClusterMarker> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  bool get _pulsing => widget.incident.priorityBand == 'critical' && widget.incident.status == 'open' && !isSuspect(widget.incident);

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _ClusterMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (_pulsing && _pulse == null) {
      _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    } else if (!_pulsing && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.incident;
    final suspect = isSuspect(i);
    final color = suspect ? TipoColors.muted : bandColor(i.priorityBand);
    final count = i.reportIds.length;
    final size = 30.0 + math.min(count, 10) * 2.6 + (widget.selected ? 6 : 0);
    final pulse = _pulse;
    final core = AnimatedContainer(
      duration: Motion.base,
      curve: Motion.curve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: suspect ? TipoColors.navyRaised : color,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.selected ? TipoColors.white : (suspect ? TipoColors.criticalOnDark : TipoColors.navyDeep),
          width: widget.selected ? 3 : 2,
        ),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: widget.selected ? 16 : 8)],
      ),
      child: suspect
          ? const Icon(Icons.gpp_maybe_rounded, size: 18, color: TipoColors.criticalOnDark)
          : i.status == 'approved'
              ? const Icon(Icons.campaign_rounded, size: 18, color: TipoColors.navy)
              : Text('$count', style: const TextStyle(fontFamily: headingFont, color: TipoColors.navy, fontWeight: FontWeight.w800, fontSize: 14)),
    );
    return Semantics(
      button: true,
      label: '${i.title}, ${suspect ? 'unconfirmed' : i.priorityBand}, $count reports',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (pulse != null)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(pulse.value);
                    return Container(
                      width: size + 34 * t,
                      height: size + 34 * t,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.35 * (1 - t))),
                    );
                  },
                ),
              core,
            ],
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: TipoColors.navyPanel.withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm), side: const BorderSide(color: TipoColors.navyLine)),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: TipoColors.text, semanticLabel: label)),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: TipoColors.navyPanel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: TipoColors.navyLine),
      ),
      child: const Wrap(
        spacing: Space.md,
        runSpacing: Space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Dot(TipoColors.criticalOnDark, 'Critical'),
          _Dot(TipoColors.highOnDark, 'High'),
          _Dot(TipoColors.mediumOnDark, 'Medium'),
          _Dot(TipoColors.lowOnDark, 'Low'),
          _Dot(TipoColors.muted, 'Unconfirmed', ring: TipoColors.criticalOnDark),
          _Dot(TipoColors.info, 'Standby device', small: true),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label, {this.ring, this.small = false});
  final Color color;
  final String label;
  final Color? ring;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final d = small ? 7.0 : 10.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: d,
          height: d,
          decoration: BoxDecoration(color: ring == null ? color : TipoColors.navyRaised, shape: BoxShape.circle, border: ring == null ? null : Border.all(color: ring!, width: 2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: TipoColors.text)),
      ],
    );
  }
}
