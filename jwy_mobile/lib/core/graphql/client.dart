import 'package:flutter/foundation.dart' show ValueNotifier, defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:graphql_flutter/graphql_flutter.dart';
import '../config/app_config.dart';

/// Construit un GraphQLClient avec AuthLink JWT.
/// [token] est optionnel — null pour les requêtes non authentifiées.
GraphQLClient buildGraphQLClient(String? token) {
  // Desktop (Windows/Linux/macOS) et iOS et Web → localhost
  // Android emulator → 10.0.2.2 (pointe vers l'hôte)
  final bool isAndroidEmulator = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final String url = AppConfig.graphqlUrlOverride.isNotEmpty
      ? AppConfig.graphqlUrlOverride
      : (isAndroidEmulator ? AppConfig.graphqlUrl : AppConfig.graphqlUrlIos);

  final authLink = AuthLink(
    getToken: () => token != null ? 'Bearer $token' : null,
  );

  final httpLink = HttpLink(url);

  final link = Link.from([authLink, RelanceLink(), httpLink]);

  return GraphQLClient(
    cache: GraphQLCache(store: InMemoryStore()),
    link: link,
    // 5 s par défaut : trop court sur les réseaux mobiles lents (et serveur de développement)
    queryRequestTimeout: const Duration(seconds: 30),
    defaultPolicies: DefaultPolicies(
      query: Policies(fetch: FetchPolicy.networkOnly),
      mutate: Policies(fetch: FetchPolicy.networkOnly),
    ),
  );
}

/// ValueNotifier pour exposer le client aux widgets via GraphQLProvider.
ValueNotifier<GraphQLClient> graphQLClientNotifier(String? token) {
  return ValueNotifier(buildGraphQLClient(token));
}

/// Relance une lecture qui a échoué pour une raison réseau (Wi-Fi instable,
/// serveur momentanément occupé). Les mutations ne sont jamais relancées :
/// une action (paiement, alerte…) ne doit pas risquer d'être envoyée deux fois.
class RelanceLink extends Link {
  static const _essaisMax = 3;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    final lecture = request.operation.getOperationType()?.name == 'query';

    for (var essai = 1;; essai++) {
      try {
        // await for (et non yield*) : yield* transmettrait l'erreur sans passer par le catch
        await for (final reponse in forward!(request)) {
          yield reponse;
        }
        return;
      } on ServerException catch (e) {
        // parsedResponse nul : pas de réponse du serveur (échec réseau), et non une erreur HTTP
        final reseau = e.parsedResponse == null;
        if (!lecture || !reseau || essai >= _essaisMax) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 700 * essai));
      }
    }
  }
}
