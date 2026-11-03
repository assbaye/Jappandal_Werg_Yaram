<?php

namespace App\Http\Controllers;

use App\Models\Paiement;
use App\Services\ConfirmationPaiementService;
use App\Services\PaymentService;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Webhooks Wave (checkout.session.completed / checkout.session.payment_failed).
 * Docs : https://docs.wave.com/webhook
 */
class WaveWebhookController
{
    public function __invoke(Request $request, PaymentService $payment, ConfirmationPaiementService $confirmation): Response
    {
        // Corps brut, non re-sérialisé : la signature porte sur les octets exacts
        $corps = $request->getContent();

        if (! $payment->verifyWaveWebhook($corps, $request->header('Wave-Signature'))) {
            Log::warning('Webhook Wave rejeté : signature invalide', ['ip' => $request->ip()]);

            return response('Signature invalide', 401);
        }

        $evenement = json_decode($corps, true);
        $id        = $evenement['id'] ?? null;
        $type      = $evenement['type'] ?? null;
        $sessionId = $evenement['data']['id'] ?? null;

        // Wave peut renvoyer un même événement : on ne le traite qu'une fois
        if (! $id || ! Cache::add("wave-webhook:{$id}", true, now()->addDays(4))) {
            return response('Déjà traité', 200);
        }

        if (in_array($type, ['checkout.session.completed', 'checkout.session.payment_failed'], true) && $sessionId) {
            $paiement = Paiement::where('methode_paiement', 'wave')->where('reference_externe', $sessionId)->first();

            if ($paiement) {
                // Répondre sous 5 s : la relecture de la session se fait après la réponse.
                // Le statut vient de Wave lui-même, pas du contenu du webhook.
                dispatch(fn () => app(ConfirmationPaiementService::class)->synchroniserWave($paiement))->afterResponse();
            } else {
                Log::warning('Webhook Wave : session inconnue', ['session' => $sessionId]);
            }
        }

        return response('OK', 200);
    }
}
