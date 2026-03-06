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
            $consultation = Consultation::create([
                'patient_id'       => $patient->id,
                'medecin_id'       => $args['medecin_id'],
                'dossier_medical_id' => $patient->dossierMedical?->id,
                'type_consultation'  => strtolower($args['type_consultation']),
                'symptomes'          => $args['symptomes'],
                'date_consultation'  => $args['date_souhaitee'] ?? null,
                'statut'             => 'en_attente',
            ]);

            if (in_array($args['type_consultation'], ['VIDEO', 'CHAT'])) {
                TeleConsultation::create([
                    'consultation_id' => $consultation->id,
                ]);
            }

            // Notifier le médecin
            $medecin = $consultation->medecin;
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
