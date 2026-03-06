<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pharmacies', function (Blueprint $table) {
            $table->id();
            $table->string('nom_pharmacie');
            $table->text('adresse');
            $table->string('telephone', 20)->nullable();
            $table->string('email')->nullable();
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->jsonb('heures_ouverture')->default('{}');
            $table->boolean('est_partenaire')->default(false);
            $table->boolean('est_active')->default(true);
            $table->boolean('livraison_disponible')->default(false);
            $table->decimal('taux_commission', 5, 2)->default(5.00);
            $table->string('photo')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['latitude', 'longitude']);
            $table->index('est_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pharmacies');
    }
};
