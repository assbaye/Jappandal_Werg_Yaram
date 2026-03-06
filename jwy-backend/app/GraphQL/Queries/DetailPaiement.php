<?php

namespace App\GraphQL\Queries;

use App\Models\Paiement;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DetailPaiement
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): ?Paiement
    {
        return Paiement::with(['facture', 'payable'])->findOrFail($args['id']);
    }
}
