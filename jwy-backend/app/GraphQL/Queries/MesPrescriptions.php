<?php

namespace App\GraphQL\Queries;

use App\Models\Prescription;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesPrescriptions
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user  = $context->user();
        $query = Prescription::query()->with(['medecin', 'medicamentsPrescrites.medicament']);

        if ($user->patient) {
            $query->where('patient_id', $user->patient->id);
        } elseif ($user->medecin) {
            $query->where('medecin_id', $user->medecin->id);
        }

        $paginator = $query->orderBy('created_at', 'desc')
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
