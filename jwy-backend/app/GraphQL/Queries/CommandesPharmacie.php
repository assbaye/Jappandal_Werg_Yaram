<?php

namespace App\GraphQL\Queries;

use App\Models\Commande;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class CommandesPharmacie
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $pharmacien = $context->user()->pharmacien;

        if (! $pharmacien) {
            throw new Error('Accès réservé aux pharmaciens.');
        }

        $paginator = Commande::whereIn('pharmacie_id', $pharmacien->pharmacies->pluck('id'))
            ->when(! empty($args['statut']), fn ($q) => $q->where('statut', $args['statut']))
            ->with(['patient', 'medicaments'])
            ->latest()
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
