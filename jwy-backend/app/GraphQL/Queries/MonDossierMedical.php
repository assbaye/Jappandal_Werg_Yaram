<?php

namespace App\GraphQL\Queries;

use App\Models\DossierMedical;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MonDossierMedical
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): DossierMedical
    {
        $user = $context->user();

        if (! $user->isPatient()) {
            throw new Error('Seul un patient peut accéder à son dossier médical.');
        }

        return $user->patient->dossierMedical()->with([
            'consultations.medecin',
            'consultations.prescriptions.medicamentsPrescrits.medicament',
        ])->firstOrFail();
    }
}
