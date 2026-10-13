import 'models.dart';

/// Place copy and pins for the citizen app, switched by the active ops drill.
class CitizenContext {
  const CitizenContext({
    required this.placeShort,
    required this.regionLabel,
    required this.greeting,
    required this.headlineId,
    required this.standbyTitle,
    required this.bmkgAreaKey,
    required this.lat,
    required this.lng,
    required this.hazardFocus,
    required this.places,
    required this.isFire,
  });

  final String placeShort;
  final String regionLabel;
  final String greeting;
  final String headlineId;
  final String standbyTitle;
  final String bmkgAreaKey;
  final double lat;
  final double lng;
  final String hazardFocus;
  final Map<String, (double, double)> places;
  final bool isFire;

  static const flood = CitizenContext(
    placeShort: 'Dayeuhkolot',
    regionLabel: 'Kab. Bandung',
    greeting: 'Halo, warga Dayeuhkolot',
    headlineId: 'Lihat tanda bahaya?\nLaporkan ke posko.',
    standbyTitle: 'Siaga di Dayeuhkolot',
    bmkgAreaKey: 'dayeuhkolot',
    lat: -6.9755,
    lng: 107.6250,
    hazardFocus: 'flood',
    places: {
      'Dayeuhkolot': (-6.9755, 107.6250),
      'Baleendah': (-7.0045, 107.6302),
      'Bojongsoang': (-6.9986, 107.6510),
    },
    isFire: false,
  );

  static const karhutla = CitizenContext(
    placeShort: 'Segati',
    regionLabel: 'Kab. Pelalawan',
    greeting: 'Halo, warga Segati',
    headlineId: 'Lihat asap atau api?\nLaporkan ke posko.',
    standbyTitle: 'Siaga di Segati, Pelalawan',
    bmkgAreaKey: 'segati',
    lat: 0.352,
    lng: 101.912,
    hazardFocus: 'fire',
    places: {
      'Segati': (0.352, 101.912),
      'Bunut': (0.278, 102.148),
      'Teluk Meranti': (0.156, 102.385),
    },
    isFire: true,
  );

  static CitizenContext fromScenario(ScenarioInfo? scenario) {
    if (scenario == null) return flood;
    final id = scenario.id.toLowerCase();
    final hazard = scenario.hazard.toLowerCase();
    if (hazard == 'fire' || id.contains('karhutla') || id.contains('pelalawan')) {
      return karhutla;
    }
    return flood;
  }
}
