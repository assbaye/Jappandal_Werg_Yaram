<?php

namespace App\GraphQL\Mutations;

use App\Models\Medecin;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class ToggleDisponibilite
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Medecin
    {
        $user    = $context->user();
        $medecin = $user->medecin;

        abort_if(!$medecin, 403, 'Profil médecin non trouvé.');

        $medecin->update([
            'disponible_maintenant' => !$medecin->disponible_maintenant,
        ]);

        return $medecin->fresh();
    }
}
