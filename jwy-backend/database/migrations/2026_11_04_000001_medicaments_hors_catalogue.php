<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lignes d'ordonnance « hors catalogue » : le médecin peut prescrire un médicament
 * absent du catalogue JWY en saisissant son nom (medicament_id reste alors vide).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('medicaments_prescrits', function (Blueprint $table) {
            $table->foreignId('medicament_id')->nullable()->change();
            $table->string('nom_libre', 150)->nullable()->after('medicament_id');
        });
    }

    public function down(): void
    {
        Schema::table('medicaments_prescrits', function (Blueprint $table) {
            $table->dropColumn('nom_libre');
            $table->foreignId('medicament_id')->nullable(false)->change();
        });
    }
};
