<?php

namespace Database\Seeders;

use App\Models\Patient;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class PatientSeeder extends Seeder
{
    public function run(): void
    {
        $patients = [
            [
                'user' => [
                    'email'     => 'aminata.diallo@gmail.com',
                    'password'  => Hash::make('Patient@123'),
                    'telephone' => '+221771234560',
                    'role'      => 'patient',
                    'est_actif' => true,
                ],
                'profil' => [
                    'nom'            => 'Diallo',
                    'prenom'         => 'Aminata',
                    'date_naissance' => '1990-05-15',
                    'genre'          => 'F',
                    'adresse'        => 'Sacré-Cœur 3, Dakar',
                    'groupe_sanguin' => 'O+',
                    'latitude'       => 14.7256,
                    'longitude'      => -17.4638,
                    'allergies'      => ['pénicilline', 'aspirine'],
                ],
                'dossier' => [
                    'antecedents_medicaux' => 'Asthme léger depuis l\'enfance. Paludisme simple traité en 2021. Césarienne en 2018.',
                    'allergies_connues'    => ['Pénicilline', 'Aspirine'],
                    'medicaments_actuels'  => ['Salbutamol (Ventoline) en cas de crise'],
                    'groupe_sanguin'       => 'O+',
                    'poids'                => 64,
                    'taille'               => 165,
                    'notes_generales'      => 'Suivi annuel de l\'asthme. Vaccinations à jour.',
                ],
            ],
            [
                'user' => [
                    'email'     => 'oumar.sow@gmail.com',
                    'password'  => Hash::make('Patient@123'),
                    'telephone' => '+221769998877',
                    'role'      => 'patient',
                    'est_actif' => true,
                ],
                'profil' => [
                    'nom'            => 'Sow',
                    'prenom'         => 'Oumar',
                    'date_naissance' => '1985-11-22',
                    'genre'          => 'M',
                    'adresse'        => 'Almadies, Dakar',
                    'groupe_sanguin' => 'A+',
                    'latitude'       => 14.7456,
                    'longitude'      => -17.5117,
                    'allergies'      => [],
                ],
                'dossier' => [
                    'antecedents_medicaux' => 'Hypertension artérielle diagnostiquée en 2019. Père diabétique de type 2.',
                    'allergies_connues'    => [],
                    'medicaments_actuels'  => ['Amlodipine 5 mg, 1 comprimé le matin'],
                    'groupe_sanguin'       => 'A+',
                    'poids'                => 82,
                    'taille'               => 178,
                    'notes_generales'      => 'Contrôle tensionnel tous les 3 mois. Glycémie à surveiller.',
                ],
            ],
            [
                'user' => [
                    'email'     => 'marieme.ba@gmail.com',
                    'password'  => Hash::make('Patient@123'),
                    'telephone' => '+221785443322',
                    'role'      => 'patient',
                    'est_actif' => true,
                ],
                'profil' => [
                    'nom'            => 'Ba',
                    'prenom'         => 'Marième',
                    'date_naissance' => '2000-03-08',
                    'genre'          => 'F',
                    'adresse'        => 'Pikine, Dakar',
                    'groupe_sanguin' => 'B+',
                    'latitude'       => 14.7517,
                    'longitude'      => -17.3967,
                    'allergies'      => ['sulfamides'],
                ],
                'dossier' => [
                    'antecedents_medicaux' => 'Anémie ferriprive en 2023. Aucun antécédent chirurgical.',
                    'allergies_connues'    => ['Sulfamides'],
                    'medicaments_actuels'  => ['Fer + acide folique, 1 comprimé par jour'],
                    'groupe_sanguin'       => 'B+',
                    'poids'                => 55,
                    'taille'               => 162,
                    'notes_generales'      => 'Bilan sanguin de contrôle prévu.',
                ],
            ],
        ];

        foreach ($patients as $data) {
            $user = User::firstOrCreate(
                ['email' => $data['user']['email']],
                $data['user']
            );
            $user->assignRole('patient');

            // numero_patient est auto-généré dans le boot() du modèle Patient
            $patient = Patient::firstOrCreate(
                ['user_id' => $user->id],
                array_merge($data['profil'], ['user_id' => $user->id])
            );

            // Le dossier vide est créé par le modèle Patient : on le complète
            $patient->dossierMedical()->updateOrCreate([], $data['dossier']);
        }

        $this->command->info('3 patients créés.');
    }
}
