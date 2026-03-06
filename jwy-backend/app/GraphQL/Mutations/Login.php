<?php

namespace App\GraphQL\Mutations;

use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class Login
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $credentials = [
            'email'    => $args['email'],
            'password' => $args['password'],
        ];

        if (! $token = auth('api')->attempt($credentials)) {
            throw new Error('Email ou mot de passe incorrect.');
        }

        $user = auth('api')->user();

        if (! $user->est_actif) {
            auth('api')->logout();
            throw new Error('Votre compte a été désactivé. Contactez l\'administration.');
        }

        $user->update(['dernier_login' => now()]);

        return [
            'access_token' => $token,
            'token_type'   => 'bearer',
            'expires_in'   => auth('api')->factory()->getTTL() * 60,
            'user'         => $user,
        ];
    }
}
