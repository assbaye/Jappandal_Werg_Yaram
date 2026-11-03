import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/graphql/client.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
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
    final token = ref.watch(authProvider).token;

    return GraphQLProvider(
      client: graphQLClientNotifier(token),
      child: MaterialApp.router(
        title: 'JWY',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
