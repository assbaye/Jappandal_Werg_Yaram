<?php

namespace App\GraphQL\Mutations;

use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class Logout
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): bool
    {
        auth('api')->logout();
        return true;
    }
}
