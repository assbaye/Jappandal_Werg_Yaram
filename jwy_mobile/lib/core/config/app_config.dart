class AppConfig {
  // Backend GraphQL URL
  // Android emulator: 10.0.2.2 pointe vers localhost de la machine hôte
  // iOS simulator: localhost
  static const String graphqlUrl = 'http://10.0.2.2:8001/graphql';
  static const String graphqlUrlIos = 'http://localhost:8001/graphql';
  // Appareil physique : flutter run --dart-define=API_URL=http://<IP_DU_MAC>:8001/graphql
  static const String graphqlUrlOverride = String.fromEnvironment('API_URL');

  // Couleurs JWY
  static const String primaryColorHex = '#1565C0'; // Bleu santé
  static const String secondaryColorHex = '#42A5F5'; // Bleu clair

  // Pagination
  static const int defaultPageSize = 10;
}
