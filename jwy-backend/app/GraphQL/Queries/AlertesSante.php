<?php

namespace App\GraphQL\Queries;

use App\Models\AlerteSante;
use Illuminate\Database\Eloquent\Collection;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class AlertesSante
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): Collection
    {
        return AlerteSante::where('est_active', true)
            ->when(! empty($args['zone']), fn ($q) => $q->where('zone', 'ilike', "%{$args['zone']}%"))
            ->latest()
            ->limit(20)
            ->get();
    }
}
