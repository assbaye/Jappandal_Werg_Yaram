import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../../core/graphql/queries/medecin_queries.dart';
import '../../auth/providers/auth_provider.dart';

final consultationDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final client = ref.read(graphQLClientProvider);
  final result = await client.query(
    QueryOptions(
      document: gql(consultationDetailQuery),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;
  return result.data?['consultation'] as Map<String, dynamic>?;
});

final _dossierPatientProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, patientId) async {
  final client = ref.read(graphQLClientProvider);
  final result = await client.query(
    QueryOptions(
      document: gql(dossierMedicalPatientQuery),
      variables: {'patient_id': patientId},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;
  return result.data?['dossierMedicalPatient'] as Map<String, dynamic>?;
});

String _messageErreur(OperationException? e) =>
    e?.graphqlErrors.firstOrNull?.message ??
    (e?.linkException != null ? 'Impossible de joindre le serveur' : 'Une erreur est survenue');

String _groupeSanguinLabel(String? g) => switch (g) {
      'A_POS' => 'A+',
      'A_NEG' => 'A-',
      'B_POS' => 'B+',
      'B_NEG' => 'B-',
      'AB_POS' => 'AB+',
      'AB_NEG' => 'AB-',
      'O_POS' => 'O+',
      'O_NEG' => 'O-',
      _ => '—',
    };

class ConsultationDetailScreen extends ConsumerWidget {
  final String consultationId;
  const ConsultationDetailScreen({super.key, required this.consultationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(consultationDetailProvider(consultationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail consultation'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(consultationDetailProvider(consultationId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text('Impossible de charger la consultation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(e is OperationException ? _messageErreur(e) : e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(consultationDetailProvider(consultationId)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (consultation) {
          if (consultation == null) {
            return const Center(child: Text('Consultation introuvable'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(consultationDetailProvider(consultationId).future),
            child: _DetailBody(consultation: consultation),
          );
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Map<String, dynamic> consultation;
  const _DetailBody({required this.consultation});

  Color _statutColor(String s) => switch (s) {
        'EN_ATTENTE' => AppTheme.warningColor,
        'CONFIRMEE' => AppTheme.secondary,
        'EN_COURS' => AppTheme.primary,
        'TERMINEE' => Colors.grey.shade600,
        'ANNULEE' => AppTheme.errorColor,
        _ => Colors.grey,
      };

  String _statutLabel(String s) => switch (s) {
        'EN_ATTENTE' => 'En attente',
        'CONFIRMEE' => 'Confirmée',
        'EN_COURS' => 'En cours',
        'TERMINEE' => 'Terminée',
        'ANNULEE' => 'Annulée',
        _ => s,
      };

  String _typeLabel(String t) => switch (t) {
        'VIDEO' => 'Téléconsultation vidéo',
        'CHAT' => 'Chat médical',
        'PHYSIQUE' => 'Consultation physique',
        _ => t,
      };

  IconData _typeIcon(String t) => switch (t) {
        'VIDEO' => Icons.video_call,
        'CHAT' => Icons.chat_bubble_outline,
        'PHYSIQUE' => Icons.local_hospital_outlined,
        _ => Icons.medical_services_outlined,
      };

  String _formatDate(String? d) {
    if (d == null) return '—';
    try {
      return DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMedecin = ref.watch(authProvider).user?['role'] == 'medecin';
    final medecin = consultation['medecin'] as Map<String, dynamic>?;
    final patient = consultation['patient'] as Map<String, dynamic>?;
    final statut = consultation['statut'] as String? ?? '';
    final type = consultation['type_consultation'] as String? ?? '';
    final cout = (consultation['cout_consultation'] as num?)?.toInt() ?? 0;
    final prescriptions = consultation['prescriptions'] as List<dynamic>? ?? [];
    final statutColor = _statutColor(statut);
    final estActive = statut == 'CONFIRMEE' || statut == 'EN_COURS';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Statut + Type ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statutColor.withValues(alpha: 0.08),
              border: Border.all(color: statutColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statutColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(type), color: statutColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_typeLabel(type),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statutColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statutLabel(statut),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Infos rapides ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _formatDate(consultation['created_at'] as String?),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoChip(
                  icon: Icons.payments_outlined,
                  label: 'Coût',
                  value: '$cout FCFA',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Patient (vue médecin) ou Médecin (vue patient) ────────────────
          if (isMedecin)
            _PatientCard(patient: patient)
          else
            _MedecinCard(medecin: medecin),
          const SizedBox(height: 12),

          // ── Symptômes ─────────────────────────────────────────────────────
          if (consultation['symptomes'] != null) ...[
            _SectionCard(
              title: 'Symptômes décrits',
              icon: Icons.sick_outlined,
              child: Text(
                consultation['symptomes'] as String,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Diagnostic ────────────────────────────────────────────────────
          if (consultation['diagnostic'] != null) ...[
            _SectionCard(
              title: 'Diagnostic',
              icon: Icons.local_hospital_outlined,
              iconColor: AppTheme.secondary,
              child: Text(
                consultation['diagnostic'] as String,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Recommandations ───────────────────────────────────────────────
          if (consultation['recommandations'] != null) ...[
            _SectionCard(
              title: 'Recommandations',
              icon: Icons.assignment_outlined,
              iconColor: AppTheme.successColor,
              child: Text(
                consultation['recommandations'] as String,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Notes privées (médecin uniquement) ────────────────────────────
          if (isMedecin && consultation['notes_consultation'] != null) ...[
            _SectionCard(
              title: 'Notes (visibles par vous seul)',
              icon: Icons.sticky_note_2_outlined,
              iconColor: Colors.grey.shade700,
              child: Text(
                consultation['notes_consultation'] as String,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Ordonnances ───────────────────────────────────────────────────
          if (prescriptions.isNotEmpty) ...[
            _SectionCard(
              title: 'Ordonnance(s)',
              icon: Icons.medication_outlined,
              iconColor: AppTheme.warningColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < prescriptions.length; i++) ...[
                    _OrdonnanceItem(
                      numero: i + 1,
                      prescription: prescriptions[i] as Map<String, dynamic>,
                      peutCommander: !isMedecin,
                    ),
                    if (i < prescriptions.length - 1) const Divider(height: 24),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Action vidéo (patient et médecin) ─────────────────────────────
          if (type == 'VIDEO' && estActive) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.video_call),
                label: Text(isMedecin ? 'Démarrer la téléconsultation' : 'Rejoindre la téléconsultation'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () => context.push('/consultations/${consultation['id']}/video'),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions médecin ───────────────────────────────────────────────
          if (isMedecin) _MedecinActions(consultation: consultation),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Carte médecin (vue patient) ──────────────────────────────────────────────

class _MedecinCard extends StatelessWidget {
  final Map<String, dynamic>? medecin;
  const _MedecinCard({required this.medecin});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Médecin',
      icon: Icons.person_outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${medecin?['prenom'] ?? ''} ${medecin?['nom'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  medecin?['specialite'] as String? ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                if (medecin?['hopital_rattachement'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    medecin!['hopital_rattachement'] as String,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
                if (medecin?['est_certifie'] == true) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.verified, color: AppTheme.primary, size: 14),
                      SizedBox(width: 4),
                      Text('Médecin certifié',
                          style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte patient (vue médecin) ──────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic>? patient;
  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final age = patient?['age'];
    final genre = switch (patient?['genre']) {
      'M' || 'masculin' || 'homme' => 'Homme',
      'F' || 'feminin' || 'féminin' || 'femme' => 'Femme',
      final String g => g,
      _ => null,
    };
    final allergies = (patient?['allergies'] as List<dynamic>? ?? []).cast<String>();
    final infos = [
      if (age != null) '$age ans',
      if (genre != null) genre,
      if (patient?['groupe_sanguin'] != null)
        'Groupe ${_groupeSanguinLabel(patient!['groupe_sanguin'] as String?)}',
    ];

    return _SectionCard(
      title: 'Patient',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${patient?['prenom'] ?? ''} ${patient?['nom'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (infos.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(infos.join(' · '),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (allergies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Allergies : ${allergies.join(', ')}',
                      style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.folder_shared_outlined),
              label: const Text('Voir le dossier médical'),
              onPressed: patient?['id'] == null
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => DossierPatientSheet(patientId: patient!['id'] as String),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dossier médical (bottom sheet médecin) ───────────────────────────────────

class DossierPatientSheet extends ConsumerWidget {
  final String patientId;
  const DossierPatientSheet({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dossierPatientProvider(patientId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is OperationException ? _messageErreur(e) : e.toString(),
                textAlign: TextAlign.center),
          ),
        ),
        data: (dossier) {
          if (dossier == null) {
            return const Center(child: Text('Aucun dossier médical pour ce patient'));
          }
          List<String> liste(String k) => (dossier[k] as List<dynamic>? ?? []).cast<String>();
          String mesure(String k, String unite) {
            final v = dossier[k] as num?;
            return v == null ? '—' : '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} $unite';
          }

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              const Text('Dossier médical',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _InfoChip(icon: Icons.bloodtype_outlined, label: 'Groupe', value: _groupeSanguinLabel(dossier['groupe_sanguin'] as String?))),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoChip(icon: Icons.monitor_weight_outlined, label: 'Poids', value: mesure('poids', 'kg'))),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoChip(icon: Icons.height, label: 'Taille', value: mesure('taille', 'cm'))),
                ],
              ),
              if (dossier['imc'] != null) ...[
                const SizedBox(height: 8),
                Text('IMC : ${(dossier['imc'] as num).toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.grey[700])),
              ],
              const SizedBox(height: 12),
              _DossierLigne(titre: 'Antécédents médicaux', valeur: dossier['antecedents_medicaux'] as String?),
              _DossierLigne(titre: 'Allergies connues', valeur: liste('allergies_connues').join(', ')),
              _DossierLigne(titre: 'Traitements en cours', valeur: liste('medicaments_actuels').join(', ')),
              _DossierLigne(titre: 'Notes générales', valeur: dossier['notes_generales'] as String?),
            ],
          );
        },
      ),
    );
  }
}

class _DossierLigne extends StatelessWidget {
  final String titre;
  final String? valeur;
  const _DossierLigne({required this.titre, required this.valeur});

  @override
  Widget build(BuildContext context) {
    final vide = valeur == null || valeur!.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(vide ? 'Non renseigné' : valeur!,
              style: TextStyle(fontSize: 14, color: vide ? Colors.grey : null)),
        ],
      ),
    );
  }
}

// ─── Ordonnance détaillée ─────────────────────────────────────────────────────

class _OrdonnanceItem extends StatelessWidget {
  final int numero;
  final Map<String, dynamic> prescription;
  final bool peutCommander;
  const _OrdonnanceItem({required this.numero, required this.prescription, this.peutCommander = false});

  @override
  Widget build(BuildContext context) {
    final meds = prescription['medicaments_prescrits'] as List<dynamic>? ?? [];
    final instructions = prescription['instructions'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ordonnance $numero · valable ${prescription['validite_jours'] ?? 30} jours',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final m in meds.cast<Map<String, dynamic>>())
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.medication, size: 18, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m['medicament']?['nom_commercial'] ?? ''} × ${m['quantite']}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text('${m['posologie']} — pendant ${m['duree_traitement']} jours',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      if (m['instructions_speciales'] != null)
                        Text(m['instructions_speciales'] as String,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (instructions != null && instructions.isNotEmpty)
          Text('Instructions : $instructions',
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        if (peutCommander && meds.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Commander en pharmacie'),
              onPressed: () => context.push('/commandes/ordonnance', extra: prescription),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Actions médecin ──────────────────────────────────────────────────────────

class _MedecinActions extends ConsumerStatefulWidget {
  final Map<String, dynamic> consultation;
  const _MedecinActions({required this.consultation});

  @override
  ConsumerState<_MedecinActions> createState() => _MedecinActionsState();
}

class _MedecinActionsState extends ConsumerState<_MedecinActions> {
  bool _loading = false;

  String get _id => widget.consultation['id'] as String;

  void _snack(String msg, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: erreur ? AppTheme.errorColor : AppTheme.successColor,
    ));
  }

  Future<void> _repondre(bool accepter) async {
    String? motif;
    if (!accepter) {
      motif = await showDialog<String>(context: context, builder: (_) => const _RefusDialog());
      if (motif == null) return; // annulé
    }
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(repondreConsultationMutation),
          variables: {
            'consultation_id': _id,
            'accepter': accepter,
            if (motif != null && motif.isNotEmpty) 'motif': motif,
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      _snack(_messageErreur(result.exception), erreur: true);
      return;
    }
    _snack(accepter ? 'Consultation acceptée — le patient est notifié' : 'Demande refusée');
    ref.invalidate(consultationDetailProvider(_id));
  }

  Future<void> _terminer() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TerminerSheet(consultationId: _id),
    );
    if (ok == true && mounted) {
      _snack('Consultation terminée — le patient est notifié');
      ref.invalidate(consultationDetailProvider(_id));
    }
  }

  Future<void> _prescrire() async {
    final patientId = widget.consultation['patient']?['id'];
    final ok = await context.push<bool>('/consultations/$_id/ordonnance?patient=$patientId');
    if (ok == true && mounted) {
      _snack('Ordonnance envoyée au patient');
      ref.invalidate(consultationDetailProvider(_id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final statut = widget.consultation['statut'] as String? ?? '';

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (statut == 'EN_ATTENTE') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Refuser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _repondre(false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Accepter'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: () => _repondre(true),
            ),
          ),
        ],
      );
    }

    final estActive = statut == 'CONFIRMEE' || statut == 'EN_COURS';
    if (!estActive && statut != 'TERMINEE') return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.edit_note),
            label: const Text('Rédiger une ordonnance'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _prescrire,
          ),
        ),
        if (estActive) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.task_alt),
              label: const Text('Terminer la consultation'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: _terminer,
            ),
          ),
        ],
      ],
    );
  }
}

class _RefusDialog extends StatefulWidget {
  const _RefusDialog();

  @override
  State<_RefusDialog> createState() => _RefusDialogState();
}

class _RefusDialogState extends State<_RefusDialog> {
  final _motifCtrl = TextEditingController();

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refuser la demande'),
      content: TextField(
        controller: _motifCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Motif (facultatif)',
          hintText: 'Ex. : indisponible, orienter vers un spécialiste…',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, _motifCtrl.text.trim()),
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          child: const Text('Refuser'),
        ),
      ],
    );
  }
}

// ─── Formulaire de fin de consultation ────────────────────────────────────────

class _TerminerSheet extends ConsumerStatefulWidget {
  final String consultationId;
  const _TerminerSheet({required this.consultationId});

  @override
  ConsumerState<_TerminerSheet> createState() => _TerminerSheetState();
}

class _TerminerSheetState extends ConsumerState<_TerminerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosticCtrl = TextEditingController();
  final _recommandationsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _diagnosticCtrl.dispose();
    _recommandationsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(terminerConsultationMutation),
          variables: {
            'consultation_id': widget.consultationId,
            'diagnostic': _diagnosticCtrl.text.trim(),
            'recommandations': opt(_recommandationsCtrl),
            'notes': opt(_notesCtrl),
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_messageErreur(result.exception)),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Terminer la consultation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diagnosticCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Diagnostic *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Le diagnostic est obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recommandationsCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Recommandations au patient',
                  hintText: 'Repos, hydratation, examens à faire…',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes privées',
                  helperText: 'Non visibles par le patient',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _valider,
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Valider et notifier le patient'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets communs ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
