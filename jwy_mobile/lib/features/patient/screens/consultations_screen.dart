import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:intl/intl.dart';

final _consultationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.read(graphQLClientProvider);
  final result = await client.query(
    QueryOptions(
      document: gql(mesConsultationsQuery),
      variables: const {'first': 20, 'page': 1},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;
  return (result.data?['mesConsultations']?['data'] as List<dynamic>?) ?? [];
});

class ConsultationsScreen extends ConsumerWidget {
  const ConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(_consultationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes consultations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/consultations/nouvelle'),
        icon: const Icon(PhosphorIconsRegular.plus),
        label: const Text('Nouvelle'),
        backgroundColor: AppTheme.primary,
      ),
      body: consultationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsRegular.warningCircle, size: 56, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                const Text('Impossible de charger les consultations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(messageErreur(e),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                  label: const Text('Réessayer'),
                  onPressed: () => ref.invalidate(_consultationsProvider),
                ),
              ],
            ),
          ),
        ),
        data: (consultations) {
          if (consultations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(PhosphorIconsRegular.stethoscope, size: 40, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text('Aucune consultation',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Demandez votre première consultation médicale',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.inkSoft)),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('Demander une consultation'),
                      onPressed: () => context.push('/consultations/nouvelle'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_consultationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: consultations.length,
              itemBuilder: (_, i) => _ConsultationCard(
                consultation: consultations[i] as Map<String, dynamic>,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final Map<String, dynamic> consultation;
  const _ConsultationCard({required this.consultation});

  Color _statutColor(String s) => switch (s) {
        'EN_ATTENTE' => AppTheme.warningColor,
        'CONFIRMEE' => AppTheme.secondary,
        'EN_COURS' => AppTheme.primary,
        'TERMINEE' => AppTheme.inkSoft,
        'ANNULEE' => AppTheme.errorColor,
        _ => AppTheme.inkMuted,
      };

  String _statutLabel(String s) => switch (s) {
        'EN_ATTENTE' => 'En attente',
        'CONFIRMEE' => 'Confirmée',
        'EN_COURS' => 'En cours',
        'TERMINEE' => 'Terminée',
        'ANNULEE' => 'Annulée',
        _ => s,
      };

  IconData _typeIcon(String t) => switch (t) {
        'VIDEO' => PhosphorIconsRegular.videoCamera,
        'CHAT' => PhosphorIconsRegular.chatCircle,
        'PHYSIQUE' => PhosphorIconsRegular.hospital,
        _ => PhosphorIconsRegular.stethoscope,
      };

  String _typeLabel(String t) => switch (t) {
        'VIDEO' => 'Téléconsultation',
        'CHAT' => 'Chat médical',
        'PHYSIQUE' => 'Physique',
        _ => t,
      };

  String _formatDate(String? d) {
    if (d == null) return '';
    try {
      return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medecin = consultation['medecin'] as Map<String, dynamic>?;
    final statut = consultation['statut'] as String? ?? '';
    final type = consultation['type_consultation'] as String? ?? '';
    final teleconsult = consultation['teleconsultation'] as Map<String, dynamic>?;
    final color = _statutColor(statut);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/consultations/${consultation['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_typeIcon(type), color: color, size: 22),
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
                        Text(
                          medecin?['specialite'] as String? ?? '',
                          style: TextStyle(color: AppTheme.inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsRegular.caretRight, color: AppTheme.inkMuted),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statutLabel(statut),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _typeLabel(type),
                      style: TextStyle(color: AppTheme.inkSoft, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(consultation['created_at'] as String?),
                    style: TextStyle(color: AppTheme.inkMuted, fontSize: 11),
                  ),
                ],
              ),
              if (consultation['symptomes'] != null) ...[
                const SizedBox(height: 10),
                Text(
                  consultation['symptomes'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppTheme.inkSoft),
                ),
              ],
              if (type == 'VIDEO' && statut == 'EN_COURS' && teleconsult != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.videoCamera, size: 18),
                    label: const Text('Rejoindre la téléconsultation'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: () => context.push(
                      '/consultations/${consultation['id']}/video',
                      extra: teleconsult,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
