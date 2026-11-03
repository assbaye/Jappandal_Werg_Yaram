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
     * Initier un paiement Wave (Sénégal).
     * Docs : https://docs.wave.com/
     *
     * @return array{reference: string, payment_url: string, message: string}
     */
    public function initWave(string $phone, int $amount, int|string $reference): array
    {
        $apiKey = config('services.wave.api_key');

        if (! $apiKey) {
            throw new \GraphQL\Error\Error('Wave n\'est pas encore configuré sur le serveur.');
        }

        $response = Http::withHeaders([
            'Authorization' => "Bearer {$apiKey}",
            'Content-Type'  => 'application/json',
        ])->post(config('services.wave.api_url') . '/checkout/sessions', [
            'currency'        => 'XOF',
            'amount'          => (string) $amount,
            'client_reference' => 'JWY-' . $reference,
            'success_url'     => config('app.url') . '/payment/success',
            'error_url'       => config('app.url') . '/payment/error',
        ]);

        $data = $response->json();

        return [
            'reference'   => $data['id'] ?? (string) $reference,
            'payment_url' => $data['wave_launch_url'] ?? null,
            'message'     => 'Paiement Wave initié. Utilisez le lien pour payer.',
            '__type'      => 'PaiementMobileResponse',
        ];
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
