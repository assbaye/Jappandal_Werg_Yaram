<?php

namespace App\GraphQL\Queries;

use App\Models\NotificationJwy;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesNotifications
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): LengthAwarePaginator
    {
        $user  = $context->user();
        $query = NotificationJwy::where('user_id', $user->id);

        if (isset($args['non_lues']) && $args['non_lues']) {
            $query->where('est_lue', false);
        }

        return $query->orderBy('created_at', 'desc')->paginate($args['first'] ?? 20, ['*'], 'page', $args['page'] ?? 1);
    }
}
