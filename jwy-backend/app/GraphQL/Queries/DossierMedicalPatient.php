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

        // Un médecin ne voit que le dossier de ses propres patients
        if ($user->medecin && ! $patient->consultations()->where('medecin_id', $user->medecin->id)->exists()) {
            throw new \GraphQL\Error\Error('Ce patient n\'a aucune consultation avec vous.');
        }

        return $patient->dossierMedical;
    }
}
