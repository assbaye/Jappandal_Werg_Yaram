import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/paiement_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../consultation/screens/consultation_detail_screen.dart' show consultationDetailProvider;
import '../../pharmacien/screens/commandes_pharmacien_screen.dart' show fcfa;

class PaiementScreen extends ConsumerStatefulWidget {
  final String consultationId;
  const PaiementScreen({super.key, required this.consultationId});

  @override
  ConsumerState<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends ConsumerState<PaiementScreen> {
  String _methode = 'WAVE';
  bool _isLoading = false;

  static const _methodes = [
    (value: 'WAVE', label: 'Wave', icon: PhosphorIconsRegular.waves, color: Color(0xFF1BAAE1),
        description: 'Paiement dans l\'application Wave'),
    (value: 'ORANGE_MONEY', label: 'Orange Money', icon: PhosphorIconsRegular.deviceMobile, color: Color(0xFFFF6200),
        description: 'Bientôt disponible'),
    (value: 'CASH', label: 'En espèces', icon: PhosphorIconsRegular.money, color: AppTheme.successColor,
        description: 'À régler auprès du médecin'),
  ];

  void _erreur(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
      );

  Future<void> _payer() async {
    setState(() => _isLoading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(initierPaiementMutation),
          // Le montant n'est pas envoyé : le serveur le calcule à partir de la consultation
          variables: {
            'input': {
              'payable_type': 'consultation',
              'payable_id': widget.consultationId,
              'methode': _methode,
            },
          },
        ));
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.hasException) {
      _erreur(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Paiement impossible');
      return;
    }

    final data = result.data!['initierPaiement'] as Map<String, dynamic>;
    final paiementId = data['paiement_id'] as String;
    final url = data['payment_url'] as String?;

    if (_methode == 'CASH') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Paiement en espèces enregistré : à régler lors de la consultation.'),
        backgroundColor: AppTheme.successColor,
      ));
      context.pop();
      return;
    }

    if (url == null) {
      _erreur('Lien de paiement indisponible.');
      return;
    }

    // Wave exige l'ouverture dans le navigateur ou son application, jamais dans une vue web intégrée
    final ouvert = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ouvert) {
      _erreur('Impossible d\'ouvrir Wave sur cet appareil.');
      return;
    }
    context.pushReplacement('/paiement/suivi/$paiementId');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(consultationDetailProvider(widget.consultationId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Paiement'),
      ),
      body: async.when(
        skipError: true, // un rafraîchissement raté garde l'affichage précédent
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Impossible de charger la consultation')),
        data: (c) {
          if (c == null) return const Center(child: Text('Consultation introuvable'));
          final montant = (c['cout_consultation'] as num?) ?? 0;
          final medecin = c['medecin'] as Map<String, dynamic>?;

          if (c['est_payee'] == true) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIconsFill.sealCheck, color: AppTheme.successColor, size: 56),
                SizedBox(height: 12),
                Text('Cette consultation est déjà payée.', style: TextStyle(fontSize: 16)),
              ]),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Récapitulatif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Text('Consultation avec Dr. ${medecin?['prenom'] ?? ''} ${medecin?['nom'] ?? ''}'),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Expanded(
                              child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          Text('${fcfa.format(montant)} FCFA',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Moyen de paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              for (final m in _methodes)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _methode == m.value ? m.color : Colors.transparent, width: 2),
                  ),
                  child: ListTile(
                    enabled: m.value != 'ORANGE_MONEY',
                    leading: CircleAvatar(
                      backgroundColor: m.color.withValues(alpha: 0.12),
                      child: Icon(m.icon, color: m.color),
                    ),
                    title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(m.description),
                    trailing: _methode == m.value ? Icon(PhosphorIconsFill.checkCircle, color: m.color) : null,
                    onTap: () => setState(() => _methode = m.value),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(PhosphorIconsRegular.lock),
                label: Text(_methode == 'CASH' ? 'Confirmer le paiement en espèces' : 'Payer ${fcfa.format(montant)} FCFA'),
                onPressed: _isLoading || montant <= 0 ? null : _payer,
              ),
              const SizedBox(height: 10),
              Text(
                'Le paiement n\'est validé qu\'après confirmation par Wave.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
              ),
            ],
          );
        },
      ),
    );
  }
}
