<?php

namespace Database\Seeders;

use App\Models\Pharmacie;
use App\Models\Pharmacien;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class PharmacieSeeder extends Seeder
{
    public function run(): void
    {
        $pharmacies = [
            [
                'user' => [
                    'email'     => 'pharmacien.plateau@jwy.sn',
                    'password'  => Hash::make('Pharma@123'),
                    'telephone' => '+221338213456',
                    'role'      => 'pharmacien',
                    'est_actif' => true,
                ],
                'pharmacien' => [
                    'nom'          => 'Sarr',
                    'prenom'       => 'Aminata',
                    'numero_ordre' => 'PH-SN-00112',
                ],
                'pharmacie' => [
                    'nom_pharmacie'        => 'Pharmacie du Plateau',
                    'adresse'              => 'Avenue Léopold Sédar Senghor, Plateau, Dakar',
                    'telephone'            => '+221338213456',
                    'latitude'             => 14.6960,
                    'longitude'            => -17.4399,
                    'est_partenaire'       => true,
                    'livraison_disponible' => true,
                    'taux_commission'      => 8.00,
                    'heures_ouverture'     => [
                        'lun_ven' => ['08:00', '20:00'],
                        'sam'     => ['08:00', '18:00'],
                        'dim'     => ['10:00', '14:00'],
                    ],
                ],
            ],
            [
                'user' => [
                    'email'     => 'pharmacien.mermoz@jwy.sn',
                    'password'  => Hash::make('Pharma@123'),
                    'telephone' => '+221338248789',
                    'role'      => 'pharmacien',
                    'est_actif' => true,
                ],
                'pharmacien' => [
                    'nom'          => 'Diop',
                    'prenom'       => 'Omar',
                    'numero_ordre' => 'PH-SN-00234',
                ],
                'pharmacie' => [
                    'nom_pharmacie'        => 'Pharmacie Mermoz',
                    'adresse'              => 'Rue 10, Mermoz, Dakar',
                    'telephone'            => '+221338248789',
                    'latitude'             => 14.7150,
                    'longitude'            => -17.4760,
                    'est_partenaire'       => true,
                    'livraison_disponible' => true,
                    'taux_commission'      => 6.00,
                    'heures_ouverture'     => [
                        'lun_ven' => ['07:30', '21:00'],
                        'sam'     => ['07:30', '20:00'],
                        'dim'     => ['09:00', '16:00'],
                    ],
                ],
            ],
            [
                'user' => [
                    'email'     => 'pharmacien.pikine@jwy.sn',
                    'password'  => Hash::make('Pharma@123'),
                    'telephone' => '+221338572222',
                    'role'      => 'pharmacien',
                    'est_actif' => true,
                ],
                'pharmacien' => [
                    'nom'          => 'Ba',
                    'prenom'       => 'Mariama',
                    'numero_ordre' => 'PH-SN-00389',
                ],
                'pharmacie' => [
                    'nom_pharmacie'        => 'Pharmacie Centrale Pikine',
                    'adresse'              => 'Marché de Pikine, Dakar',
                    'telephone'            => '+221338572222',
                    'latitude'             => 14.7517,
                    'longitude'            => -17.3967,
                    'est_partenaire'       => false,
                    'livraison_disponible' => false,
                    'taux_commission'      => 5.00,
                    'heures_ouverture'     => [
                        'lun_ven' => ['08:30', '19:30'],
                        'sam'     => ['08:30', '17:00'],
                    ],
                ],
            ],
        ];

        foreach ($pharmacies as $data) {
            $user = User::firstOrCreate(
                ['email' => $data['user']['email']],
                $data['user']
            );
            $user->assignRole('pharmacien');

            $pharmacien = Pharmacien::firstOrCreate(
                ['user_id' => $user->id],
                [
                    'user_id'      => $user->id,
                    'nom'          => $data['pharmacien']['nom'],
                    'prenom'       => $data['pharmacien']['prenom'],
                    'numero_ordre' => $data['pharmacien']['numero_ordre'],
                ]
            );

            $pharmacie = Pharmacie::firstOrCreate(
                ['nom_pharmacie' => $data['pharmacie']['nom_pharmacie']],
                $data['pharmacie']
            );

            if (!$pharmacie->pharmaciens()->where('pharmacien_id', $pharmacien->id)->exists()) {
                $pharmacie->pharmaciens()->attach($pharmacien->id, ['est_responsable' => true]);
            }
        }

        $this->command->info('3 pharmacies créées.');
    }
}
