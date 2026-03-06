<?php

namespace App\GraphQL\Mutations;

use App\Models\Commande;
use App\Models\StockMedicament;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Support\Facades\DB;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class CommanderMedicaments
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Commande
    {
        $user    = $context->user();
        $patient = $user->patient;

        abort_if(!$patient, 403, 'Seuls les patients peuvent passer une commande.');

        return DB::transaction(function () use ($args, $patient) {
            $montantTotal = 0;
            $lignes       = [];

            foreach ($args['medicaments'] as $ligne) {
                $stock = StockMedicament::where('pharmacie_id', $args['pharmacie_id'])
                    ->where('medicament_id', $ligne['medicament_id'])
                    ->where('quantite_disponible', '>=', $ligne['quantite'])
                    ->firstOrFail();

                $sousTotal     = $stock->prix_vente * $ligne['quantite'];
                $montantTotal += $sousTotal;
                $lignes[]      = [
                    'medicament_id' => $ligne['medicament_id'],
                    'quantite'      => $ligne['quantite'],
                    'prix_unitaire' => $stock->prix_vente,
                ];

                $stock->decrement('quantite_disponible', $ligne['quantite']);
            }

            $commande = Commande::create([
                'patient_id'       => $patient->id,
                'pharmacie_id'     => $args['pharmacie_id'],
                'numero_commande'  => 'CMD-' . strtoupper(uniqid()),
                'statut'           => 'en_attente',
                'type_livraison'   => $args['type_livraison'] ?? 'retrait',
                'adresse_livraison' => $args['adresse_livraison'] ?? null,
                'montant_total'    => $montantTotal,
                'frais_livraison'  => 0,
            ]);

            foreach ($lignes as $ligne) {
                $commande->medicaments()->attach($ligne['medicament_id'], [
                    'quantite'      => $ligne['quantite'],
                    'prix_unitaire' => $ligne['prix_unitaire'],
                ]);
            }

            return $commande;
        });
    }
}
