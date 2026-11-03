<?php

namespace App\GraphQL\Queries;

use App\Models\AlerteUrgence;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MonAlerteUrgence
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): ?AlerteUrgence
    {
        $patient = $context->user()->patient;

        return $patient
            ? AlerteUrgence::where('patient_id', $patient->id)->enCours()->latest()->first()
            : null;
    }
}
