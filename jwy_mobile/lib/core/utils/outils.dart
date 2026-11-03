import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart' show OperationException;
import 'package:url_launcher/url_launcher.dart';

/// Lance un appel téléphonique ; affiche un message si l'appareil ne peut pas appeler.
Future<void> appeler(BuildContext context, String numero) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: numero.replaceAll(' ', '')));
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossible d\'appeler le $numero depuis cet appareil')),
    );
  }
}

/// Ouvre une position dans l'application de cartes.
Future<void> ouvrirCarte(double latitude, double longitude) =>
    launchUrl(Uri.parse('https://maps.apple.com/?q=$latitude,$longitude'), mode: LaunchMode.externalApplication);

/// Horodatage généré par le serveur (created_at…) : stocké en UTC sans fuseau.
/// À ne pas utiliser pour les dates saisies par l'utilisateur (rendez-vous), stockées telles quelles.
DateTime? dateServeurUtc(String? d) =>
    d == null ? null : DateTime.tryParse(d.contains('Z') || d.contains('+') ? d : '${d.replaceFirst(' ', 'T')}Z')?.toLocal();

/// Groupes sanguins : nom de l'enum GraphQL (qui n'accepte pas « + ») → libellé affiché.
const groupesSanguins = {
  'A_POS': 'A+', 'A_NEG': 'A−', 'B_POS': 'B+', 'B_NEG': 'B−',
  'AB_POS': 'AB+', 'AB_NEG': 'AB−', 'O_POS': 'O+', 'O_NEG': 'O−',
};

/// « O_POS » → « O+ » ; renvoie la valeur telle quelle si elle est déjà lisible (ex. « O+ »).
String? groupeSanguinLabel(String? valeur) => valeur == null ? null : groupesSanguins[valeur] ?? valeur;

/// Message lisible pour l'utilisateur à partir d'une erreur de requête (jamais l'exception brute).
String messageErreur(Object? e) {
  if (e is OperationException) {
    if (e.linkException != null) return 'Connexion au serveur impossible. Vérifiez votre connexion et réessayez.';
    final message = e.graphqlErrors.firstOrNull?.message;
    if (message != null && message != 'Internal server error') return message;
  }
  return 'Une erreur est survenue. Réessayez.';
}
