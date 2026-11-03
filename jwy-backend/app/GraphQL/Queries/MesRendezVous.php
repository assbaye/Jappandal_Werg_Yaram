<?php

namespace App\GraphQL\Queries;

use App\Models\RendezVous;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesRendezVous
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user  = $context->user();
        $query = RendezVous::query()->with(['patient', 'medecin']);

        if ($user->patient) {
            $query->where('patient_id', $user->patient->id);
        } elseif ($user->medecin) {
            $query->where('medecin_id', $user->medecin->id);
        }

        if (!empty($args['statut'])) {
            $query->where('statut', $args['statut']);
        }

        $paginator = $query->orderBy('date_rendez_vous', 'desc')
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
