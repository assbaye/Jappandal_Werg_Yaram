<?php

namespace App\GraphQL\Mutations;

use App\Models\User;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateCompte
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): User
    {
        $user = $context->user();

        if (array_key_exists('telephone', $args)) {
            $telephone = trim((string) $args['telephone']) ?: null;

            if ($telephone && User::where('telephone', $telephone)->where('id', '!=', $user->id)->exists()) {
                throw new Error('Ce numéro de téléphone est déjà utilisé.');
            }
            $user->telephone = $telephone;
        }

        if (! empty($args['langue_preferee'])) {
            $user->langue_preferee = $args['langue_preferee'];
        }

        $user->save();

        return $user;
    }
}
