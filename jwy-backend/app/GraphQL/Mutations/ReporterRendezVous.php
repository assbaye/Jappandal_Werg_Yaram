<?php

namespace App\GraphQL\Mutations;

use App\Models\RendezVous;
use App\Services\NotificationService;
use Carbon\Carbon;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class ReporterRendezVous
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): RendezVous
    {
        $user = $context->user();
        $rdv  = RendezVous::with(['patient', 'medecin'])->findOrFail($args['id']);

        $estPatient = $user->patient?->id === $rdv->patient_id;
        $estMedecin = $user->medecin?->id === $rdv->medecin_id;

        if (! $estPatient && ! $estMedecin) {
            throw new Error('Accès non autorisé à ce rendez-vous.');
        }

        if (in_array($rdv->statut, ['annule', 'termine'])) {
            throw new Error('Ce rendez-vous ne peut plus être reporté.');
        }

        $date = Carbon::parse($args['nouvelle_date']);

        if ($date->isPast()) {
            throw new Error('La nouvelle date doit être dans le futur.');
        }

        if (RendezVous::chevauche($rdv->medecin_id, $date, $rdv->duree_estimee, $rdv->id)->exists()) {
            throw new Error('Ce créneau est déjà pris. Choisissez une autre heure.');
        }

        // Reporté par le patient : le médecin doit reconfirmer.
        // Reporté par le médecin : le nouveau créneau est proposé au patient.
        $rdv->update([
            'date_rendez_vous' => $date,
            'statut'           => $estPatient ? 'en_attente' : 'reporte',
        ]);

        $nouvelle = $date->translatedFormat('d/m/Y à H:i');
        $this->notif->sendToUser(
            userId: $estPatient ? $rdv->medecin->user_id : $rdv->patient->user_id,
            titre: 'Rendez-vous reporté',
            message: $estPatient
                ? "{$rdv->patient->nom_complet} propose de déplacer le rendez-vous au {$nouvelle}."
                : "Dr. {$rdv->medecin->nom_complet} a déplacé votre rendez-vous au {$nouvelle}.",
            type: 'rendez_vous',
            data: ['rendez_vous_id' => $rdv->id],
        );

        return $rdv->fresh();
    }
}
