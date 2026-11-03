import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
import '../../../core/graphql/queries/urgence_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../consultation/screens/consultation_detail_screen.dart' show DossierPatientSheet;

/// Alertes visibles par le médecin, rafraîchies toutes les 20 s.
final alertesUrgenceProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final timer = Timer(const Duration(seconds: 20), ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(alertesUrgenceQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['alertesUrgence'] as List<dynamic>?) ?? [];
});

String _depuis(String? d) {
  final date = dateServeurUtc(d);
  if (date == null) return '';
  final m = DateTime.now().difference(date).inMinutes;
  if (m < 1) return 'à l\'instant';
  if (m < 60) return 'il y a $m min';
  return 'il y a ${m ~/ 60} h ${m % 60} min';
}

// ─── Bandeau sur l'accueil médecin ────────────────────────────────────────────

class BandeauUrgences extends ConsumerWidget {
  const BandeauUrgences({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertes = ref.watch(alertesUrgenceProvider).valueOrNull ?? [];
    final actives = alertes.where((a) => a['statut'] == 'ACTIVE').length;
    final miennes = alertes.where((a) => a['statut'] == 'PRISE_EN_CHARGE').length;
    if (actives == 0 && miennes == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/medecin/urgences'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.siren, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    [
                      if (actives > 0) '$actives urgence(s) en attente',
                      if (miennes > 0) '$miennes prise(s) en charge par vous',
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(PhosphorIconsRegular.caretRight, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Écran ────────────────────────────────────────────────────────────────────

class UrgencesMedecinScreen extends ConsumerWidget {
  const UrgencesMedecinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertesUrgenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Urgences')),
      body: async.when(
        skipError: true, // un rafraîchissement raté garde l'affichage précédent
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(alertesUrgenceProvider),
            child: const Text('Impossible de charger les urgences — réessayer'),
          ),
        ),
        data: (alertes) => RefreshIndicator(
          onRefresh: () => ref.refresh(alertesUrgenceProvider.future),
          child: alertes.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Icon(PhosphorIconsRegular.shieldCheck, size: 64, color: AppTheme.inkMuted),
                  const SizedBox(height: 12),
                  Center(child: Text('Aucune urgence en cours', style: TextStyle(color: AppTheme.inkSoft))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alertes.length,
                  itemBuilder: (_, i) => _AlerteCard(alerte: alertes[i] as Map<String, dynamic>),
                ),
        ),
      ),
    );
  }
}

class _AlerteCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> alerte;
  const _AlerteCard({required this.alerte});

  @override
  ConsumerState<_AlerteCard> createState() => _AlerteCardState();
}

class _AlerteCardState extends ConsumerState<_AlerteCard> {
  bool _loading = false;

  Map<String, dynamic> get a => widget.alerte;

  Future<void> _action(String document, String succes) async {
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(
          MutationOptions(document: gql(document), variables: {'id': a['id']}),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.hasException
          ? (result.exception?.graphqlErrors.firstOrNull?.message ?? 'Une erreur est survenue')
          : succes),
      backgroundColor: result.hasException ? AppTheme.errorColor : AppTheme.successColor,
    ));
    ref.invalidate(alertesUrgenceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final statut = a['statut'] as String? ?? '';
    final patient = a['patient'] as Map<String, dynamic>? ?? {};
    final tel = patient['user']?['telephone'] as String?;
    final contact = patient['numero_urgence'] as String?;
    final allergies = (patient['allergies'] as List<dynamic>? ?? []).cast<String>();
    final active = statut == 'ACTIVE';
    final enCharge = statut == 'PRISE_EN_CHARGE';
    final terminee = !active && !enCharge;

    final (label, couleur) = switch (statut) {
      'ACTIVE' => ('En attente', AppTheme.errorColor),
      'PRISE_EN_CHARGE' => ('Prise en charge par vous', AppTheme.successColor),
      'CLOTUREE' => ('Clôturée', AppTheme.inkSoft),
      'ANNULEE' => ('Annulée par le patient', AppTheme.inkSoft),
      _ => (statut, AppTheme.inkMuted),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? AppTheme.errorColor : Colors.transparent, width: 2),
      ),
      child: Opacity(
        opacity: terminee ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsRegular.siren, color: couleur),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(a['type_urgence'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Text(_depuis(a['created_at'] as String?), style: TextStyle(color: AppTheme.inkSoft, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: couleur, fontSize: 12, fontWeight: FontWeight.w600)),
              const Divider(height: 20),
              Text(
                '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}'
                '${patient['age'] != null ? ' · ${patient['age']} ans' : ''}'
                '${patient['groupe_sanguin'] != null ? ' · ${groupeSanguinLabel(patient['groupe_sanguin'] as String?)}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (allergies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Allergies : ${allergies.join(', ')}',
                      style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                ),
              if (a['description'] != null && (a['description'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('« ${a['description']} »', style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
              if (!terminee) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(PhosphorIconsRegular.mapTrifold, size: 18),
                      label: const Text('Position'),
                      onPressed: () => ouvrirCarte(
                        (a['latitude'] as num).toDouble(),
                        (a['longitude'] as num).toDouble(),
                      ),
                    ),
                    if (tel != null)
                      ActionChip(
                        avatar: const Icon(PhosphorIconsRegular.phone, size: 18),
                        label: const Text('Patient'),
                        onPressed: () => appeler(context, tel),
                      ),
                    if (contact != null && contact.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(PhosphorIconsRegular.addressBook, size: 18),
                        label: const Text('Proche'),
                        onPressed: () => appeler(context, contact),
                      ),
                    if (enCharge)
                      ActionChip(
                        avatar: const Icon(PhosphorIconsRegular.folderUser, size: 18),
                        label: const Text('Dossier'),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => DossierPatientSheet(patientId: patient['id'] as String),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (active)
                  ElevatedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.shieldCheck),
                    label: const Text('Je prends en charge'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                    onPressed: () => _action(prendreEnChargeUrgenceMutation, 'Urgence prise en charge — le patient est prévenu'),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.checkCircle),
                    label: const Text('Clôturer l\'urgence'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _action(terminerAlerteUrgenceMutation, 'Urgence clôturée'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
