<?php

namespace App\GraphQL\Mutations;

use App\Models\AlerteUrgence;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Illuminate\Support\Facades\DB;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class PrendreEnChargeUrgence
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): AlerteUrgence
    {
        $medecin = $context->user()->medecin;

        if (! $medecin) {
            throw new Error('Seul un médecin peut prendre en charge une urgence.');
        }

        // Verrou : deux médecins ne peuvent pas prendre la même alerte
        $alerte = DB::transaction(function () use ($args, $medecin) {
            $alerte = AlerteUrgence::lockForUpdate()->findOrFail($args['id']);

            if ($alerte->statut !== 'active') {
                throw new Error($alerte->statut === 'prise_en_charge'
                    ? 'Cette urgence est déjà prise en charge par un autre médecin.'
                    : 'Cette alerte n\'est plus active.');
            }

            $alerte->update([
                'statut'             => 'prise_en_charge',
                'medecin_id'         => $medecin->id,
                'prise_en_charge_le' => now(),
            ]);

            return $alerte;
        });

        $this->notif->sendToUser(
            userId: $alerte->patient->user_id,
            titre: 'Votre urgence est prise en charge',
            message: "Dr. {$medecin->nom_complet} s'occupe de votre alerte et va vous contacter.",
            type: 'urgence',
            data: ['alerte_urgence_id' => $alerte->id],
            priorite: 'urgente',
        );

        return $alerte->fresh();
    }
}
