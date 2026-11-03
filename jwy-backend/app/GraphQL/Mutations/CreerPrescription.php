<?php

namespace App\GraphQL\Mutations;

use App\Models\Consultation;
use App\Models\MedicamentPrescrit;
use App\Models\Patient;
use App\Models\Prescription;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Illuminate\Support\Facades\DB;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class CreerPrescription
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): Prescription
    {
        $user = $context->user();

        if (! $user->isMedecin()) {
            throw new Error('Seul un médecin peut créer une prescription.');
        }

        $patient = Patient::findOrFail($args['patient_id']);

        if (! empty($args['consultation_id'])) {
            $consultation = Consultation::findOrFail($args['consultation_id']);
            if ($consultation->medecin_id !== $user->medecin->id || $consultation->patient_id !== $patient->id) {
                throw new Error('Cette consultation ne correspond pas à ce patient ou à ce médecin.');
            }
        }

        if (empty($args['medicaments'])) {
            throw new Error('Ajoutez au moins un médicament à l\'ordonnance.');
        }

        return DB::transaction(function () use ($args, $user, $patient) {
            $prescription = Prescription::create([
                'medecin_id'      => $user->medecin->id,
                'patient_id'      => $args['patient_id'],
                'consultation_id' => $args['consultation_id'] ?? null,
                'validite_jours'  => $args['validite_jours'] ?? 30,
                'instructions'    => $args['instructions'] ?? null,
            ]);

            foreach ($args['medicaments'] as $med) {
                MedicamentPrescrit::create([
                    'prescription_id'      => $prescription->id,
                    'medicament_id'        => $med['medicament_id'],
                    'quantite'             => $med['quantite'],
                    'posologie'            => $med['posologie'],
                    'duree_traitement'     => $med['duree_traitement'],
                    'instructions_speciales' => $med['instructions_speciales'] ?? null,
                ]);
            }

            // Notifier le patient
            $this->notif->sendToUser(
                userId: $patient->user_id,
                titre: 'Nouvelle prescription',
                message: "Dr. {$user->medecin->nom_complet} vous a prescrit des médicaments.",
                type: 'prescription',
                data: ['prescription_id' => $prescription->id]
            );

            return $prescription->load('medicamentsPrescrits.medicament');
        });
    }
}
