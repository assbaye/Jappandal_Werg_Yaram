<?php

namespace App\GraphQL\Mutations;

use App\Models\Medecin;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateProfilMedecin
{
    /** Champs obligatoires en base : ignorés s'ils sont absents ou null */
    private const REQUIS = ['nom', 'prenom', 'specialite', 'tarif_consultation', 'annees_experience'];

    public function __invoke(mixed $root, array $args, GraphQLContext $context): Medecin
    {
        $medecin = $context->user()->medecin;

        if (! $medecin) {
            throw new Error('Profil médecin non trouvé.');
        }

        $medecin->update(array_filter(
            $args,
            fn ($v, $k) => $v !== null || ! in_array($k, self::REQUIS),
            ARRAY_FILTER_USE_BOTH
        ));

        return $medecin->fresh();
    }
}
