<?php

namespace App\GraphQL\Mutations;

use App\Models\Commande;
use App\Models\Consultation;
use App\Models\Paiement;
use App\Services\PaymentService;
use GraphQL\Error\Error;
use Illuminate\Support\Facades\DB;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class InitierPaiement
{
    public function __construct(private PaymentService $payment) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        $user = $context->user();

        $payable = match ($args['payable_type']) {
            'consultation' => Consultation::findOrFail($args['payable_id']),
            'commande'     => Commande::findOrFail($args['payable_id']),
            default        => throw new Error("Type payable invalide: {$args['payable_type']}"),
        };

        $montant = match ($args['payable_type']) {
            'consultation' => $payable->cout_consultation,
            'commande'     => $payable->montant_total + $payable->frais_livraison,
        };

        return DB::transaction(function () use ($args, $user, $payable, $montant) {
            $paiement = Paiement::create([
                'user_id'          => $user->id,
                'montant'          => $montant,
                'devise'           => 'XOF',
                'statut'           => 'en_attente',
                'methode_paiement' => strtolower($args['methode']),
                'payable_type'     => get_class($payable),
                'payable_id'       => $payable->id,
            ]);

            $methode = strtolower($args['methode']);
            $telephone = $args['telephone'] ?? $user->telephone;

            if (in_array($methode, ['orange_money', 'wave']) && ! $telephone) {
                throw new Error('Un numéro de téléphone est requis pour ce mode de paiement.');
            }

            $result = match ($methode) {
                'orange_money' => $this->payment->initOrangeMoney(
                    phone: $telephone,
                    amount: (int) $montant,
                    reference: $paiement->id,
                ),
                'wave' => $this->payment->initWave(
                    phone: $telephone,
                    amount: (int) $montant,
                    reference: $paiement->id,
                ),
                'stripe' => $this->payment->initStripe(
                    amount: (int) ($montant * 100),
                    currency: 'xof',
                    metadata: ['paiement_id' => $paiement->id],
                ),
                'cash' => [
                    'reference' => 'CASH-' . $paiement->id,
                    'message'   => 'Paiement en espèces enregistré. À régler lors de la consultation.',
                    '__type'    => 'PaiementMobileResponse',
                ],
                default => throw new Error("Méthode de paiement non supportée."),
            };

            $paiement->update([
                'reference_externe' => $result['reference'] ?? null,
                'metadata'          => $result,
            ]);

            return $result + ['paiement_id' => $paiement->id];
        });
    }
}
