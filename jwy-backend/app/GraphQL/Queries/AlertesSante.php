<?php

namespace App\GraphQL\Queries;

use App\Models\AlerteSante;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class AlertesSante
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): LengthAwarePaginator
    {
        $query = AlerteSante::query();

        if (!empty($args['actives_seulement'])) {
            $query->where('est_active', true);
        }

        return $query->orderBy('created_at', 'desc')->paginate($args['first'] ?? 10, ['*'], 'page', $args['page'] ?? 1);
    }
}
