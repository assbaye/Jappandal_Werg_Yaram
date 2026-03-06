import 'package:flutter/foundation.dart' show ValueNotifier, defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:graphql_flutter/graphql_flutter.dart';
import '../config/app_config.dart';

/// Construit un GraphQLClient avec AuthLink JWT.
/// [token] est optionnel — null pour les requêtes non authentifiées.
GraphQLClient buildGraphQLClient(String? token) {
  // Desktop (Windows/Linux/macOS) et iOS et Web → localhost
  // Android emulator → 10.0.2.2 (pointe vers l'hôte)
  final bool isAndroidEmulator = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final String url = isAndroidEmulator ? AppConfig.graphqlUrl : AppConfig.graphqlUrlIos;

  final authLink = AuthLink(
    getToken: () => token != null ? 'Bearer $token' : null,
  );

  final httpLink = HttpLink(url);

  final link = authLink.concat(httpLink);

  return GraphQLClient(
    cache: GraphQLCache(store: InMemoryStore()),
    link: link,
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
