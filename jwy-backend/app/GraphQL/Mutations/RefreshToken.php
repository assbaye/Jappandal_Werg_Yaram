<?php

namespace App\GraphQL\Mutations;

use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;
use Tymon\JWTAuth\Facades\JWTAuth;

class RefreshToken
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): array
    {
        $token = JWTAuth::refresh(JWTAuth::getToken());

        return [
            'access_token' => $token,
            'token_type'   => 'bearer',
            'expires_in'   => auth('api')->factory()->getTTL() * 60,
            'user'         => auth('api')->user(),
        ];
    }
}
