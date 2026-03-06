<?php

namespace Database\Seeders;

use App\Models\Medecin;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class MedecinSeeder extends Seeder
{
    public function run(): void
    {
        $medecins = [
            [
                'user' => [
                    'email'     => 'dr.diallo@jwy.sn',
                    'password'  => Hash::make('Medecin@123'),
                    'telephone' => '+221771234567',
                    'role'      => 'medecin',
                    'est_actif' => true,
                ],
                'profil' => [
                    'nom'                   => 'Diallo',
                    'prenom'                => 'Ibrahima',
                    'numero_ordre'          => 'CM-SN-001234',
                    'specialite'            => 'Médecine générale',
                    'hopital_rattachement'  => 'Hôpital Principal de Dakar',
                    'tarif_consultation'    => 10000,
                    'disponible_maintenant' => true,
                    'est_certifie'          => true,
                    'annees_experience'     => 12,
                    'heures_disponibilite'  => [
                        'lun' => ['08:00', '17:00'],
                        'mar' => ['08:00', '17:00'],
                        'mer' => ['08:00', '13:00'],
                        'jeu' => ['08:00', '17:00'],
                        'ven' => ['08:00', '17:00'],
                    ],
                ],
            ],
            [
                'user' => [
                    'email'     => 'dr.ndiaye@jwy.sn',
                    'password'  => Hash::make('Medecin@123'),
                    'telephone' => '+221769876543',
                    'role'      => 'medecin',
                    'est_actif' => true,
                ],
                'profil' => [
                    'nom'                   => 'Ndiaye',
                    'prenom'                => 'Fatou',
                    'numero_ordre'          => 'CM-SN-002456',
                    'specialite'            => 'Pédiatrie',
                    'hopital_rattachement'  => 'Hôpital pour Enfants Albert Royer',
                    'tarif_consultation'    => 15000,
                    'disponible_maintenant' => true,
                    'est_certifie'          => true,
                    'annees_experience'     => 8,
                    'heures_disponibilite'  => [
                        'lun' => ['09:00', '16:00'],
                        'mar' => ['09:00', '16:00'],
                        'jeu' => ['09:00', '16:00'],
                        'ven' => ['09:00', '14:00'],
                    ],
                ],
            ],
            [
                'user' => [
                    'email'     => 'dr.fall@jwy.sn',
                    'password'  => Hash::make('Medecin@123'),
                    'telephone' => '+221785555555',
                    'role'      => 'medecin',
                    'est_actif' => true,
                ],
                'profil' => [
                    'nom'                   => 'Fall',
                    'prenom'                => 'Moussa',
                    'numero_ordre'          => 'CM-SN-003789',
                    'specialite'            => 'Cardiologie',
                    'hopital_rattachement'  => 'Clinique du Cap-Vert',
                    'tarif_consultation'    => 25000,
                    'disponible_maintenant' => false,
                    'est_certifie'          => true,
                    'annees_experience'     => 20,
                    'heures_disponibilite'  => [
                        'mar' => ['10:00', '18:00'],
                        'mer' => ['10:00', '18:00'],
                        'ven' => ['10:00', '16:00'],
                        'sam' => ['09:00', '13:00'],
                    ],
                ],
            ],
        ];

        foreach ($medecins as $data) {
            $user = User::firstOrCreate(
                ['email' => $data['user']['email']],
                $data['user']
            );
            $user->assignRole('medecin');

            Medecin::firstOrCreate(
                ['user_id' => $user->id],
                array_merge($data['profil'], ['user_id' => $user->id])
            );
        }

        $this->command->info('3 médecins créés.');
    }
}
