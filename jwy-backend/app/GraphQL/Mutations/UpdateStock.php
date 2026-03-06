<?php

namespace App\GraphQL\Mutations;

use App\Models\StockMedicament;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateStock
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): StockMedicament
    {
        $stock = StockMedicament::findOrFail($args['stock_id']);

        $stock->update(array_filter([
            'quantite_disponible' => $args['quantite_disponible'] ?? null,
            'prix_vente'          => $args['prix_vente'] ?? null,
            'date_expiration'     => $args['date_expiration'] ?? null,
        ], fn($v) => $v !== null));

        return $stock->fresh();
    }
}
