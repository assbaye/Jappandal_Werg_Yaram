<?php

namespace App\GraphQL\Mutations;

use App\Models\Commande;
use App\Models\StockMedicament;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Illuminate\Support\Facades\DB;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class UpdateStatutCommande
{
    /** Étapes autorisées depuis chaque statut */
    private const TRANSITIONS = [
        'en_attente'     => ['confirmee', 'annulee'],
        'confirmee'      => ['en_preparation', 'annulee'],
        'en_preparation' => ['prete', 'annulee'],
        'prete'          => ['en_livraison', 'livree'],
        'en_livraison'   => ['livree'],
    ];

    private const MESSAGES = [
        'confirmee'      => 'a été acceptée par la pharmacie.',
        'en_preparation' => 'est en cours de préparation.',
        'prete'          => 'est prête.',
        'en_livraison'   => 'est en cours de livraison.',
        'livree'         => 'a été remise. Merci !',
        'annulee'        => 'a été annulée par la pharmacie.',
    ];

    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): Commande
    {
        $user     = $context->user();
        $commande = Commande::with('medicaments', 'patient', 'pharmacie')->findOrFail($args['id']);

        $autorise = $user->hasRole('admin')
            || $user->pharmacien?->pharmacies->contains('id', $commande->pharmacie_id);

        if (! $autorise) {
            throw new Error('Cette commande ne concerne pas votre pharmacie.');
        }

        $nouveau = strtolower($args['statut']);

        if (! in_array($nouveau, self::TRANSITIONS[$commande->statut] ?? [])) {
            throw new Error('Cette étape n\'est pas possible pour une commande à ce stade.');
        }

        if ($nouveau === 'en_livraison' && $commande->type_livraison !== 'livraison') {
            throw new Error('Cette commande est à retirer en pharmacie, pas à livrer.');
        }

        DB::transaction(function () use ($commande, $nouveau) {
            // Annulation : les médicaments réservés retournent en stock
            if ($nouveau === 'annulee') {
                foreach ($commande->medicaments as $m) {
                    StockMedicament::where('pharmacie_id', $commande->pharmacie_id)
                        ->where('medicament_id', $m->id)
                        ->increment('quantite_disponible', $m->pivot->quantite);
                }
            }

            $commande->update(['statut' => $nouveau]);
        });

        $message = $nouveau === 'prete' && $commande->type_livraison === 'retrait'
            ? 'est prête : vous pouvez la retirer à la pharmacie.'
            : self::MESSAGES[$nouveau];

        $this->notif->sendToUser(
            userId: $commande->patient->user_id,
            titre: 'Commande ' . $commande->numero_commande,
            message: "Votre commande chez {$commande->pharmacie->nom_pharmacie} {$message}",
            type: 'commande',
            data: ['commande_id' => $commande->id],
        );

        return $commande->fresh();
    }
}
