<?php

return [

    // ─── Claude (Anthropic) : assistant de pré-orientation ───────────────────
    'anthropic' => [
        'api_key' => env('ANTHROPIC_API_KEY'),
        'model'   => env('ANTHROPIC_MODEL', 'claude-opus-5-5'),
        // Analyses par patient et par heure (maîtrise des coûts)
        'triages_par_heure' => (int) env('ANTHROPIC_TRIAGES_PAR_HEURE', 10),
    ],

    // ─── Agora.io ─────────────────────────────────────────────────────────────
    'agora' => [
        'app_id'          => env('AGORA_APP_ID'),
        'app_certificate' => env('AGORA_APP_CERTIFICATE'),
        'token_expiry'    => (int) env('AGORA_TOKEN_EXPIRY', 3600),
    ],

    // ─── Stripe ───────────────────────────────────────────────────────────────
    'stripe' => [
        'key'            => env('STRIPE_KEY'),
        'secret'         => env('STRIPE_SECRET'),
        'webhook_secret' => env('STRIPE_WEBHOOK_SECRET'),
    ],

    // ─── Orange Money Sénégal ─────────────────────────────────────────────────
    'orange_money' => [
        'url'          => env('ORANGE_MONEY_URL', 'https://api.orange.com/orange-money-webpay/sn/v1'),
        'merchant_key' => env('ORANGE_MONEY_MERCHANT_KEY'),
        'auth_token'   => env('ORANGE_MONEY_AUTH_TOKEN'),
        'notif_url'    => env('ORANGE_MONEY_NOTIF_URL'),
    ],

    // ─── Wave Sénégal ─────────────────────────────────────────────────────────
    'wave' => [
        'api_url'        => env('WAVE_API_URL', 'https://api.wave.com/v1'),
        'api_key'        => env('WAVE_API_KEY'),
        'webhook_secret' => env('WAVE_WEBHOOK_SECRET'),
    ],

    // ─── Firebase Cloud Messaging ─────────────────────────────────────────────
    'fcm' => [
        'server_key' => env('FCM_SERVER_KEY'),
    ],

    // ─── Mailgun ──────────────────────────────────────────────────────────────
    'mailgun' => [
        'domain'    => env('MAILGUN_DOMAIN'),
        'secret'    => env('MAILGUN_SECRET'),
        'endpoint'  => env('MAILGUN_ENDPOINT', 'api.mailgun.net'),
        'scheme'    => 'https',
    ],

];
