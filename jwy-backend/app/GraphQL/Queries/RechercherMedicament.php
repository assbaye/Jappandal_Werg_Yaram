<?php

namespace App\GraphQL\Queries;

use App\Models\Medicament;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Support\Collection;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class RechercherMedicament
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Collection
    {
        return Medicament::where('nom_commercial', 'ilike', "%{$args['terme']}%")
            ->orWhere('principe_actif', 'ilike', "%{$args['terme']}%")
            ->limit(20)
            ->get();
    }
}
