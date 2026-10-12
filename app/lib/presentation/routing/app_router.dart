import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../citizen/citizen.dart' deferred as citizen;
import '../ops/ops_page.dart';
import '../ops/sitrep_page.dart';
import '../widgets/brand.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: kIsWeb ? '/ops' : '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => CitizenDesk(
          child: CitizenTabs(location: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(path: '/', pageBuilder: (context, state) => _fade(state, _DeferredCitizen(builder: () => citizen.CitizenHomePage()))),
          GoRoute(path: '/report', pageBuilder: (context, state) => _slide(state, _DeferredCitizen(builder: () => citizen.ReportPage()))),
          GoRoute(path: '/mine', pageBuilder: (context, state) => _fade(state, _DeferredCitizen(builder: () => citizen.MyReportsPage()))),
          GoRoute(path: '/inbox', pageBuilder: (context, state) => _fade(state, _DeferredCitizen(builder: () => citizen.InboxPage()))),
          GoRoute(
            path: '/mine/:id',
            pageBuilder: (context, state) => _slide(
              state,
              _DeferredCitizen(builder: () => citizen.ReportStatusPage(reportId: state.pathParameters['id']!)),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/ops',
        builder: (context, state) => Theme(data: opsTheme(), child: const OpsPage()),
      ),
      GoRoute(
        path: '/ops/sitrep/:id',
        builder: (context, state) => SitrepPage(incidentId: state.pathParameters['id']!),
      ),
    ],
  );
}

/// Loads the citizen deferred library once, then builds the screen.
class _DeferredCitizen extends StatefulWidget {
  const _DeferredCitizen({required this.builder});
  final Widget Function() builder;

  @override
  State<_DeferredCitizen> createState() => _DeferredCitizenState();
}

class _DeferredCitizenState extends State<_DeferredCitizen> {
  static Future<void>? _library;

  @override
  void initState() {
    super.initState();
    _library ??= citizen.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _library,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Failed to load citizen app:\n${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: TipoColors.navyDeep,
            child: Center(child: CircularProgressIndicator(color: TipoColors.orange)),
          );
        }
        return widget.builder();
      },
    );
  }
}

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: Motion.base,
  transitionsBuilder: (context, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Motion.curve),
    child: child,
  ),
);

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: Motion.base,
  transitionsBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);

/// Bottom navigation for the three citizen destinations. Report and status
/// screens hide it so the flow stays focused.
class CitizenTabs extends StatelessWidget {
  const CitizenTabs({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = ['/', '/mine', '/inbox'];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexOf(location);
    if (index < 0) return child;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          context.go(_tabs[i]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda', tooltip: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Laporan', tooltip: 'My reports'),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Kotak masuk',
            tooltip: 'Alerts inbox',
          ),
        ],
      ),
    );
  }
}

/// On a wide web window the citizen app sits in a phone frame, next to a way
/// back to the posko console, so a judge can file a report without a phone.
class CitizenDesk extends StatelessWidget {
  const CitizenDesk({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    if (!wide) return child;
    return Material(
      color: TipoColors.navyDeep,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final phoneHeight = (constraints.maxHeight - 48).clamp(480.0, 860.0);
          final phoneWidth = phoneHeight * 0.46;
          return Row(
            children: [
              SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.xxl),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: (constraints.maxHeight - Space.xxl * 2).clamp(0.0, double.infinity)),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Wordmark(light: true),
                          const SizedBox(height: Space.xxl),
                          Text('Citizen app', style: displayStyle(size: 30, color: TipoColors.white)),
                          const SizedBox(height: Space.sm),
                          const Text(
                            'The Android app, running here so you can file a report without a phone. Reports land in the posko console in seconds.',
                            style: TextStyle(color: TipoColors.muted, height: 1.5),
                          ),
                          const SizedBox(height: Space.xl),
                          const Text(
                            'Read the signs. Act first.',
                            style: TextStyle(color: TipoColors.orangeSoft, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          const SizedBox(height: Space.xl),
                          FilledButton.icon(
                            onPressed: () => GoRouter.of(context).go('/ops'),
                            icon: const Icon(Icons.space_dashboard_rounded),
                            label: const Text('Open posko console'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: phoneWidth,
                    height: phoneHeight,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020A16),
                      borderRadius: BorderRadius.circular(44),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 20))],
                      border: Border.all(color: TipoColors.navyLine),
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(34), child: child),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
