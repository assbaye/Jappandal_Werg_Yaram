<?php

namespace App\GraphQL\Queries;

use App\Models\DossierMedical;
use App\Models\Prescription;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Support\Collection;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DossierPrescriptions
{
    public function __invoke(DossierMedical $dossier, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Collection
    {
        return Prescription::whereHas('consultation', function ($q) use ($dossier) {
            $q->where('dossier_medical_id', $dossier->id);
        })->with('medicamentsPrescrits')->get();
    }
}
