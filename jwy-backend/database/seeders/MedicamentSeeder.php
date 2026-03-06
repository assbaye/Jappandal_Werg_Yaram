<?php

namespace Database\Seeders;

use App\Models\Medicament;
use App\Models\Pharmacie;
use App\Models\StockMedicament;
use Illuminate\Database\Seeder;

class MedicamentSeeder extends Seeder
{
    public function run(): void
    {
        $medicaments = [
            [
                'nom_commercial'    => 'Paracétamol 500mg',
                'principe_actif'    => 'Paracétamol',
                'dosage'            => '500mg',
                'forme'             => 'comprime',
                'fabricant'         => 'SIPOA',
                'prix_unitaire'     => 150,
                'necessite_ordonnance' => false,
                'contre_indications' => ['insuffisance hépatique sévère'],
            ],
            [
                'nom_commercial'    => 'Amoxicilline 500mg',
                'principe_actif'    => 'Amoxicilline',
                'dosage'            => '500mg',
                'forme'             => 'gelule',
                'fabricant'         => 'LABOREX',
                'prix_unitaire'     => 450,
                'necessite_ordonnance' => true,
                'contre_indications' => ['allergie aux pénicillines'],
            ],
            [
                'nom_commercial'    => 'Ibuprofène 400mg',
                'principe_actif'    => 'Ibuprofène',
                'dosage'            => '400mg',
                'forme'             => 'comprime',
                'fabricant'         => 'SÉNÉPHARMA',
                'prix_unitaire'     => 250,
                'necessite_ordonnance' => false,
                'contre_indications' => ['ulcère gastroduodénal', 'insuffisance rénale'],
            ],
            [
                'nom_commercial'    => 'Chloroquine 100mg',
                'principe_actif'    => 'Chloroquine',
                'dosage'            => '100mg',
                'forme'             => 'comprime',
                'fabricant'         => 'SIPOA',
                'prix_unitaire'     => 100,
                'necessite_ordonnance' => true,
                'contre_indications' => ['rétinopathie'],
            ],
            [
                'nom_commercial'    => 'Métronidazole 250mg',
                'principe_actif'    => 'Métronidazole',
                'dosage'            => '250mg',
                'forme'             => 'comprime',
                'fabricant'         => 'LABOREX',
                'prix_unitaire'     => 200,
                'necessite_ordonnance' => true,
                'contre_indications' => ['premier trimestre grossesse'],
            ],
            [
                'nom_commercial'    => 'Soluté de réhydratation orale',
                'principe_actif'    => 'Glucose + Sels minéraux',
                'dosage'            => 'sachet 5g',
                'forme'             => 'autre',
                'fabricant'         => 'OMS/UNICEF',
                'prix_unitaire'     => 75,
                'necessite_ordonnance' => false,
                'contre_indications' => [],
            ],
            [
                'nom_commercial'    => 'Acide folique 5mg',
                'principe_actif'    => 'Acide folique',
                'dosage'            => '5mg',
                'forme'             => 'comprime',
                'fabricant'         => 'SÉNÉPHARMA',
                'prix_unitaire'     => 50,
                'necessite_ordonnance' => false,
                'contre_indications' => [],
            ],
            [
                'nom_commercial'    => 'Fer + Acide folique',
                'principe_actif'    => 'Sulfate ferreux + Acide folique',
                'dosage'            => '200mg/5mg',
                'forme'             => 'comprime',
                'fabricant'         => 'SIPOA',
                'prix_unitaire'     => 75,
                'necessite_ordonnance' => false,
                'contre_indications' => [],
            ],
        ];

        foreach ($medicaments as $data) {
            Medicament::firstOrCreate(
                ['nom_commercial' => $data['nom_commercial']],
                $data
            );
        }

        // Créer des stocks pour chaque pharmacie
        $pharmacies   = Pharmacie::all();
        $medicamentIds = Medicament::pluck('id');

        foreach ($pharmacies as $pharmacie) {
            foreach ($medicamentIds as $medicamentId) {
                $medicament = Medicament::find($medicamentId);

                StockMedicament::firstOrCreate(
                    [
                        'pharmacie_id'  => $pharmacie->id,
                        'medicament_id' => $medicamentId,
                    ],
                    [
                        'quantite_disponible' => rand(10, 500),
                        'quantite_minimale'   => 10,
                        'date_expiration'     => now()->addMonths(rand(6, 24)),
                        'prix_vente'          => $medicament->prix_unitaire * 1.3,
                        'emplacement_stock'   => 'Rayon ' . chr(rand(65, 69)),
                    ]
                );
            }
        }

        $this->command->info('8 médicaments créés avec stocks dans 3 pharmacies.');
    }
}
