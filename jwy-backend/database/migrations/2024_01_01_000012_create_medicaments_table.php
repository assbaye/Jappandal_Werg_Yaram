<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('medicaments', function (Blueprint $table) {
            $table->id();
            $table->string('nom_commercial');
            $table->string('principe_actif');
            $table->string('dosage')->nullable();
            $table->enum('forme', ['comprime', 'gelule', 'sirop', 'injectable', 'creme', 'autre'])->default('comprime');
            $table->string('fabricant')->nullable();
            $table->decimal('prix_unitaire', 10, 2)->default(0);
            $table->string('code_barre')->nullable()->unique();
            $table->boolean('necessite_ordonnance')->default(false);
            $table->text('description')->nullable();
            $table->jsonb('contre_indications')->default('[]');
            $table->jsonb('effets_secondaires')->default('[]');
            $table->timestamps();
            $table->softDeletes();

            $table->index('nom_commercial');
            $table->index('principe_actif');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('medicaments');
    }
};
