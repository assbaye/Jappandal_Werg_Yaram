<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pharmacies', function (Blueprint $table) {
            // Pharmacie de garde jusqu'à cette date (null = pas de garde)
            $table->timestamp('de_garde_jusqu_au')->nullable()->after('livraison_disponible');
        });
    }

    public function down(): void
    {
        Schema::table('pharmacies', function (Blueprint $table) {
            $table->dropColumn('de_garde_jusqu_au');
        });
    }
};
