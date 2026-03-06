<?php

namespace App\GraphQL\Queries;

use App\Models\Pharmacie;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class PharmaciesProches
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): \Illuminate\Database\Eloquent\Collection
    {
        return Pharmacie::query()
            ->where('est_active', true)
            ->proche($args['latitude'], $args['longitude'], $args['rayon'] ?? 10)
            ->with(['stocks.medicament'])
            ->get();
    }
}
