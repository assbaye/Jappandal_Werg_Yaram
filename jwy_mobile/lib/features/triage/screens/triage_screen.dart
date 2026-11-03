import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
import '../../../core/graphql/queries/ia_queries.dart';
import '../../auth/providers/auth_provider.dart';

/// Présentation de chaque niveau d'urgence renvoyé par l'assistant.
(String, String, Color, IconData) _niveau(String? n) => switch (n) {
      'URGENCE_VITALE' => ('Urgence', 'Appelez les secours maintenant', AppTheme.errorColor, PhosphorIconsRegular.siren),
      'AUJOURDHUI' => ('À voir aujourd\'hui', 'Consultez un médecin dans la journée', AppTheme.warningColor, PhosphorIconsRegular.clock),
      'SOUS_48H' => ('Sous 48 heures', 'Consultez dans les deux prochains jours', AppTheme.primary, PhosphorIconsFill.calendarBlank),
      'CONSEIL' => ('Pas d\'urgence', 'Consultez si cela dure ou s\'aggrave', AppTheme.successColor, PhosphorIconsRegular.checkCircle),
      _ => ('Orientation', '', AppTheme.inkMuted, PhosphorIconsRegular.question),
    };

class TriageScreen extends ConsumerStatefulWidget {
  const TriageScreen({super.key});

  @override
  ConsumerState<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends ConsumerState<TriageScreen> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _resultat;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _erreur(OperationException e) {
    if (e.linkException != null) return 'Impossible de joindre le serveur.';
    final err = e.graphqlErrors.firstOrNull;
    final validation = err?.extensions?['validation'];
    if (validation is Map && validation.isNotEmpty) return (validation.values.first as List).first.toString();
    return err?.message ?? 'Analyse impossible.';
  }

  Future<void> _analyser() async {
    final texte = _ctrl.text.trim();
    if (texte.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décrivez vos symptômes en une ou deux phrases.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(analyserSymptomesMutation),
          variables: {'symptomes': texte},
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_erreur(result.exception!)),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 6),
      ));
      return;
    }
    setState(() => _resultat = result.data?['analyserSymptomes'] as Map<String, dynamic>?);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orientation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_resultat == null) ..._formulaire() else _Resultat(
            resultat: _resultat!,
            onRecommencer: () => setState(() {
              _resultat = null;
              _ctrl.clear();
            }),
          ),
          const SizedBox(height: 20),
          Text(
            'L\'assistant utilise une intelligence artificielle (Claude, d\'Anthropic). Il oriente mais ne remplace pas '
            'un médecin et ne pose pas de diagnostic. Votre nom et vos coordonnées ne lui sont pas transmis.',
            style: TextStyle(fontSize: 11, color: AppTheme.inkSoft),
          ),
        ],
      ),
    );
  }

  List<Widget> _formulaire() => [
        const Text('Que ressentez-vous ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        const Text(
          'Décrivez vos symptômes : nous évaluons l\'urgence et vous indiquons quel médecin consulter.',
          style: TextStyle(color: AppTheme.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_loading,
          decoration: const InputDecoration(
            hintText: 'Ex. : fièvre depuis 2 jours, maux de tête, frissons le soir. Pas de toux.',
            alignLabelWithHint: true,
          ),
        ),
        Text(
          'Précisez depuis quand, l\'intensité, et ce qui aggrave ou soulage.',
          style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(PhosphorIconsRegular.arrowRight),
          label: Text(_loading ? 'Analyse en cours…' : 'Être orienté'),
          onPressed: _loading ? null : _analyser,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(PhosphorIconsRegular.siren, color: AppTheme.errorColor),
          label: const Text('Urgence grave ? SOS', style: TextStyle(color: AppTheme.errorColor)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: AppTheme.errorColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => context.push('/urgence'),
        ),
      ];
}

class _Resultat extends StatelessWidget {
  final Map<String, dynamic> resultat;
  final VoidCallback onRecommencer;
  const _Resultat({required this.resultat, required this.onRecommencer});

  @override
  Widget build(BuildContext context) {
    final niveau = resultat['niveau_urgence'] as String?;
    final (titre, sousTitre, couleur, icone) = _niveau(niveau);
    final vitale = niveau == 'URGENCE_VITALE';
    final conseils = (resultat['conseils'] as List<dynamic>? ?? []).cast<String>();
    final alertes = (resultat['signes_alerte'] as List<dynamic>? ?? []).cast<String>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Niveau d'urgence ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: couleur.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(icone, color: couleur, size: 44),
              const SizedBox(height: 8),
              Text(titre, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: couleur)),
              Text(sousTitre, textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (vitale) ...[
          FilledButton.icon(
            icon: const Icon(PhosphorIconsRegular.phone),
            label: const Text('Appeler le SAMU (1515)'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor, minimumSize: const Size(double.infinity, 52)),
            onPressed: () => appeler(context, '1515'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(PhosphorIconsRegular.siren),
            label: const Text('Alerter un médecin (SOS)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.push('/urgence'),
          ),
          const SizedBox(height: 16),
        ],

        _Bloc(titre: 'Pourquoi', child: Text(resultat['explication'] as String? ?? '', style: const TextStyle(height: 1.5))),
        if (!vitale)
          _Bloc(
            titre: 'Médecin conseillé',
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.stethoscope, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${resultat['specialite_recommandee']} · '
                    '${resultat['type_consultation'] == 'PHYSIQUE' ? 'au cabinet' : 'en vidéo'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (conseils.isNotEmpty)
          _Bloc(
            titre: 'En attendant',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final c in conseils) Text('• $c', style: const TextStyle(height: 1.5))],
            ),
          ),
        if (alertes.isNotEmpty)
          _Bloc(
            titre: 'Appelez le 1515 si',
            couleur: AppTheme.errorColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final a in alertes) Text('• $a', style: const TextStyle(height: 1.5))],
            ),
          ),

        const SizedBox(height: 8),
        if (!vitale)
          ElevatedButton.icon(
            icon: const Icon(PhosphorIconsRegular.arrowRight),
            label: const Text('Demander une consultation'),
            onPressed: () => context.push('/consultations/nouvelle', extra: resultat),
          ),
        TextButton(onPressed: onRecommencer, child: const Text('Nouvelle analyse')),
      ],
    );
  }
}

class _Bloc extends StatelessWidget {
  final String titre;
  final Widget child;
  final Color? couleur;
  const _Bloc({required this.titre, required this.child, this.couleur});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre.toUpperCase(),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: couleur ?? AppTheme.inkSoft)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
