<?php

namespace App\GraphQL\Queries;

use App\Models\StockMedicament;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Support\Collection;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DisponibiliteMedicament
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Collection
    {
        $query = StockMedicament::where('medicament_id', $args['medicament_id'])
            ->where('quantite_disponible', '>', 0)
            ->with(['medicament', 'pharmacie']);

        if (!empty($args['pharmacie_id'])) {
            $query->where('pharmacie_id', $args['pharmacie_id']);
        }

        return $query->get();
    }
}
