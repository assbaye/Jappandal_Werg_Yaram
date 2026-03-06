class AppConfig {
  // Backend GraphQL URL
  // Android emulator: 10.0.2.2 pointe vers localhost de la machine hôte
  // iOS simulator: localhost
  static const String graphqlUrl = 'http://10.0.2.2:8000/graphql';
  static const String graphqlUrlIos = 'http://localhost:8000/graphql';

  // Agora.io — remplacer par votre App ID réel depuis console.agora.io
  static const String agoraAppId = 'VOTRE_AGORA_APP_ID';

  // Couleurs JWY
  static const String primaryColorHex = '#2E7D32'; // Vert santé
  static const String secondaryColorHex = '#1565C0'; // Bleu confiance

  // Pagination
  static const int defaultPageSize = 10;
}
