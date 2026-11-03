<?php

namespace App\GraphQL\Mutations;

use App\Models\Consultation;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class RepondreConsultation
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): Consultation
    {
        $medecin = $context->user()->medecin;

        if (! $medecin) {
            throw new Error('Seul un médecin peut répondre à une demande de consultation.');
        }

        $consultation = Consultation::findOrFail($args['consultation_id']);

        if ($consultation->medecin_id !== $medecin->id) {
            throw new Error('Cette consultation ne vous est pas adressée.');
        }

        if ($consultation->statut !== 'en_attente') {
            throw new Error('Cette demande a déjà été traitée.');
        }

        $accepter = $args['accepter'];

        $consultation->update(['statut' => $accepter ? 'confirmee' : 'annulee']);

        $motif = ! empty($args['motif']) ? " Motif : {$args['motif']}" : '';

        $this->notif->sendToUser(
            userId: $consultation->patient->user_id,
            titre: $accepter ? 'Consultation acceptée' : 'Consultation refusée',
            message: $accepter
                ? "Dr. {$medecin->nom_complet} a accepté votre demande de consultation."
                : "Dr. {$medecin->nom_complet} ne peut pas donner suite à votre demande.{$motif}",
            type: 'consultation',
            data: ['consultation_id' => $consultation->id],
        );

        return $consultation->fresh();
    }
}
