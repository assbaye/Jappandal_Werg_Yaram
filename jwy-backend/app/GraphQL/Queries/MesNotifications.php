<?php

namespace App\GraphQL\Queries;

use App\Models\NotificationJwy;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesNotifications
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user  = $context->user();
        $query = NotificationJwy::where('user_id', $user->id);

        if (isset($args['est_lue'])) {
            $query->where('est_lue', $args['est_lue']);
        }

        $paginator = $query->orderBy('created_at', 'desc')
            ->paginate($args['first'] ?? 20, ['*'], 'page', $args['page'] ?? 1);

        return [
            'data' => $paginator->items(),
            'paginatorInfo' => [
                'count'        => $paginator->count(),
                'currentPage'  => $paginator->currentPage(),
                'lastPage'     => $paginator->lastPage(),
                'total'        => $paginator->total(),
                'hasMorePages' => $paginator->hasMorePages(),
            ],
        ];
    }
}
