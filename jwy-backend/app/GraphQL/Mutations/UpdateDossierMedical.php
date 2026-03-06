<?php

namespace App\GraphQL\Mutations;

use App\Models\DossierMedical;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateDossierMedical
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): DossierMedical
    {
        $user    = $context->user();
        $patient = $user->patient;

        abort_if(!$patient, 403);

        $dossier = $patient->dossierMedical;
        $dossier->update(array_filter($args, fn($v) => $v !== null));

        return $dossier->fresh();
    }
}
