import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/rendez_vous_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';

final rendezVousProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(mesRendezVousQuery),
        variables: const {'first': 50, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['mesRendezVous']?['data'] as List<dynamic>?) ?? [];
});

/// Format attendu par le scalaire DateTime de Lighthouse.
String formatDateServeur(DateTime d) => DateFormat('yyyy-MM-dd HH:mm:ss').format(d);

/// Sélecteur date puis heure. Retourne null si l'utilisateur annule.
Future<DateTime?> choisirDateHeure(BuildContext context, {DateTime? initiale}) async {
  final maintenant = DateTime.now();
  final depart = initiale != null && initiale.isAfter(maintenant)
      ? initiale
      : maintenant.add(const Duration(days: 1));

  final date = await showDatePicker(
    context: context,
    initialDate: depart,
    firstDate: maintenant,
    lastDate: maintenant.add(const Duration(days: 180)),
    locale: const Locale('fr', 'FR'),
    helpText: 'Date du rendez-vous',
  );
  if (date == null || !context.mounted) return null;

  final heure = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: depart.hour < 8 || depart.hour > 18 ? 9 : depart.hour, minute: 0),
    helpText: 'Heure du rendez-vous',
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (heure == null) return null;

  final choisi = DateTime(date.year, date.month, date.day, heure.hour, heure.minute);
  if (choisi.isBefore(maintenant) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Choisissez une heure dans le futur')),
    );
    return null;
  }
  return choisi;
}

// ─── Écran liste ──────────────────────────────────────────────────────────────

