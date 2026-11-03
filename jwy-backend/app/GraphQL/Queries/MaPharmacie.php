<?php

namespace App\GraphQL\Queries;

use App\Models\Pharmacie;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MaPharmacie
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): ?Pharmacie
    {
        $pharmacien = $context->user()->pharmacien;

        if (! $pharmacien) {
            throw new Error('Accès réservé aux pharmaciens.');
        }

        return $pharmacien->pharmacies()->first();
    }
}
