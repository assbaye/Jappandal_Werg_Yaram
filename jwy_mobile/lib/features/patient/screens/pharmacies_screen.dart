import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';

// Provider de géolocalisation
final locationProvider = FutureProvider<Position?>((ref) async {
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
  );
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
            icon: const Icon(Icons.refresh),
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
              SizedBox(height: 12),
              Text('Localisation en cours...'),
            ],
          ),
        ),
        error: (e, _) => _LocationErrorWidget(onRetry: () => ref.invalidate(locationProvider)),
        data: (position) {
          if (position == null) {
            return _LocationErrorWidget(onRetry: () => ref.invalidate(locationProvider));
          }
          return _PharmaciesList(
            latitude: position.latitude,
            longitude: position.longitude,
            ref: ref,
          );
        },
      ),
    );
  }
}

class _PharmaciesList extends StatelessWidget {
  final double latitude;
  final double longitude;
  final WidgetRef ref;

  const _PharmaciesList({
    required this.latitude,
    required this.longitude,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(pharmaciesProchesQuery),
        variables: {'latitude': latitude, 'longitude': longitude, 'rayon': 15.0},
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
                const Text('Impossible de charger les pharmacies'),
                TextButton(onPressed: () => refetch!(), child: const Text('Réessayer')),
              ],
            ),
          );
        }

        final pharmacies = (result.data?['pharmaciesProches'] as List<dynamic>?) ?? [];

        if (pharmacies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_pharmacy_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucune pharmacie dans un rayon de 15 km', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Info localisation
            Container(
              padding: const EdgeInsets.all(12),
              color: AppTheme.primary.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${pharmacies.length} pharmacie(s) trouvée(s) dans un rayon de 15 km',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pharmacies.length,
                itemBuilder: (_, i) => _PharmacieCard(
                  pharmacie: pharmacies[i] as Map<String, dynamic>,
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
  const _PharmacieCard({required this.pharmacie});

  String _formatDistance(dynamic dist) {
    if (dist == null) return '';
    final km = (dist as num).toDouble();
    return km < 1 ? '${(km * 1000).toInt()} m' : '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final livraison = pharmacie['livraison_disponible'] as bool? ?? false;
    final active = pharmacie['est_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: active ? AppTheme.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_pharmacy,
                    color: active ? AppTheme.primary : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pharmacie['nom_pharmacie'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        pharmacie['adresse'] as String? ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDistance(pharmacie['distance']),
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (livraison) ...[
                  const Icon(Icons.delivery_dining, size: 16, color: AppTheme.successColor),
                  const SizedBox(width: 4),
                  const Text('Livraison disponible', style: TextStyle(fontSize: 12, color: AppTheme.successColor)),
                  const SizedBox(width: 16),
                ],
                const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  pharmacie['telephone'] as String? ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (!active) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Fermée', style: TextStyle(color: Colors.red, fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _LocationErrorWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Localisation non disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Activez la localisation pour trouver les pharmacies proches de vous.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('Activer la localisation'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
