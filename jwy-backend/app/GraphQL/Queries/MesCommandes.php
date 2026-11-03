<?php

namespace App\GraphQL\Queries;

use App\Models\Commande;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesCommandes
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $patient = $context->user()->patient;

        if (! $patient) {
            throw new Error('Accès réservé aux patients.');
        }

        $paginator = Commande::where('patient_id', $patient->id)
            ->with(['pharmacie', 'medicaments'])
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
