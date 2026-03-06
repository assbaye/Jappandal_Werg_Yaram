<?php

namespace App\GraphQL\Queries;

use App\Models\NotificationJwy;
use App\Models\User;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class NotificationsNonLues
{
    public function __invoke(User $user, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): int
    {
        return NotificationJwy::where('user_id', $user->id)->where('est_lue', false)->count();
    }
}
