<?php

namespace App\GraphQL\Mutations;

use App\Models\RendezVous;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class AnnulerRendezVous
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
            throw new Error('Ce rendez-vous ne peut plus être annulé.');
        }

        $rdv->update(['statut' => 'annule']);

        // Prévenir l'autre partie
        $date = $rdv->date_rendez_vous->translatedFormat('d/m/Y à H:i');
        $this->notif->sendToUser(
            userId: $estPatient ? $rdv->medecin->user_id : $rdv->patient->user_id,
            titre: 'Rendez-vous annulé',
            message: $estPatient
                ? "{$rdv->patient->nom_complet} a annulé le rendez-vous du {$date}."
                : "Dr. {$rdv->medecin->nom_complet} a annulé le rendez-vous du {$date}.",
            type: 'rendez_vous',
            data: ['rendez_vous_id' => $rdv->id],
        );

        return $rdv;
    }
}
