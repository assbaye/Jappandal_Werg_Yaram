<?php

namespace Database\Seeders;

use App\Models\Medicament;
use App\Models\Pharmacie;
use App\Models\StockMedicament;
use Illuminate\Database\Seeder;

/**
 * Pharmacies partenaires de démonstration, sans compte pharmacien.
 *
 * Placées autour du barycentre des pharmacies existantes : elles suivent donc
 * la position choisie avec `php artisan jwy:position-demo` (Dakar ou ailleurs).
 */
class PharmaciesDemoSeeder extends Seeder
{
    /** [nom, quartier, est (km), nord (km), livraison] */
    private const PHARMACIES = [
        ['Pharmacie Teranga',        'Médina, Dakar',            -1.2,  0.8, true],
        ['Pharmacie du Baobab',      'Grand Yoff, Dakar',         2.1,  2.6, false],
        ['Pharmacie Keur Santé',     'Liberté 6, Dakar',          0.9,  1.7, true],
        ['Pharmacie de l\'Espoir',   'Parcelles Assainies, Dakar', 3.4, 4.1, true],
        ['Pharmacie Jamm',           'Ouakam, Dakar',            -3.0,  2.2, false],
        ['Pharmacie de la Corniche', 'Fann, Dakar',              -2.2, -0.6, true],
        ['Pharmacie Nafa',           'HLM Grand Médine, Dakar',   1.6, -1.1, false],
    ];

    public function run(): void
    {
        $existantes = Pharmacie::all();
        $lat0 = $existantes->isEmpty() ? 14.7209 : $existantes->avg(fn ($p) => (float) $p->latitude);
        $lng0 = $existantes->isEmpty() ? -17.4375 : $existantes->avg(fn ($p) => (float) $p->longitude);
        $kmParDegreLng = 111.32 * cos(deg2rad($lat0));

        $medicaments = Medicament::all();

        foreach (self::PHARMACIES as $i => [$nom, $quartier, $est, $nord, $livraison]) {
            $pharmacie = Pharmacie::firstOrCreate(
                ['nom_pharmacie' => $nom],
                [
                    'adresse'              => $quartier,
                    'telephone'            => sprintf('+22133%07d', 8100000 + $i * 1111),
                    'latitude'             => round($lat0 + $nord / 110.57, 7),
                    'longitude'            => round($lng0 + $est / $kmParDegreLng, 7),
                    'est_partenaire'       => true,
                    'est_active'           => true,
                    'livraison_disponible' => $livraison,
                    'taux_commission'      => 8.00,
                    'heures_ouverture'     => ['lun_sam' => ['08:30', '21:00'], 'dim' => ['10:00', '13:00']],
                ]
            );

            // Stock partiel : chaque pharmacie n'a pas tout le catalogue
            foreach ($medicaments->shuffle()->take(max(4, $medicaments->count() - 2)) as $m) {
                StockMedicament::firstOrCreate(
                    ['pharmacie_id' => $pharmacie->id, 'medicament_id' => $m->id],
                    [
                        'quantite_disponible' => rand(0, 6) === 0 ? rand(1, 8) : rand(20, 300),
                        'quantite_minimale'   => 10,
                        'date_expiration'     => now()->addMonths(rand(6, 24)),
                        'prix_vente'          => round($m->prix_unitaire * (1.2 + rand(0, 20) / 100), -1),
                        'emplacement_stock'   => 'Rayon ' . chr(rand(65, 69)),
                    ]
                );
            }
        }

        // Deux pharmacies de garde pour la semaine (jusqu'au même jour, 8 h, la semaine suivante)
        $finGarde = now(Pharmacie::FUSEAU)->addDays(7)->setTime(8, 0);
        Pharmacie::whereIn('nom_pharmacie', ['Pharmacie Keur Santé', 'Pharmacie Nafa'])
            ->update(['de_garde_jusqu_au' => $finGarde->utc()]);

        $this->command->info(count(self::PHARMACIES) . ' pharmacies partenaires de démo prêtes (2 de garde).');
    }
}
