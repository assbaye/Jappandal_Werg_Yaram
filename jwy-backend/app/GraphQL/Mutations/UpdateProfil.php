<?php

namespace App\GraphQL\Mutations;

use App\Models\Patient;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateProfil
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Patient
    {
        $user    = $context->user();
        $patient = $user->patient;

        abort_if(!$patient, 403, 'Profil patient non trouvé.');

        $patient->update(array_filter($args, fn($v) => $v !== null));

        return $patient->fresh();
    }
}
