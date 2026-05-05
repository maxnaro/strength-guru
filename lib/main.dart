import 'package:flutter/material.dart';
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
  late final Future<void> _seedFuture;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    _seedFuture = Seeder.seedIfEmpty(db);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'StrengthGuru',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      home: FutureBuilder(
        future: _seedFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _SplashScreen();
          }
          if (snap.hasError) {
            return Scaffold(
              body: Center(child: Text('Seed error: ${snap.error}')),
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
      body: Center(
        child: CircularProgressIndicator(color: p.accent),
      ),
    );
  }
}

class RootScaffold extends ConsumerWidget {
  const RootScaffold({super.key});

  static const _screens = [
    TodayScreen(),
    LogScreen(),
    MesoScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(tabIndexProvider);
    final p = pal(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: p.bg,
      body: IndexedStack(
        index: idx,
        children: _screens,
      ),
      bottomNavigationBar: SGTabBar(
        currentIndex: idx,
        onTabChanged: (i) =>
            ref.read(tabIndexProvider.notifier).state = i,
      ),
    );
  }
}
