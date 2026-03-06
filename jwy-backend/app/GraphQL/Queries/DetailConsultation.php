<?php

namespace App\GraphQL\Queries;

use App\Models\Consultation;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DetailConsultation
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): ?Consultation
    {
        $user         = $context->user();
        $consultation = Consultation::with(['patient', 'medecin', 'prescriptions', 'teleconsultation'])->findOrFail($args['id']);

        abort_if(
            $user->patient?->id !== $consultation->patient_id
            && $user->medecin?->id !== $consultation->medecin_id
            && !$user->hasRole('admin'),
            403
        );

        return $consultation;
    }
}
