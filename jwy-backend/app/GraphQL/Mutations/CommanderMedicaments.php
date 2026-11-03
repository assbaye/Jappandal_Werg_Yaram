<?php

namespace App\GraphQL\Mutations;

use App\Models\Commande;
use App\Models\Medicament;
use App\Models\Pharmacie;
use App\Models\Prescription;
use App\Models\StockMedicament;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Illuminate\Support\Facades\DB;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class CommanderMedicaments
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): Commande
    {
        $patient = $context->user()->patient;

        if (! $patient) {
            throw new Error('Seuls les patients peuvent passer une commande.');
        }

        if (empty($args['medicaments'])) {
            throw new Error('La commande ne contient aucun médicament.');
        }

        $pharmacie = Pharmacie::where('est_active', true)->findOrFail($args['pharmacie_id']);

        $typeLivraison = strtolower($args['type_livraison'] ?? 'retrait');
        if ($typeLivraison === 'livraison') {
            if (! $pharmacie->livraison_disponible) {
                throw new Error('Cette pharmacie ne propose pas la livraison.');
            }
            if (empty($args['adresse_livraison'])) {
                throw new Error('Indiquez une adresse de livraison.');
            }
        }

        // Médicaments couverts par l'ordonnance (si fournie)
        $prescrits = collect();
        if (! empty($args['prescription_id'])) {
            $prescription = Prescription::with('medicamentsPrescrits')->findOrFail($args['prescription_id']);
            if ($prescription->patient_id !== $patient->id) {
                throw new Error('Cette ordonnance ne vous appartient pas.');
            }
            $prescrits = $prescription->medicamentsPrescrits->pluck('medicament_id');
        }

        $commande = DB::transaction(function () use ($args, $patient, $pharmacie, $typeLivraison, $prescrits) {
            $montantTotal = 0;
            $lignes       = [];

            foreach ($args['medicaments'] as $ligne) {
                $medicament = Medicament::findOrFail($ligne['medicament_id']);

                if ($medicament->necessite_ordonnance && ! $prescrits->contains($medicament->id)) {
                    throw new Error("{$medicament->nom_commercial} nécessite une ordonnance.");
                }

                $stock = StockMedicament::where('pharmacie_id', $pharmacie->id)
                    ->where('medicament_id', $medicament->id)
                    ->lockForUpdate()
                    ->first();

                if (! $stock || $stock->quantite_disponible < $ligne['quantite']) {
                    $dispo = $stock?->quantite_disponible ?? 0;
                    throw new Error("Stock insuffisant pour {$medicament->nom_commercial} ({$dispo} disponible(s)).");
                }

                $montantTotal += $stock->prix_vente * $ligne['quantite'];
                $lignes[$medicament->id] = [
                    'quantite'      => $ligne['quantite'],
                    'prix_unitaire' => $stock->prix_vente,
                ];

                // Réservé dès la commande, rendu au stock si elle est annulée
                $stock->decrement('quantite_disponible', $ligne['quantite']);
            }

            $commande = Commande::create([
                'patient_id'        => $patient->id,
                'pharmacie_id'      => $pharmacie->id,
                'prescription_id'   => $args['prescription_id'] ?? null,
                'statut'            => 'en_attente',
                'type_livraison'    => $typeLivraison,
                'adresse_livraison' => $args['adresse_livraison'] ?? null,
                'montant_total'     => $montantTotal,
                'frais_livraison'   => $typeLivraison === 'livraison' ? 1000 : 0,
            ]);

            $commande->medicaments()->attach($lignes);

            return $commande;
        });

        foreach ($pharmacie->pharmaciens as $pharmacien) {
            $this->notif->sendToUser(
                userId: $pharmacien->user_id,
                titre: 'Nouvelle commande',
                message: "{$patient->nom_complet} a passé la commande {$commande->numero_commande}.",
                type: 'commande',
                data: ['commande_id' => $commande->id],
            );
        }

        return $commande;
    }
}
