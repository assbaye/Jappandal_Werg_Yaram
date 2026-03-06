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

            $result = match (strtolower($args['methode'])) {
                'orange_money' => $this->payment->initOrangeMoney(
                    phone: $args['telephone'],
                    amount: (int) $montant,
                    reference: $paiement->id,
                ),
                'wave' => $this->payment->initWave(
                    phone: $args['telephone'],
                    amount: (int) $montant,
                    reference: $paiement->id,
                ),
                'stripe' => $this->payment->initStripe(
                    amount: (int) ($montant * 100),
                    currency: 'xof',
                    metadata: ['paiement_id' => $paiement->id],
                ),
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
