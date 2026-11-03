<?php

namespace App\GraphQL\Mutations;

use App\Models\Medecin;
use App\Models\RendezVous;
use App\Services\NotificationService;
use Carbon\Carbon;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class PrendreRendezVous
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): RendezVous
    {
        $patient = $context->user()->patient;

        if (! $patient) {
            throw new Error('Seuls les patients peuvent prendre des rendez-vous.');
        }

        $medecin = Medecin::findOrFail($args['medecin_id']);
        $date    = Carbon::parse($args['date_rendez_vous']);
        $duree   = $args['duree_estimee'] ?? 30;

        if ($date->isPast()) {
            throw new Error('La date du rendez-vous doit être dans le futur.');
        }

        if (RendezVous::chevauche($medecin->id, $date, $duree)->exists()) {
            throw new Error('Ce créneau est déjà pris. Choisissez une autre heure.');
        }

        $rdv = RendezVous::create([
            'patient_id'       => $patient->id,
            'medecin_id'       => $medecin->id,
            'date_rendez_vous' => $date,
            'duree_estimee'    => $duree,
            'type_rendez_vous' => strtolower($args['type_rendez_vous']),
            'motif'            => $args['motif'] ?? null,
            'lieu_rendez_vous' => $args['lieu_rendez_vous'] ?? null,
            'statut'           => 'en_attente',
        ]);

        $this->notif->sendToUser(
            userId: $medecin->user_id,
            titre: 'Nouvelle demande de rendez-vous',
            message: "{$patient->nom_complet} demande un rendez-vous le {$date->translatedFormat('d/m/Y à H:i')}.",
            type: 'rendez_vous',
            data: ['rendez_vous_id' => $rdv->id],
        );

        return $rdv;
    }
}
