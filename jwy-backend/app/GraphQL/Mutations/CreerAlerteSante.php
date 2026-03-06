<?php

namespace App\GraphQL\Mutations;

use App\Models\AlerteSante;
use App\Services\NotificationService;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class CreerAlerteSante
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): AlerteSante
    {
        $user = $context->user();

        abort_if(!$user->hasRole('admin'), 403, 'Seuls les admins peuvent créer des alertes santé.');

        $alerte = AlerteSante::create([
            'created_by'      => $user->id,
            'type_alerte'     => $args['type_alerte'],
            'zone'            => $args['zone'],
            'niveau_gravite'  => $args['niveau_gravite'],
            'description'     => $args['description'],
            'recommandations' => $args['recommandations'] ?? null,
            'date_debut'      => $args['date_debut'],
            'date_fin'        => $args['date_fin'] ?? null,
            'est_active'      => true,
        ]);

        // Broadcast à tous les patients
        app(NotificationService::class)->sendHealthAlert($alerte);

        return $alerte;
    }
}
