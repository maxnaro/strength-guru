import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shake/shake.dart';

import 'providers.dart';
import 'seed/seeder.dart';
import 'theme/tokens.dart';
import 'theme/sg_atoms.dart';
import 'screens/today_screen.dart';
import 'screens/log_screen.dart';
import 'screens/meso_screen.dart';
import 'widgets/about_sheet.dart';

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
    return MaterialApp(
      title: 'StrengthGuru',
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
              body: Center(child: Text('Seed error: ${snap.error}')),
            );
          }
          return const _ShakeAboutWrapper(child: RootScaffold());
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

class _ShakeAboutWrapper extends StatefulWidget {
  final Widget child;
  const _ShakeAboutWrapper({required this.child});

  @override
  State<_ShakeAboutWrapper> createState() => _ShakeAboutWrapperState();
}

class _ShakeAboutWrapperState extends State<_ShakeAboutWrapper> {
  ShakeDetector? _detector;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _detector = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        debugPrint('Shake detected!');
        if (_isShowing) {
          Navigator.of(context).pop();
        } else {
          _show();
        }
      },
      shakeThresholdGravity: 1.5,
    );
  }

  Future<void> _show() async {
    if (!mounted || _isShowing) return;
    _isShowing = true;
    await showSGSheet(
      context,
      child: const AboutSheet(),
    );
    _isShowing = false;
  }

  @override
  void dispose() {
    _detector?.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
