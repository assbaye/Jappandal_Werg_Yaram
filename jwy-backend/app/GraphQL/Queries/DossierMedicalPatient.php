<?php

namespace App\GraphQL\Queries;

use App\Models\DossierMedical;
use App\Models\Patient;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DossierMedicalPatient
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): ?DossierMedical
    {
        $user = $context->user();

        abort_if(!$user->medecin && !$user->hasRole('admin'), 403, 'Accès réservé aux médecins.');

        $patient = Patient::findOrFail($args['patient_id']);

        return $patient->dossierMedical;
    }
}
