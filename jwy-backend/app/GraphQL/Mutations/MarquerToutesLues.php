<?php

namespace App\GraphQL\Mutations;

use App\Models\NotificationJwy;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MarquerToutesLues
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): bool
    {
        $user = $context->user();

        NotificationJwy::where('user_id', $user->id)
            ->where('est_lue', false)
            ->update(['est_lue' => true, 'lue_le' => now()]);

        return true;
    }
}
