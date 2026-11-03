import 'package:flutter/material.dart';
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
