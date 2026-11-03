<?php

namespace App\GraphQL\Fields;

use App\Models\Commande;

class LignesCommande
{
    public function __invoke(Commande $commande): array
    {
        return $commande->medicaments->map(fn ($m) => [
            'medicament'    => $m,
            'quantite'      => (int) $m->pivot->quantite,
            'prix_unitaire' => (float) $m->pivot->prix_unitaire,
        ])->all();
    }
}
