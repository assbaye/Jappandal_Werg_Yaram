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
        $user    = $context->user();
        $patient = $user->patient;

        if (! $patient) {
            throw new Error('Seul un patient peut effectuer un paiement.');
        }

        // Le patient ne peut payer que SA consultation ou SA commande
        $payable = match ($args['payable_type']) {
            'consultation' => Consultation::where('patient_id', $patient->id)->find($args['payable_id']),
            'commande'     => Commande::where('patient_id', $patient->id)->find($args['payable_id']),
            default        => throw new Error('Type de paiement invalide.'),
        };
        if (! $payable) {
            throw new Error('Élément à payer introuvable.');
        }

        if (in_array($payable->statut, ['annulee', 'annule'], true)) {
            throw new Error('Cet élément a été annulé : il ne peut plus être payé.');
        }

        $dejaPaye = Paiement::where('payable_type', get_class($payable))
            ->where('payable_id', $payable->id)
            ->where('statut', 'confirme')
            ->exists();
        if ($dejaPaye) {
            throw new Error('Ce paiement a déjà été effectué.');
        }

        // Le montant vient toujours du serveur, jamais de l'application
        $montant = (int) round($payable instanceof Consultation
            ? $payable->cout_consultation
            : $payable->montant_total + $payable->frais_livraison);
        if ($montant <= 0) {
            throw new Error('Aucun montant à payer.');
        }

        $methode = strtolower($args['methode']);

        return DB::transaction(function () use ($methode, $user, $payable, $montant) {
            // Une seule tentative en attente par élément : la précédente est abandonnée
            Paiement::where('payable_type', get_class($payable))
                ->where('payable_id', $payable->id)
                ->where('statut', 'en_attente')
                ->update(['statut' => 'echec']);

            $paiement = Paiement::create([
                'user_id'          => $user->id,
                'montant'          => $montant,
                'devise'           => 'XOF',
                'statut'           => 'en_attente',
                'methode_paiement' => $methode,
                'payable_type'     => get_class($payable),
                'payable_id'       => $payable->id,
            ]);

            $result = match ($methode) {
                'wave' => $this->payment->initWave(amount: $montant, reference: $paiement->id),
                'orange_money' => $this->payment->initOrangeMoney(
                    phone: $user->telephone ?? throw new Error('Ajoutez un numéro de téléphone à votre profil.'),
                    amount: $montant,
                    reference: $paiement->id,
                ),
                'stripe' => $this->payment->initStripe(
                    amount: $montant * 100,
                    currency: 'xof',
                    metadata: ['paiement_id' => $paiement->id],
                ),
                // Espèces : reste « en attente » jusqu'à l'encaissement réel
                'cash' => [
                    'reference' => 'CASH-' . $paiement->id,
                    'message'   => 'Paiement en espèces enregistré. À régler lors de la consultation.',
                    '__type'    => 'PaiementMobileResponse',
                ],
                default => throw new Error('Méthode de paiement non supportée.'),
            };

            $paiement->update([
                'reference_externe' => $result['reference'] ?? null,
                'metadata'          => array_diff_key($result, array_flip(['__type'])),
            ]);

            return $result + ['paiement_id' => $paiement->id];
        });
    }
}
