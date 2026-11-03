<?php

namespace App\GraphQL\Mutations;

use App\Models\AlerteUrgence;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

/**
 * Le patient annule son alerte ; le médecin en charge la clôture.
 */
class TerminerAlerteUrgence
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): AlerteUrgence
    {
        $user   = $context->user();
        $alerte = AlerteUrgence::with(['patient', 'medecin'])->findOrFail($args['id']);

        $estPatient = $user->patient?->id === $alerte->patient_id;
        $estMedecin = $user->medecin && $user->medecin->id === $alerte->medecin_id;

        if (! $estPatient && ! $estMedecin) {
            throw new Error('Vous ne pouvez pas modifier cette alerte.');
        }

        if (! in_array($alerte->statut, ['active', 'prise_en_charge'])) {
            throw new Error('Cette alerte est déjà terminée.');
        }

        $alerte->update([
            'statut'      => $estPatient ? 'annulee' : 'cloturee',
            'cloturee_le' => now(),
        ]);

        // Le patient annule une alerte déjà prise en charge : prévenir le médecin
        if ($estPatient && $alerte->medecin) {
            $this->notif->sendToUser(
                userId: $alerte->medecin->user_id,
                titre: 'Alerte annulée',
                message: "{$alerte->patient->nom_complet} a annulé son alerte d'urgence.",
                type: 'urgence',
                data: ['alerte_urgence_id' => $alerte->id],
            );
        }

        return $alerte->fresh();
    }
}