class RendezVousScreen extends ConsumerWidget {
  const RendezVousScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMedecin = ref.watch(authProvider).user?['role'] == 'medecin';
    final async = ref.watch(rendezVousProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rendez-vous'),
          actions: const [NotificationBell()],
          bottom: const TabBar(
            tabs: [Tab(text: 'À venir'), Tab(text: 'Passés')],
          ),
        ),
        floatingActionButton: isMedecin
            ? null
            : FloatingActionButton.extended(
                icon: const Icon(PhosphorIconsRegular.plus),
                label: const Text('Prendre RDV'),
                onPressed: () async {
                  final ok = await context.push<bool>('/rendez-vous/nouveau');
                  if (ok == true) ref.invalidate(rendezVousProvider);
                },
              ),
        body: async.when(
          skipError: true, // un rafraîchissement raté garde l'affichage précédent
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Impossible de charger les rendez-vous'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(rendezVousProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
          data: (liste) {
            final maintenant = DateTime.now();
            DateTime dateDe(dynamic r) =>
                DateTime.tryParse(r['date_rendez_vous'] as String? ?? '') ?? maintenant;
            final aVenir = liste
                .where((r) => dateDe(r).isAfter(maintenant) && r['statut'] != 'ANNULE')
                .toList()
              ..sort((a, b) => dateDe(a).compareTo(dateDe(b)));
            final passes = liste.where((r) => !aVenir.contains(r)).toList()
              ..sort((a, b) => dateDe(b).compareTo(dateDe(a)));

            return TabBarView(
              children: [
                _Liste(
                  items: aVenir,
                  vide: isMedecin
                      ? 'Aucun rendez-vous à venir'
                      : 'Aucun rendez-vous à venir.\nTouchez « Prendre RDV » pour en demander un.',
                ),
                _Liste(items: passes, vide: 'Aucun rendez-vous passé ou annulé'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Liste extends ConsumerWidget {
  final List<dynamic> items;
  final String vide;
  const _Liste({required this.items, required this.vide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(rendezVousProvider.future),
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Icon(PhosphorIconsRegular.calendarCheck, size: 64, color: AppTheme.inkMuted),
                const SizedBox(height: 12),
                Text(vide, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.inkSoft)),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              itemBuilder: (_, i) => _RendezVousCard(rdv: items[i] as Map<String, dynamic>),
            ),
    );
  }
}

// ─── Carte rendez-vous ────────────────────────────────────────────────────────

class _RendezVousCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> rdv;
  const _RendezVousCard({required this.rdv});

  @override
  ConsumerState<_RendezVousCard> createState() => _RendezVousCardState();
}

class _RendezVousCardState extends ConsumerState<_RendezVousCard> {
  bool _loading = false;

  Map<String, dynamic> get rdv => widget.rdv;

  Future<void> _executer(String document, Map<String, dynamic> variables, String succes) async {
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(
          MutationOptions(document: gql(document), variables: variables),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    final msg = result.hasException
        ? (result.exception?.graphqlErrors.firstOrNull?.message ?? 'Une erreur est survenue')
        : succes;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: result.hasException ? AppTheme.errorColor : AppTheme.successColor,
    ));
    if (!result.hasException) ref.invalidate(rendezVousProvider);
  }

  Future<void> _repondre(bool accepter) async {
    String? motif;
    if (!accepter) {
      motif = await showDialog<String>(context: context, builder: (_) => const _MotifDialog());
      if (motif == null) return;
    }
    await _executer(
      repondreRendezVousMutation,
      {'id': rdv['id'], 'accepter': accepter, if (motif != null && motif.isNotEmpty) 'motif': motif},
      accepter ? 'Rendez-vous confirmé' : 'Rendez-vous refusé',
    );
  }

  Future<void> _reporter() async {
    final date = await choisirDateHeure(
      context,
      initiale: DateTime.tryParse(rdv['date_rendez_vous'] as String? ?? ''),
    );
    if (date == null) return;
    await _executer(
      reporterRendezVousMutation,
      {'id': rdv['id'], 'nouvelle_date': formatDateServeur(date)},
      'Rendez-vous déplacé — l\'autre partie est notifiée',
    );
  }

  Future<void> _annuler() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: const Text('L\'autre partie sera prévenue.'),
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
    if (ok == true) await _executer(annulerRendezVousMutation, {'id': rdv['id']}, 'Rendez-vous annulé');
  }

  @override
  Widget build(BuildContext context) {
    final isMedecin = ref.watch(authProvider).user?['role'] == 'medecin';
    final statut = rdv['statut'] as String? ?? '';
    final date = DateTime.tryParse(rdv['date_rendez_vous'] as String? ?? '');
    final aVenir = date != null && date.isAfter(DateTime.now());
    final autre = (isMedecin ? rdv['patient'] : rdv['medecin']) as Map<String, dynamic>?;
    final nom = isMedecin
        ? '${autre?['prenom'] ?? ''} ${autre?['nom'] ?? ''}'
        : 'Dr. ${autre?['prenom'] ?? ''} ${autre?['nom'] ?? ''}';

    final (statutLabel, statutColor) = switch (statut) {
      'EN_ATTENTE' => (isMedecin ? 'À confirmer' : 'En attente', AppTheme.warningColor),
      'CONFIRME' => ('Confirmé', AppTheme.successColor),
      'REPORTE' => ('Déplacé', AppTheme.secondary),
      'ANNULE' => ('Annulé', AppTheme.errorColor),
      'TERMINE' => ('Terminé', AppTheme.inkSoft),
      _ => (statut, AppTheme.inkMuted),
    };
    final estVideo = rdv['type_rendez_vous'] == 'VIDEO';
    final actif = aVenir && statut != 'ANNULE' && statut != 'TERMINE';
    // « Déplacé » = nouveau créneau proposé par le médecin lui-même : rien à confirmer
    final aConfirmer = isMedecin && statut == 'EN_ATTENTE';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pastille date
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(date == null ? '--' : DateFormat('dd').format(date),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      Text(date == null ? '' : DateFormat('MMM', 'fr_FR').format(date).toUpperCase(),
                          style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(estVideo ? PhosphorIconsRegular.videoCamera : PhosphorIconsRegular.hospital,
                              size: 14, color: AppTheme.inkSoft),
                          const SizedBox(width: 4),
                          Text(
                            '${date == null ? '' : DateFormat('EEEE à HH:mm', 'fr_FR').format(date)}'
                            ' · ${estVideo ? 'Vidéo' : 'Cabinet'}',
                            style: TextStyle(color: AppTheme.inkSoft, fontSize: 13),
                          ),
                        ],
                      ),
                      if (!isMedecin && autre?['specialite'] != null)
                        Text(autre!['specialite'] as String,
                            style: TextStyle(color: AppTheme.inkMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statutColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statutLabel,
                      style: TextStyle(color: statutColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (rdv['motif'] != null && (rdv['motif'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Motif : ${rdv['motif']}', style: const TextStyle(fontSize: 13)),
            ],
            if (actif) ...[
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
              else if (aConfirmer)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _repondre(false),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                        child: const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _repondre(true),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                        child: const Text('Confirmer'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(PhosphorIconsRegular.clock, size: 18),
                      label: const Text('Déplacer'),
                      onPressed: _reporter,
                    ),
                    TextButton.icon(
                      icon: const Icon(PhosphorIconsRegular.x, size: 18),
                      label: const Text('Annuler'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                      onPressed: _annuler,
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MotifDialog extends StatefulWidget {
  const _MotifDialog();

  @override
  State<_MotifDialog> createState() => _MotifDialogState();
}

class _MotifDialogState extends State<_MotifDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refuser le rendez-vous'),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          child: const Text('Refuser'),
        ),
      ],
    );
  }
}
