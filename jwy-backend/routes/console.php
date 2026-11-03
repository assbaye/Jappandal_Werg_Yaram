<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Déplace les pharmacies de test autour d'un point (tests hors du Sénégal).
// Les positions relatives sont conservées : on translate le barycentre vers le point cible.
Artisan::command('jwy:position-demo {latitude?} {longitude?} {--dakar : Remettre les pharmacies à Dakar}', function () {
    $dakar = [14.7209, -17.4375]; // barycentre des pharmacies du PharmacieSeeder

    if ($this->option('dakar')) {
        [$lat, $lng] = $dakar;
    } elseif ($this->argument('latitude') !== null && $this->argument('longitude') !== null) {
        [$lat, $lng] = [(float) $this->argument('latitude'), (float) $this->argument('longitude')];
    } else {
        $this->error('Usage : php artisan jwy:position-demo <latitude> <longitude>  |  --dakar');
        return 1;
    }

    $pharmacies = \App\Models\Pharmacie::all();
    if ($pharmacies->isEmpty()) {
        $this->warn('Aucune pharmacie en base (lancez php artisan db:seed).');
        return 1;
    }

    $dLat = $lat - $pharmacies->avg(fn ($p) => (float) $p->latitude);
    $dLng = $lng - $pharmacies->avg(fn ($p) => (float) $p->longitude);

    foreach ($pharmacies as $p) {
        $p->update([
            'latitude'  => round((float) $p->latitude + $dLat, 7),
            'longitude' => round((float) $p->longitude + $dLng, 7),
        ]);
        $this->line("  {$p->nom_pharmacie} → {$p->latitude}, {$p->longitude}");
    }

    $this->info("{$pharmacies->count()} pharmacie(s) déplacée(s) autour de {$lat}, {$lng}.");
})->purpose('Déplacer les pharmacies de test autour d\'une position');
