import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
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

enum _Filtre { toutes, deGarde, ouvertes }

String _formatDistance(num? km) {
  if (km == null) return '';
  return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}

class PharmaciesScreen extends ConsumerWidget {
  const PharmaciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacies'),
        actions: [
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

class _PharmaciesList extends ConsumerStatefulWidget {
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
  ConsumerState<_PharmaciesList> createState() => _PharmaciesListState();
}

class _PharmaciesListState extends ConsumerState<_PharmaciesList> {
  _Filtre _filtre = _Filtre.toutes;

  @override
  Widget build(BuildContext context) {
    final coords = (latitude: widget.latitude, longitude: widget.longitude);
    final async = ref.watch(pharmaciesProvider(coords));
    final toutes = (async.valueOrNull ?? []).cast<Map<String, dynamic>>();
    final deGarde = toutes.where((p) => p['est_de_garde'] == true).toList();
    final ouvertes = toutes.where((p) => p['est_ouverte'] == true).toList();
    final liste = switch (_filtre) {
      _Filtre.toutes => toutes,
      _Filtre.deGarde => deGarde,
      _Filtre.ouvertes => ouvertes,
    };

    return RefreshIndicator(
      onRefresh: () => ref.refresh(pharmaciesProvider(coords).future),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (widget.isApproximate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.location_off, color: AppTheme.warningColor, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Localisation non disponible — affichage autour de Dakar',
                        style: TextStyle(color: AppTheme.warningColor, fontSize: 12)),
                  ),
                  GestureDetector(
                    onTap: widget.onRefresh,
                    child: const Text('Activer',
                        style: TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // ── Raccourcis commande ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Raccourci(
                    icon: Icons.description_outlined,
                    label: 'Commander une ordonnance',
                    onTap: () => context.push('/ordonnances'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Raccourci(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Mes commandes',
                    onTap: () => context.push('/commandes'),
                  ),
                ),
              ],
            ),
          ),

          // ── Pharmacie de garde la plus proche ───────────────────────────
          if (deGarde.isNotEmpty && _filtre == _Filtre.toutes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _GardeBandeau(pharmacie: deGarde.first, nombre: deGarde.length),
            ),

          // ── Filtres ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Toutes (${toutes.length})'),
                  selected: _filtre == _Filtre.toutes,
                  onSelected: (_) => setState(() => _filtre = _Filtre.toutes),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.nightlight_round, size: 16),
                  label: Text('De garde (${deGarde.length})'),
                  selected: _filtre == _Filtre.deGarde,
                  onSelected: (_) => setState(() => _filtre = _Filtre.deGarde),
                ),
                ChoiceChip(
                  label: Text('Ouvertes (${ouvertes.length})'),
                  selected: _filtre == _Filtre.ouvertes,
                  onSelected: (_) => setState(() => _filtre = _Filtre.ouvertes),
                ),
              ],
            ),
          ),

          ...async.when(
            loading: () => [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))],
            error: (_, __) => [
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(pharmaciesProvider(coords)),
                  child: const Text('Impossible de charger les pharmacies — réessayer'),
                ),
              ),
            ],
            data: (_) => liste.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        switch (_filtre) {
                          _Filtre.deGarde => 'Aucune pharmacie de garde déclarée dans un rayon de 15 km.',
                          _Filtre.ouvertes => 'Aucune pharmacie ouverte en ce moment dans un rayon de 15 km.',
                          _Filtre.toutes => 'Aucune pharmacie dans un rayon de 15 km.',
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ]
                : [for (final p in liste) _PharmacieCard(pharmacie: p)],
          ),
        ],
      ),
    );
  }
}

class _Raccourci extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Raccourci({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mise en avant de la pharmacie de garde la plus proche (la liste est triée par distance).
class _GardeBandeau extends StatelessWidget {
  final Map<String, dynamic> pharmacie;
  final int nombre;
  const _GardeBandeau({required this.pharmacie, required this.nombre});

  @override
  Widget build(BuildContext context) {
    final tel = pharmacie['telephone'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                nombre > 1 ? 'Pharmacie de garde la plus proche' : 'Pharmacie de garde',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(pharmacie['nom_pharmacie'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          Text(
            '${_formatDistance(pharmacie['distance'] as num?)} · ${pharmacie['statut_ouverture'] ?? ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (tel != null)
                _BoutonClair(icon: Icons.call, label: 'Appeler', onTap: () => appeler(context, tel)),
              if (tel != null) const SizedBox(width: 8),
              _BoutonClair(
                icon: Icons.directions,
                label: 'Itinéraire',
                onTap: () => ouvrirCarte(
                  (pharmacie['latitude'] as num?)?.toDouble() ?? 0,
                  (pharmacie['longitude'] as num?)?.toDouble() ?? 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoutonClair extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BoutonClair({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          minimumSize: const Size(0, 38),
        ),
        onPressed: onTap,
      );
}

class _PharmacieCard extends StatelessWidget {
  final Map<String, dynamic> pharmacie;
  const _PharmacieCard({required this.pharmacie});

  @override
  Widget build(BuildContext context) {
    final livraison = pharmacie['livraison_disponible'] as bool? ?? false;
    final deGarde = pharmacie['est_de_garde'] == true;
    final ouverte = pharmacie['est_ouverte'] == true;
    final couleurStatut = deGarde
        ? const Color(0xFF0D47A1)
        : ouverte
            ? AppTheme.successColor
            : AppTheme.errorColor;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pharmacies/${pharmacie['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: couleurStatut.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(deGarde ? Icons.nightlight_round : Icons.local_pharmacy, color: couleurStatut),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pharmacie['nom_pharmacie'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(pharmacie['statut_ouverture'] as String? ?? '',
                        style: TextStyle(color: couleurStatut, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(_formatDistance(pharmacie['distance'] as num?),
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(pharmacie['adresse'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ),
                      ],
                    ),
                    if (livraison)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Row(children: [
                          Icon(Icons.delivery_dining, size: 14, color: AppTheme.successColor),
                          SizedBox(width: 4),
                          Text('Livraison', style: TextStyle(color: AppTheme.successColor, fontSize: 12)),
                        ]),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
