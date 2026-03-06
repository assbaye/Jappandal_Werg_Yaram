import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import 'package:intl/intl.dart';

class ConsultationsScreen extends ConsumerWidget {
  const ConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes consultations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/consultations/nouvelle'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle consultation'),
        backgroundColor: AppTheme.primary,
      ),
      body: Query(
        options: QueryOptions(
          document: gql(mesConsultationsQuery),
          variables: const {'first': 20, 'page': 1},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                  const SizedBox(height: 12),
                  Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Erreur de chargement'),
                  TextButton(onPressed: () => refetch!(), child: const Text('Réessayer')),
                ],
              ),
            );
          }

          final consultations = (result.data?['mesConsultations']?['data'] as List<dynamic>?) ?? [];

          if (consultations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Aucune consultation', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Demander une consultation'),
                    onPressed: () => context.push('/consultations/nouvelle'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => refetch!(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
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

  Color _statutColor(String statut) => switch (statut) {
        'en_attente' => AppTheme.warningColor,
        'confirmee' => AppTheme.secondary,
        'en_cours' => AppTheme.primary,
        'terminee' => Colors.grey,
        'annulee' => AppTheme.errorColor,
        _ => Colors.grey,
      };

  IconData _typeIcon(String type) => switch (type) {
        'video' => Icons.video_call,
        'chat' => Icons.chat,
        'physique' => Icons.local_hospital,
        _ => Icons.medical_services,
      };

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medecin = consultation['medecin'] as Map<String, dynamic>?;
    final medecinUser = medecin?['user'] as Map<String, dynamic>?;
    final statut = consultation['statut'] as String? ?? '';
    final type = consultation['type'] as String? ?? '';
    final teleconsult = consultation['teleconsultation'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(type), color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dr. ${medecinUser?['prenom'] ?? ''} ${medecinUser?['nom'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statutColor(statut).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statut.replaceAll('_', ' '),
                    style: TextStyle(color: _statutColor(statut), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(medecin?['specialite'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              _formatDate(consultation['created_at'] as String?),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (consultation['symptomes'] != null) ...[
              const SizedBox(height: 8),
              Text(
                consultation['symptomes'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            // Bouton rejoindre si vidéo en cours
            if (type == 'video' && statut == 'en_cours' && teleconsult != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.video_call),
                  label: const Text('Rejoindre la téléconsultation'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
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
    );
  }
}
