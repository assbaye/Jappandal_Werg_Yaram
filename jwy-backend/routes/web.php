<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// ─── Paiements Wave ──────────────────────────────────────────────────────────

// Webhook Wave : authentifié par signature (exempté de CSRF dans bootstrap/app.php)
Route::post('/webhooks/wave', \App\Http\Controllers\WaveWebhookController::class)
    ->middleware('throttle:60,1');

// Page affichée par Wave après le paiement. Purement informative : le statut
// réel n'est établi que par le webhook signé ou la vérification serveur.
Route::get('/paiement/retour', fn (\Illuminate\Http\Request $r) => view('paiement-retour', [
    'succes' => $r->query('statut') === 'succes',
]));
