<?php

namespace App\GraphQL\Mutations;

use App\Models\Medicament;
use App\Models\StockMedicament;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

/**
 * Met à jour (ou ajoute) un médicament dans le stock de la pharmacie du pharmacien connecté.
 */
class UpdateStock
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): StockMedicament
    {
        $pharmacie = $context->user()->pharmacien?->pharmacies()->first();

        if (! $pharmacie) {
            throw new Error('Accès réservé aux pharmaciens rattachés à une pharmacie.');
        }

        $medicament = Medicament::findOrFail($args['medicament_id']);

        $stock = StockMedicament::firstOrNew([
            'pharmacie_id'  => $pharmacie->id,
            'medicament_id' => $medicament->id,
        ]);

        $stock->fill(array_filter([
            'quantite_disponible' => $args['quantite_disponible'],
            'prix_vente'          => $args['prix_vente'] ?? null,
            'quantite_minimale'   => $args['quantite_minimale'] ?? null,
            'date_expiration'     => $args['date_expiration'] ?? null,
        ], fn ($v) => $v !== null));

        // Valeurs par défaut pour un médicament ajouté au stock
        $stock->prix_vente        ??= $medicament->prix_unitaire;
        $stock->quantite_minimale ??= 10;

        $stock->save();

        return $stock->fresh(['medicament', 'pharmacie']);
    }
}
