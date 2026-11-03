<?php

namespace App\GraphQL\Mutations;

use App\Models\Pharmacien;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateProfilPharmacien
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): Pharmacien
    {
        $pharmacien = $context->user()->pharmacien;

        if (! $pharmacien) {
            throw new Error('Profil pharmacien non trouvé.');
        }

        $pharmacien->update(array_filter($args, fn ($v) => $v !== null));

        return $pharmacien->fresh();
    }
}
