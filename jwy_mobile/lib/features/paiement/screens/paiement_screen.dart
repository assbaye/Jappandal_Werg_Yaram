import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/paiement_queries.dart';
import '../../auth/providers/auth_provider.dart';

class PaiementScreen extends ConsumerStatefulWidget {
  final String consultationId;
  const PaiementScreen({super.key, required this.consultationId});

  @override
  ConsumerState<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends ConsumerState<PaiementScreen> {
  String _methodePaiement = 'ORANGE_MONEY';
  bool _isLoading = false;

  static const _methodes = [
    {
      'value': 'ORANGE_MONEY',
      'label': 'Orange Money',
      'icon': 'assets/icons/orange_money.png',
      'fallbackIcon': Icons.phone_android,
      'color': Color(0xFFFF6200),
      'description': 'Paiement via votre compte Orange Money',
    },
    {
      'value': 'WAVE',
      'label': 'Wave',
      'icon': 'assets/icons/wave.png',
      'fallbackIcon': Icons.waves,
      'color': Color(0xFF1BAAE1),
      'description': 'Paiement rapide avec Wave',
    },
    {
      'value': 'STRIPE',
      'label': 'Carte bancaire',
      'icon': 'assets/icons/card.png',
      'fallbackIcon': Icons.credit_card,
      'color': Color(0xFF6772E5),
      'description': 'Visa, Mastercard via Stripe',
    },
    {
      'value': 'CASH',
      'label': 'En espèces',
      'icon': 'assets/icons/cash.png',
      'fallbackIcon': Icons.payments,
      'color': Color(0xFF388E3C),
      'description': 'Paiement à la pharmacie ou à la clinique',
    },
  ];

  // Montant simulé — dans une vraie app, vient de la consultation
  static const double _montant = 5000;

  Future<void> _initierPaiement() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(graphQLClientProvider);
      final result = await client.mutate(
        MutationOptions(
          document: gql(initierPaiementMutation),
          variables: {
            'input': {
              'payable_type': 'consultation',
              'payable_id': widget.consultationId,
              'methode': _methodePaiement,
            },
          },
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        final msg = result.exception?.graphqlErrors.firstOrNull?.message ?? 'Erreur de paiement';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
        );
        return;
      }

      final data = result.data!['initierPaiement'] as Map<String, dynamic>;
      final paiementId = data['paiement_id'] as String?;
      final paymentUrl = data['payment_url'] as String?;        // PaiementMobileResponse
      final clientSecret = data['client_secret'] as String?;   // PaiementStripeResponse

      if (_methodePaiement == 'CASH') {
        // Paiement cash → confirmation directe
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement en espèces enregistré'), backgroundColor: AppTheme.successColor),
        );
        context.go('/consultations');
      } else if (paymentUrl != null) {
        // Orange Money / Wave → WebView
        context.push('/paiement/webview', extra: {
          'redirect_url': paymentUrl,
          'transaction_id': data['reference'] ?? paiementId ?? '',
        });
      } else if (clientSecret != null) {
        // Stripe → à implémenter avec flutter_stripe
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement Stripe en cours d\'intégration')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Paiement'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Récapitulatif
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Récapitulatif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Consultation vidéo'),
                      Text('${_montant.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Frais de service'),
                      Text('${(_montant * 0.02).toStringAsFixed(0)} FCFA',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${(_montant * 1.02).toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Méthode de paiement
          const Text('Choisir une méthode de paiement',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._methodes.map((m) => _MethodeCard(
            value: m['value'] as String,
            label: m['label'] as String,
            description: m['description'] as String,
            icon: m['fallbackIcon'] as IconData,
            color: m['color'] as Color,
            selected: _methodePaiement == m['value'],
            onTap: () => setState(() => _methodePaiement = m['value'] as String),
          )),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.lock),
            label: Text(_isLoading ? 'Traitement...' : 'Payer maintenant'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppTheme.primary,
            ),
            onPressed: _isLoading ? null : _initierPaiement,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text('Paiement sécurisé et chiffré', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodeCard extends StatelessWidget {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodeCard({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha:0.06) : Colors.white,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                  Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
