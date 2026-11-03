<?php

namespace App\GraphQL\Queries;

use App\Models\Paiement;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesPaiements
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user = $context->user();

        $paginator = Paiement::with(['facture'])
            ->whereHasMorph('payable', ['App\Models\Consultation', 'App\Models\Commande'], function ($q) use ($user) {
                if ($user->patient) {
                    $q->where('patient_id', $user->patient->id);
                }
            })
            ->orderBy('created_at', 'desc')
            ->paginate($args['first'] ?? 10, ['*'], 'page', $args['page'] ?? 1);

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
