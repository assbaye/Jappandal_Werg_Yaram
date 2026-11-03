<?php

namespace App\GraphQL\Queries;

use App\Models\Paiement;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DetailPaiement
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): Paiement
    {
        $user = $context->user();

        // Un utilisateur ne voit que ses propres paiements (l'admin voit tout)
        $paiement = Paiement::with(['facture', 'payable'])
            ->when(! $user->hasRole('admin'), fn ($q) => $q->where('user_id', $user->id))
            ->find($args['id']);

        return $paiement ?? throw new Error('Paiement introuvable.');
    }
}
