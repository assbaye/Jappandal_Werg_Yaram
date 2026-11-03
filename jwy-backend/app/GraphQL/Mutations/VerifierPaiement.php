<?php

namespace App\GraphQL\Mutations;

use App\Models\Paiement;
use App\Services\ConfirmationPaiementService;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

/**
 * L'app demande où en est un paiement ; le serveur interroge Wave et met à jour le statut.
 * Complément du webhook (s'il est en retard ou n'a pas pu joindre le serveur).
 */
class VerifierPaiement
{
    public function __construct(private ConfirmationPaiementService $confirmation) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): Paiement
    {
        $paiement = Paiement::where('user_id', $context->user()->id)->find($args['paiement_id']);

        if (! $paiement) {
            throw new Error('Paiement introuvable.');
        }

        return $this->confirmation->synchroniserWave($paiement)->load('facture');
    }
}
