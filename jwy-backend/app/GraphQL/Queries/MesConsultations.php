<?php

namespace App\GraphQL\Queries;

use App\Models\Consultation;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesConsultations
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user = $context->user();

        $paginator = Consultation::with(['patient', 'medecin', 'teleconsultation', 'prescriptions'])
            ->when($user->isPatient(), fn ($q) => $q->where('patient_id', $user->patient->id))
            ->when($user->isMedecin(), fn ($q) => $q->where('medecin_id', $user->medecin->id))
            ->when(isset($args['statut']), fn ($q) => $q->where('statut', strtolower($args['statut'])))
            ->orderByDesc('created_at')
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
