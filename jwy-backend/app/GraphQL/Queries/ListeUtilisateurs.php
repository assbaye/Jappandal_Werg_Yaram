<?php

namespace App\GraphQL\Queries;

use App\Models\User;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class ListeUtilisateurs
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): LengthAwarePaginator
    {
        abort_if(!$context->user()->hasRole('admin'), 403);

        $query = User::query();

        if (!empty($args['role'])) {
            $query->where('role', $args['role']);
        }

        return $query->orderBy('created_at', 'desc')->paginate($args['first'] ?? 20, ['*'], 'page', $args['page'] ?? 1);
    }
}
