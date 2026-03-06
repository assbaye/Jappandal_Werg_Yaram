<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('commandes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('patient_id')->constrained()->restrictOnDelete();
            $table->foreignId('pharmacie_id')->constrained()->restrictOnDelete();
            $table->foreignId('prescription_id')->nullable()->constrained()->nullOnDelete();
            $table->string('numero_commande')->unique();
            $table->enum('statut', [
                'en_attente',
                'confirmee',
                'en_preparation',
                'prete',
                'en_livraison',
                'livree',
                'annulee'
            ])->default('en_attente');
            $table->enum('type_livraison', ['retrait', 'livraison'])->default('retrait');
            $table->text('adresse_livraison')->nullable();
            $table->decimal('montant_total', 10, 2)->default(0);
            $table->decimal('frais_livraison', 10, 2)->default(0);
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['patient_id', 'statut']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('commandes');
    }
};
