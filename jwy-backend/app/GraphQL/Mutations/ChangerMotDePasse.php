<?php

namespace App\GraphQL\Mutations;

use GraphQL\Error\Error;
use Illuminate\Support\Facades\Hash;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class ChangerMotDePasse
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): bool
    {
        $user = $context->user();

        if (! Hash::check($args['ancien_mot_de_passe'], $user->password)) {
            throw new Error('Le mot de passe actuel est incorrect.');
        }

        if (Hash::check($args['nouveau_mot_de_passe'], $user->password)) {
            throw new Error('Le nouveau mot de passe doit être différent de l\'actuel.');
        }

        $user->update(['password' => $args['nouveau_mot_de_passe']]); // haché par le cast du modèle

        return true;
    }
}
