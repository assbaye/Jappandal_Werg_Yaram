import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
import '../../../core/graphql/queries/urgence_queries.dart';
import '../../auth/providers/auth_provider.dart';

/// Numéros d'urgence du Sénégal (+ 112, international).
const _numeros = [
  ('SAMU', '1515', PhosphorIconsRegular.hospital),
  ('Sapeurs-pompiers', '18', PhosphorIconsRegular.fire),
  ('Police', '17', PhosphorIconsRegular.policeCar),
  ('Urgence internationale', '112', PhosphorIconsRegular.globe),
];

const _typesUrgence = [
  'Malaise',
  'Douleur thoracique',
  'Difficulté à respirer',
  'Accident / blessure',
  'Saignement important',
  'Autre',
];

/// Alerte en cours du patient, rafraîchie toutes les 10 s pour suivre la prise en charge.
final _monAlerteProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(monAlerteUrgenceQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return result.data?['monAlerteUrgence'] as Map<String, dynamic>?;
});

class UrgenceScreen extends ConsumerWidget {
  const UrgenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_monAlerteProvider);
    // Pendant un rafraîchissement, la valeur précédente reste affichée (pas de clignotement)
    final alerte = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urgence'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (alerte != null)
            _AlerteEnCours(alerte: alerte)
          else if (async.isLoading && !async.hasValue)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            // En cas d'erreur réseau, le formulaire reste utilisable (et les numéros en dessous)
            const _FormulaireAlerte(),
          const SizedBox(height: 24),
          const _NumerosUrgence(),
        ],
      ),
    );
  }
}

// ─── Formulaire de déclenchement ──────────────────────────────────────────────

class _FormulaireAlerte extends ConsumerStatefulWidget {
  const _FormulaireAlerte();

  @override
  ConsumerState<_FormulaireAlerte> createState() => _FormulaireAlerteState();
}

class _FormulaireAlerteState extends ConsumerState<_FormulaireAlerte> {
  String _type = _typesUrgence.first;
  final _descriptionCtrl = TextEditingController();
  String? _etape; // texte de progression pendant l'envoi

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<Position?> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  void _erreur(String msg) {
    setState(() => _etape = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 6)),
    );
  }

  Future<void> _envoyer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(PhosphorIconsRegular.siren, color: AppTheme.errorColor, size: 40),
        title: const Text('Envoyer l\'alerte ?'),
        content: const Text(
          'Votre position et votre dossier seront transmis aux médecins disponibles.\n\n'
          'En cas de danger immédiat, appelez aussi le SAMU (1515).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _etape = 'Localisation en cours…');
    final position = await _position();
    if (!mounted) return;
    if (position == null) {
      _erreur('Position introuvable. Activez la localisation, ou appelez directement le SAMU (1515).');
      return;
    }

    setState(() => _etape = 'Envoi de l\'alerte…');
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(declencherAlerteUrgenceMutation),
          variables: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'type_urgence': _type,
            if (_descriptionCtrl.text.trim().isNotEmpty) 'description': _descriptionCtrl.text.trim(),
          },
        ));
    if (!mounted) return;
    if (result.hasException) {
      _erreur(result.exception?.graphqlErrors.firstOrNull?.message ??
          'Envoi impossible. Appelez directement le SAMU (1515).');
      return;
    }
    setState(() => _etape = null);
    ref.invalidate(_monAlerteProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Que se passe-t-il ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _typesUrgence)
              ChoiceChip(
                label: Text(t),
                selected: _type == t,
                selectedColor: AppTheme.errorColor.withValues(alpha: 0.15),
                onSelected: (_) => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionCtrl,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Précisions (facultatif)',
            hintText: 'Ex. : je suis seul(e), douleur depuis 10 minutes…',
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: ElevatedButton(
              onPressed: _etape == null ? _envoyer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 8,
                minimumSize: const Size(180, 180),
              ),
              child: _etape == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsRegular.siren, size: 64),
                        Text('ALERTER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _etape ?? 'Les médecins disponibles reçoivent votre position et votre dossier',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.inkSoft, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ─── Suivi de l'alerte en cours ───────────────────────────────────────────────

class _AlerteEnCours extends ConsumerStatefulWidget {
  final Map<String, dynamic> alerte;
  const _AlerteEnCours({required this.alerte});

  @override
  ConsumerState<_AlerteEnCours> createState() => _AlerteEnCoursState();
}

class _AlerteEnCoursState extends ConsumerState<_AlerteEnCours> {
  bool _loading = false;

  Future<void> _annuler() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler l\'alerte ?'),
        content: const Text('À faire uniquement si vous n\'avez plus besoin d\'aide.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(terminerAlerteUrgenceMutation),
          variables: {'id': widget.alerte['id']},
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Annulation impossible'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    ref.invalidate(_monAlerteProvider);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alerte;
    final medecin = a['medecin'] as Map<String, dynamic>?;
    final priseEnCharge = a['statut'] == 'PRISE_EN_CHARGE';
    final telMedecin = medecin?['user']?['telephone'] as String?;
    final couleur = priseEnCharge ? AppTheme.successColor : AppTheme.errorColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(priseEnCharge ? PhosphorIconsRegular.shieldCheck : PhosphorIconsRegular.broadcast, size: 56, color: couleur),
          const SizedBox(height: 12),
          Text(
            priseEnCharge ? 'Un médecin s\'occupe de vous' : 'Alerte envoyée',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: couleur),
          ),
          const SizedBox(height: 6),
          Text(
            priseEnCharge
                ? 'Dr. ${medecin?['prenom'] ?? ''} ${medecin?['nom'] ?? ''} a pris votre alerte en charge et va vous contacter.'
                : 'Les médecins disponibles ont été prévenus. Restez joignable.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text('${a['type_urgence']}', style: TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
          if (!priseEnCharge) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: AppTheme.errorColor),
            const SizedBox(height: 6),
            Text('En attente d\'un médecin…', style: TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
          ],
          if (priseEnCharge && telMedecin != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(PhosphorIconsRegular.phone),
              label: Text('Appeler Dr. ${medecin?['nom'] ?? ''}'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => appeler(context, telMedecin),
            ),
          ],
          const SizedBox(height: 12),
          _loading
              ? const CircularProgressIndicator()
              : TextButton(
                  onPressed: _annuler,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.inkSoft),
                  child: const Text('Je n\'ai plus besoin d\'aide — annuler l\'alerte'),
                ),
        ],
      ),
    );
  }
}

// ─── Numéros d'urgence ────────────────────────────────────────────────────────

class _NumerosUrgence extends ConsumerWidget {
  const _NumerosUrgence();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Appeler directement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final (nom, numero, icone) in _numeros)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                child: Icon(icone, color: AppTheme.errorColor),
              ),
              title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text(numero,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
              onTap: () => appeler(context, numero),
            ),
          ),
      ],
    );
  }
}
