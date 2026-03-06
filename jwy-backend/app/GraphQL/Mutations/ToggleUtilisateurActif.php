<?php

namespace App\GraphQL\Mutations;

use App\Models\User;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class ToggleUtilisateurActif
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): User
    {
        abort_if(!$context->user()->hasRole('admin'), 403);

        $user = User::findOrFail($args['user_id']);
        $user->update(['est_actif' => !$user->est_actif]);

        return $user->fresh();
    }
}
