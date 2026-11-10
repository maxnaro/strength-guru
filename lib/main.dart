import 'dart:async';
import 'package:flutter/material.dart';
import 'platform/lifecycle.dart';
import 'services/llm_service.dart';
import 'widgets/sync_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'seed/seeder.dart';
import 'theme/tokens.dart';
import 'theme/sg_atoms.dart';
import 'screens/today_screen.dart';
import 'screens/log_screen.dart';
import 'screens/meso_screen.dart';

void main() {
  runApp(const ProviderScope(child: StrengthGuruApp()));
}

class StrengthGuruApp extends ConsumerStatefulWidget {
  const StrengthGuruApp({super.key});
  @override
  ConsumerState<StrengthGuruApp> createState() => _StrengthGuruAppState();
}

class _StrengthGuruAppState extends ConsumerState<StrengthGuruApp> {
  late Future<void> _seedFuture;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<void>? _syncEvents;
  int _dataVersion = -1;

  @override
  void dispose() {
    _syncEvents?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    LlmService.database = db;
    final sync = ref.read(syncClientProvider);
    _seedFuture = sync == null ? Seeder.seedIfEmpty(db) : sync.initialize();
    if (sync != null) {
      sync.onError = (error) => messenger.currentState?.showSnackBar(
        SnackBar(content: Text('$error')),
      );
      _syncEvents = sync.events.stream.listen((_) {
        if (sync.dataVersion == _dataVersion) return;
        _dataVersion = sync.dataVersion;
        ref.invalidate(allExercisesProvider);
        ref.invalidate(dayPlanProvider);
        ref.invalidate(dayGroupProvider);
        ref.invalidate(programDayExercisesProvider);
        ref.invalidate(sessionLogProvider);
        ref.invalidate(weekTargetsProvider);
        ref.invalidate(mesoSessionLogsProvider);
      });
    }
    requestPersistentStorage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrengthGuru',
      scaffoldMessengerKey: messenger,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: FutureBuilder(
        future: _seedFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _SplashScreen();
          }
          if (snap.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Could not open training data: ${snap.error}'),
                    TextButton(
                      onPressed: () => setState(() {
                        final sync = ref.read(syncClientProvider);
                        _seedFuture = sync == null
                            ? Seeder.seedIfEmpty(ref.read(dbProvider))
                            : sync.initialize();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const RootScaffold();
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(child: CircularProgressIndicator(color: p.accent)),
    );
  }
}

class RootScaffold extends ConsumerWidget {
  const RootScaffold({super.key});

  static const _screens = [TodayScreen(), LogScreen(), MesoScreen()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(tabIndexProvider);
    final p = pal(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SyncStatus(),
            Expanded(child: _LazyTabs(index: idx)),
          ],
        ),
      ),
      bottomNavigationBar: SGTabBar(
        currentIndex: idx,
        onTabChanged: (i) => ref.read(tabIndexProvider.notifier).state = i,
      ),
    );
  }
}

class _LazyTabs extends StatefulWidget {
  final int index;
  const _LazyTabs({required this.index});
  @override
  State<_LazyTabs> createState() => _LazyTabsState();
}

class _LazyTabsState extends State<_LazyTabs> {
  final visited = <int>{};
  @override
  Widget build(BuildContext context) {
    visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < 3; i++)
          visited.contains(i)
              ? RootScaffold._screens[i]
              : const SizedBox.shrink(),
      ],
    );
  }
}
