<?php

namespace App\GraphQL\Mutations;

use App\Models\RendezVous;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class RepondreRendezVous
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): RendezVous
    {
        $medecin = $context->user()->medecin;

        if (! $medecin) {
            throw new Error('Seul un médecin peut confirmer un rendez-vous.');
        }

        $rdv = RendezVous::findOrFail($args['id']);

        if ($rdv->medecin_id !== $medecin->id) {
            throw new Error('Ce rendez-vous ne vous est pas adressé.');
        }

        if (! in_array($rdv->statut, ['en_attente', 'reporte'])) {
            throw new Error('Ce rendez-vous a déjà été traité.');
        }

        $accepter = $args['accepter'];
        $rdv->update(['statut' => $accepter ? 'confirme' : 'annule']);

        $date  = $rdv->date_rendez_vous->translatedFormat('d/m/Y à H:i');
        $motif = ! empty($args['motif']) ? " Motif : {$args['motif']}" : '';

        $this->notif->sendToUser(
            userId: $rdv->patient->user_id,
            titre: $accepter ? 'Rendez-vous confirmé' : 'Rendez-vous refusé',
            message: $accepter
                ? "Dr. {$medecin->nom_complet} a confirmé votre rendez-vous du {$date}."
                : "Dr. {$medecin->nom_complet} ne peut pas vous recevoir le {$date}.{$motif}",
            type: 'rendez_vous',
            data: ['rendez_vous_id' => $rdv->id],
        );

        return $rdv->fresh();
    }
}
