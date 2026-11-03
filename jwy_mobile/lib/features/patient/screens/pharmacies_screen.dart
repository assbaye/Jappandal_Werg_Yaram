import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';

// Coordonnées du centre de Dakar (fallback)
const double _defaultLat = 14.6928;
const double _defaultLng = -17.4467;

final locationProvider = FutureProvider<Position?>((ref) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    ).timeout(const Duration(seconds: 10));
  } catch (_) {
    return null;
  }
});

final pharmaciesProvider = FutureProvider.autoDispose
    .family<List<dynamic>, ({double latitude, double longitude})>((ref, coords) async {
  final client = ref.read(graphQLClientProvider);
  final result = await client.query(
    QueryOptions(
      document: gql(pharmaciesProchesQuery),
      variables: {
        'latitude': coords.latitude,
        'longitude': coords.longitude,
        'rayon': 15.0,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;
  return (result.data?['pharmaciesProches'] as List<dynamic>?) ?? [];
});

class PharmaciesScreen extends ConsumerWidget {
  const PharmaciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacies proches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Mes commandes',
            onPressed: () => context.push('/commandes'),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Actualiser la position',
            onPressed: () => ref.invalidate(locationProvider),
          ),
        ],
      ),
      body: locationAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Localisation en cours...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        // En cas d'erreur ou de position null → fallback Dakar
        error: (e, _) => _PharmaciesList(
          latitude: _defaultLat,
          longitude: _defaultLng,
          isApproximate: true,
          onRefresh: () => ref.invalidate(locationProvider),
        ),
        data: (position) => _PharmaciesList(
          latitude: position?.latitude ?? _defaultLat,
          longitude: position?.longitude ?? _defaultLng,
          isApproximate: position == null,
          onRefresh: () => ref.invalidate(locationProvider),
        ),
      ),
    );
  }
}

class _PharmaciesList extends ConsumerWidget {
  final double latitude;
  final double longitude;
  final bool isApproximate;
  final VoidCallback onRefresh;

  const _PharmaciesList({
    required this.latitude,
    required this.longitude,
    required this.isApproximate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coords = (latitude: latitude, longitude: longitude);
    final pharmaciesAsync = ref.watch(pharmaciesProvider(coords));

    return pharmaciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              const Text('Impossible de charger les pharmacies',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: () => ref.invalidate(pharmaciesProvider(coords)),
              ),
            ],
          ),
        ),
      ),
      data: (pharmacies) {
        if (pharmacies.isEmpty) {
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
                    child: const Icon(Icons.local_pharmacy_outlined, size: 40, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text('Aucune pharmacie trouvée',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Aucune pharmacie dans un rayon de 15 km',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                    onPressed: () => ref.invalidate(pharmaciesProvider(coords)),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Bannière localisation
            if (isApproximate)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, color: AppTheme.warningColor, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Localisation non disponible — Affichage autour de Dakar',
                        style: TextStyle(color: AppTheme.warningColor, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: onRefresh,
                      child: const Text('Activer',
                          style: TextStyle(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${pharmacies.length} pharmacie(s) dans un rayon de 15 km',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(pharmaciesProvider(coords));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pharmacies.length,
                  itemBuilder: (_, i) => _PharmacieCard(
                    pharmacie: pharmacies[i] as Map<String, dynamic>,
                    index: i,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PharmacieCard extends StatelessWidget {
  final Map<String, dynamic> pharmacie;
  final int index;
  const _PharmacieCard({required this.pharmacie, required this.index});

  String _formatDistance(dynamic dist) {
    if (dist == null) return '';
    final km = (dist as num).toDouble();
    return km < 1 ? '${(km * 1000).toInt()} m' : '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final livraison = pharmacie['livraison_disponible'] as bool? ?? false;
    final active = pharmacie['est_active'] as bool? ?? true;
    final distance = _formatDistance(pharmacie['distance']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_pharmacy,
                    color: active ? AppTheme.primary : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pharmacie['nom_pharmacie'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          if (!active)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Fermée',
                                  style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pharmacie['adresse'] as String? ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (distance.isNotEmpty) ...[
                  const Icon(Icons.near_me, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(distance,
                      style: const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 16),
                ],
                if (livraison) ...[
                  const Icon(Icons.delivery_dining, size: 14, color: AppTheme.successColor),
                  const SizedBox(width: 4),
                  const Text('Livraison',
                      style: TextStyle(color: AppTheme.successColor, fontSize: 12)),
                  const SizedBox(width: 16),
                ],
                if (pharmacie['telephone'] != null) ...[
                  const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(pharmacie['telephone'] as String,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
