<?php

namespace App\Services;

use App\Models\Consultation;
use App\Models\Facture;
use App\Models\Paiement;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Seul point d'entrée qui fait passer un paiement Wave à « confirmé » ou « échec ».
 *
 * Il ne fait confiance qu'à une session Checkout relue auprès de Wave (webhook signé
 * ou vérification serveur) — jamais à l'application mobile.
 */
class ConfirmationPaiementService
{
    public function __construct(
        private PaymentService $payment,
        private NotificationService $notif,
    ) {}

    /**
     * Relit la session Wave du paiement et met à jour son statut. Idempotent.
     */
    public function synchroniserWave(Paiement $paiement): Paiement
    {
        if ($paiement->methode_paiement !== 'wave' || $paiement->statut !== 'en_attente' || ! $paiement->reference_externe) {
            return $paiement;
        }

        $session = $this->payment->getWaveSession($paiement->reference_externe);
        if ($session === null) {
            return $paiement; // Wave injoignable : on réessaiera
        }

        if (($session['payment_status'] ?? null) === 'succeeded') {
            return $this->confirmer($paiement, $session);
        }

        // Session expirée sans paiement réussi, ou paiement annulé
        if (($session['checkout_status'] ?? null) === 'expired' || ($session['payment_status'] ?? null) === 'cancelled') {
            return $this->echouer($paiement, $session);
        }

        return $paiement; // « processing » : toujours en cours
    }

    private function confirmer(Paiement $paiement, array $session): Paiement
    {
        // La session doit correspondre exactement au paiement attendu
        $montantAttendu = (string) (int) round((float) $paiement->montant);
        if (($session['id'] ?? null) !== $paiement->reference_externe
            || (string) ($session['amount'] ?? '') !== $montantAttendu
            || ($session['currency'] ?? null) !== 'XOF') {
            Log::critical('Wave : session incohérente avec le paiement', [
                'paiement_id' => $paiement->id,
                'session_id'  => $session['id'] ?? null,
                'montant'     => $session['amount'] ?? null,
            ]);

            return $paiement;
        }

        $confirme = DB::transaction(function () use ($paiement, $session) {
            /** @var Paiement $p */
            $p = Paiement::lockForUpdate()->find($paiement->id);
            if ($p->statut !== 'en_attente') {
                return null; // déjà traité (webhook en double, vérification concurrente)
            }

            $p->update([
                'statut'             => 'confirme',
                'numero_transaction' => $session['transaction_id'] ?? null,
                'confirme_le'        => now(),
            ]);

            Facture::firstOrCreate(['paiement_id' => $p->id], [
                'numero_facture' => sprintf('FAC-%s-%06d', now()->format('Y'), $p->id),
                'date_emission'  => now(),
                'montant_ht'     => $p->montant,
                'tva'            => 0, // à paramétrer selon le régime fiscal des actes
                'montant_ttc'    => $p->montant,
                'statut'         => 'payee',
            ]);

            return $p;
        });

        if ($confirme === null) {
            return $paiement->fresh();
        }

        $objet = $confirme->payable instanceof Consultation ? 'votre consultation' : 'votre commande';
        $this->notif->sendToUser(
            userId: $confirme->user_id,
            titre: 'Paiement confirmé',
            message: 'Votre paiement Wave de ' . number_format((float) $confirme->montant, 0, ',', ' ') . " FCFA pour {$objet} est confirmé.",
            type: 'paiement',
            data: ['paiement_id' => $confirme->id],
        );

        return $confirme->fresh();
    }

    private function echouer(Paiement $paiement, array $session): Paiement
    {
        $modifie = Paiement::where('id', $paiement->id)
            ->where('statut', 'en_attente')
            ->update(['statut' => 'echec', 'metadata' => array_merge($paiement->metadata ?? [], [
                'checkout_status' => $session['checkout_status'] ?? null,
                'payment_status'  => $session['payment_status'] ?? null,
            ])]);

        if ($modifie) {
            $this->notif->sendToUser(
                userId: $paiement->user_id,
                titre: 'Paiement non abouti',
                message: 'Votre paiement Wave n\'a pas abouti. Vous pouvez réessayer depuis l\'application.',
                type: 'paiement',
                data: ['paiement_id' => $paiement->id],
            );
        }

        return $paiement->fresh();
    }
}
