<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Stripe\PaymentIntent;
use Stripe\Stripe;

/**
 * Service unifié de paiement : Orange Money, Wave, Stripe
 */
class PaymentService
{
    // ─── Orange Money Sénégal ─────────────────────────────────────────────────

    /**
     * Initier un paiement Orange Money (Sénégal).
     * Docs : https://developer.orange.com/apis/om-webpay-sn-prod/
     *
     * @return array{reference: string, payment_url: string, message: string}
     */
    public function initOrangeMoney(string $phone, int $amount, int|string $reference): array
    {
        $baseUrl = config('services.orange_money.url');
        $token   = config('services.orange_money.auth_token');
        $merchant = config('services.orange_money.merchant_key');

        if (! $token || ! $merchant) {
            throw new \GraphQL\Error\Error('Orange Money n\'est pas encore configuré sur le serveur.');
        }

        $response = Http::withToken($token)
            ->post("{$baseUrl}/webpayment", [
                'merchant_key'   => $merchant,
                'currency'       => 'ORA',
                'order_id'       => (string) $reference,
                'amount'         => $amount,
                'return_url'     => config('services.orange_money.notif_url'),
                'cancel_url'     => config('services.orange_money.notif_url'),
                'notif_url'      => config('services.orange_money.notif_url'),
                'lang'           => 'fr',
                'reference'      => 'JWY-' . $reference,
            ]);

        $data = $response->json();

        return [
            'reference'   => $data['pay_token'] ?? (string) $reference,
            'payment_url' => $data['payment_url'] ?? null,
            'ussd_code'   => isset($data['pay_token']) ? "#144*82*{$data['pay_token']}#" : null,
            'message'     => 'Paiement Orange Money initié. Composez le code USSD ou utilisez le lien.',
            '__type'      => 'PaiementMobileResponse',
        ];
    }

    // ─── Wave Sénégal ─────────────────────────────────────────────────────────

    /**
     * Créer une session Checkout Wave. Docs : https://docs.wave.com/checkout
     *
     * Le paiement n'est PAS confirmé ici : seul le webhook signé de Wave (ou une
     * vérification serveur de la session) peut le passer à « confirmé ».
     *
     * @return array{reference: string, payment_url: string, message: string, __type: string}
     */
    public function initWave(int $amount, int|string $reference): array
    {
        $apiKey = config('services.wave.api_key');
        $retour = rtrim((string) config('services.wave.url_retour'), '/');

        if (! $apiKey) {
            throw new \GraphQL\Error\Error('Wave n\'est pas encore configuré sur le serveur.');
        }
        if (! str_starts_with($retour, 'https://')) {
            // Wave refuse les adresses de retour qui ne sont pas en https
            throw new \GraphQL\Error\Error('Wave n\'est pas encore configuré sur le serveur (WAVE_URL_RETOUR doit être une adresse https).');
        }
        if ($amount <= 0) {
            throw new \GraphQL\Error\Error('Montant invalide pour un paiement Wave.');
        }

        $response = Http::withToken($apiKey)
            ->acceptJson()
            ->timeout(20)
            ->post(config('services.wave.api_url') . '/checkout/sessions', [
                'amount'           => (string) $amount,   // XOF : entier, sans décimales
                'currency'         => 'XOF',
                'client_reference' => 'JWY-' . $reference,
                'success_url'      => "{$retour}/paiement/retour?statut=succes",
                'error_url'        => "{$retour}/paiement/retour?statut=echec",
            ]);

        if (! $response->successful() || empty($response->json('wave_launch_url'))) {
            \Illuminate\Support\Facades\Log::error('Wave : création de session refusée', [
                'status' => $response->status(),
                'code'   => $response->json('code'),
            ]);
            throw new \GraphQL\Error\Error('Wave a refusé la demande de paiement. Réessayez plus tard.');
        }

        return [
            'reference'   => $response->json('id'),            // cos-…
            'payment_url' => $response->json('wave_launch_url'),
            'message'     => 'Finalisez le paiement dans l\'application Wave, puis revenez dans JWY.',
            '__type'      => 'PaiementMobileResponse',
        ];
    }

    /**
     * Relire une session Checkout auprès de Wave (source de vérité pour le statut).
     */
    public function getWaveSession(string $sessionId): ?array
    {
        $apiKey = config('services.wave.api_key');
        if (! $apiKey || ! str_starts_with($sessionId, 'cos-')) {
            return null;
        }

        $response = Http::withToken($apiKey)
            ->acceptJson()
            ->timeout(15)
            ->get(config('services.wave.api_url') . '/checkout/sessions/' . rawurlencode($sessionId));

        return $response->successful() ? $response->json() : null;
    }

    /**
     * Vérifier la signature d'un webhook Wave (en-tête « Wave-Signature: t=…,v1=… »).
     * Docs : https://docs.wave.com/webhook — HMAC-SHA256 de « timestamp + corps brut ».
     */
    public function verifyWaveWebhook(string $rawBody, ?string $header): bool
    {
        $secret = config('services.wave.webhook_secret');
        if (! $secret || ! $header) {
            return false;
        }

        $timestamp = null;
        $signatures = [];
        foreach (explode(',', $header) as $part) {
            [$cle, $valeur] = array_pad(explode('=', trim($part), 2), 2, null);
            if ($cle === 't') {
                $timestamp = $valeur;
            } elseif ($cle === 'v1' && $valeur) {
                $signatures[] = $valeur; // plusieurs v1 possibles pendant une rotation de clé
            }
        }

        // Rejeter les requêtes de plus de 5 minutes (anti-rejeu)
        if (! ctype_digit((string) $timestamp) || abs(time() - (int) $timestamp) > 300) {
            return false;
        }

        $attendue = hash_hmac('sha256', $timestamp . $rawBody, $secret);
        foreach ($signatures as $signature) {
            if (hash_equals($attendue, $signature)) {
                return true;
            }
        }

        return false;
    }

    // ─── Stripe ───────────────────────────────────────────────────────────────

    /**
     * Créer un PaymentIntent Stripe.
     * Le Flutter SDK utilisera le client_secret pour finaliser le paiement.
     *
     * @return array{client_secret: string, publishable_key: string}
     */
    public function initStripe(int $amount, string $currency, array $metadata = []): array
    {
        Stripe::setApiKey(config('services.stripe.secret'));

        $intent = PaymentIntent::create([
            'amount'   => $amount,
            'currency' => $currency,
            'metadata' => $metadata,
            'payment_method_types' => ['card'],
        ]);

        return [
            'reference'       => $intent->id,
            'client_secret'   => $intent->client_secret,
            'publishable_key' => config('services.stripe.key'),
            'message'         => 'PaymentIntent Stripe créé.',
            '__type'          => 'PaiementStripeResponse',
        ];
    }

    // ─── Vérification Webhook ─────────────────────────────────────────────────

    /**
     * Vérifier la signature d'un webhook Stripe.
     */
    public function verifyStripeWebhook(string $payload, string $signature): ?\Stripe\Event
    {
        try {
            return \Stripe\Webhook::constructEvent(
                $payload,
                $signature,
                config('services.stripe.webhook_secret')
            );
        } catch (\Exception) {
            return null;
        }
    }
}
