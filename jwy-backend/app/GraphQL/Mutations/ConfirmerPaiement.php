<?php

namespace App\GraphQL\Mutations;

use App\Models\Paiement;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class ConfirmerPaiement
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Paiement
    {
        $paiement = Paiement::where('numero_transaction', $args['transaction_id'])->firstOrFail();

        $paiement->update(['statut' => 'paye']);

        return $paiement->fresh();
    }
}
