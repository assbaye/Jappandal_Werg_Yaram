<?php

namespace App\GraphQL\Queries;

use App\Models\StockMedicament;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MonStock
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): LengthAwarePaginator
    {
        $user = $context->user();

        abort_if(!$user->pharmacien, 403, 'Accès réservé aux pharmaciens.');

        $pharmacieIds = $user->pharmacien->pharmacies->pluck('id');

        return StockMedicament::whereIn('pharmacie_id', $pharmacieIds)
            ->with(['medicament', 'pharmacie'])
            ->orderBy('quantite_disponible')
            ->paginate($args['first'] ?? 20, ['*'], 'page', $args['page'] ?? 1);
    }
}
