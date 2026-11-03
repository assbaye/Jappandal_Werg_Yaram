<?php

namespace App\GraphQL\Mutations;

use App\Models\Consultation;
use App\Models\TeleConsultation;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Illuminate\Support\Facades\DB;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DemanderConsultation
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): Consultation
    {
        $user = $context->user();

        if (! $user->isPatient()) {
            throw new Error('Seul un patient peut demander une consultation.');
        }

        $patient = $user->patient;

        return DB::transaction(function () use ($args, $patient) {
            $medecin = \App\Models\Medecin::findOrFail($args['medecin_id']);

            $consultation = Consultation::create([
                'patient_id'         => $patient->id,
                'medecin_id'         => $medecin->id,
                'dossier_medical_id' => $patient->dossierMedical?->id,
                'type_consultation'  => strtolower($args['type_consultation']),
                'symptomes'          => $args['symptomes'],
                'date_consultation'  => $args['date_souhaitee'] ?? null,
                'statut'             => 'en_attente',
                'cout_consultation'  => $medecin->tarif_consultation,
            ]);

            if (in_array(strtolower($args['type_consultation']), ['video', 'chat'])) {
                TeleConsultation::create([
                    'consultation_id' => $consultation->id,
                ]);
            }

            // Notifier le médecin
            $this->notif->sendToUser(
                $medecin->user_id,
                'Nouvelle demande de consultation',
                "Le patient {$patient->nom_complet} demande une consultation.",
                'consultation',
                ['consultation_id' => $consultation->id]
            );

            return $consultation;
        });
    }
}
