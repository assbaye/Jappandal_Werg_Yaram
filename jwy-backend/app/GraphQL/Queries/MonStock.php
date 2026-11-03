<?php

namespace App\GraphQL\Queries;

use App\Models\StockMedicament;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MonStock
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user = $context->user();

        abort_if(!$user->pharmacien, 403, 'Accès réservé aux pharmaciens.');

        $pharmacieIds = $user->pharmacien->pharmacies->pluck('id');

        $paginator = StockMedicament::whereIn('pharmacie_id', $pharmacieIds)
            ->with(['medicament', 'pharmacie'])
            ->orderBy('quantite_disponible')
            ->paginate($args['first'] ?? 20, ['*'], 'page', $args['page'] ?? 1);

        return [
            'data' => $paginator->items(),
            'paginatorInfo' => [
                'count'        => $paginator->count(),
                'currentPage'  => $paginator->currentPage(),
                'lastPage'     => $paginator->lastPage(),
                'total'        => $paginator->total(),
                'hasMorePages' => $paginator->hasMorePages(),
            ],
        ];
    }
}
