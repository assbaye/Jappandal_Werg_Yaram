<?php

namespace App\GraphQL\Mutations;

use App\Models\Commande;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateStatutCommande
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Commande
    {
        $user      = $context->user();
        $commande  = Commande::findOrFail($args['commande_id']);

        abort_if(
            !$user->hasRole('admin') && $user->pharmacien?->pharmacies->doesntContain($commande->pharmacie_id),
            403
        );

        $commande->update(['statut' => $args['statut']]);

        return $commande->fresh();
    }
}
