<?php

namespace App\GraphQL\Queries;

use App\Models\Consultation;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesConsultations
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context)
    {
        $user = $context->user();

        $query = Consultation::with(['patient.user', 'medecin.user', 'teleconsultation', 'prescriptions'])
            ->when($user->isPatient(), fn ($q) => $q->where('patient_id', $user->patient->id))
            ->when($user->isMedecin(), fn ($q) => $q->where('medecin_id', $user->medecin->id))
            ->when(isset($args['statut']), fn ($q) => $q->where('statut', strtolower($args['statut'])))
            ->orderByDesc('created_at');

        return $query->paginate($args['first'] ?? 10, ['*'], 'page', $args['page'] ?? 1);
    }
}
