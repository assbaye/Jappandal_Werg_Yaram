<?php

namespace App\GraphQL\Mutations;

use App\Models\Pharmacie;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateMaPharmacie
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): Pharmacie
    {
        $pharmacie = $context->user()->pharmacien?->pharmacies()->first();

        if (! $pharmacie) {
            throw new Error('Aucune pharmacie rattachée à votre compte.');
        }

        // La position (latitude/longitude) n'est pas modifiable ici
        $pharmacie->update(array_filter(
            $args,
            fn ($v, $k) => $v !== null || $k === 'telephone',
            ARRAY_FILTER_USE_BOTH
        ));

        return $pharmacie->fresh();
    }
}
