import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: JwyApp()));
}

class JwyApp extends ConsumerStatefulWidget {
  const JwyApp({super.key});

  @override
  ConsumerState<JwyApp> createState() => _JwyAppState();
}

class _JwyAppState extends ConsumerState<JwyApp> {
  @override
  void initState() {
    super.initState();
    // Restaurer la session JWT au démarrage
    Future.microtask(() => ref.read(authProvider.notifier).autoLogin());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'JWY Santé',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
