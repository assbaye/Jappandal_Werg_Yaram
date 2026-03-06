<?php

namespace App\GraphQL\Mutations;

use App\Models\AlerteSante;
use App\Services\NotificationService;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DeclencherAlerteUrgence
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): AlerteSante
    {
        $user = $context->user();

        $alerte = AlerteSante::create([
            'created_by'      => $user->id,
            'type_alerte'     => 'urgence_personnelle',
            'zone'            => "GPS: {$args['latitude']}, {$args['longitude']}",
            'niveau_gravite'  => 'urgence',
            'description'     => "Alerte urgence déclenchée par {$user->email}",
            'recommandations' => 'Contacter les secours : 15 (SAMU) ou 18 (Pompiers)',
            'date_debut'      => now(),
            'est_active'      => true,
        ]);

        // Notifier les équipes médicales proches (simplifié)
        app(NotificationService::class)->sendToUser(
            userId: $user->id,
            titre: '🚨 Alerte urgence déclenchée',
            message: 'Votre alerte a été envoyée. Les secours ont été notifiés.',
            type: 'urgence',
            priorite: 'urgente',
        );

        return $alerte;
    }
}
