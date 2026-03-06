<?php

namespace App\GraphQL\Mutations;

use App\Models\NotificationJwy;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MarquerNotificationLue
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): NotificationJwy
    {
        $user         = $context->user();
        $notification = NotificationJwy::where('id', $args['id'])
            ->where('user_id', $user->id)
            ->firstOrFail();

        $notification->marquerLue();

        return $notification->fresh();
    }
}
