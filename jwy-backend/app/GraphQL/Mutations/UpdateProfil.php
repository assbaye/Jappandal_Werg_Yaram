<?php

namespace App\GraphQL\Mutations;

use App\Models\Patient;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateProfil
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): Patient
    {
        $patient = $context->user()->patient;

        if (! $patient) {
            throw new Error('Profil patient non trouvé.');
        }

        // Champs facultatifs vidés volontairement → null ; nom/prénom absents → inchangés
        $patient->update(array_filter($args, fn ($v, $k) => $v !== null || ! in_array($k, ['nom', 'prenom']), ARRAY_FILTER_USE_BOTH));

        return $patient->fresh();
    }
}
