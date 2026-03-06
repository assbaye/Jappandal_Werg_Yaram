<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('paiements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->decimal('montant', 10, 2);
            $table->string('devise', 3)->default('XOF');
            $table->enum('statut', ['en_attente', 'confirme', 'echec', 'rembourse'])->default('en_attente');
            $table->enum('methode_paiement', ['orange_money', 'wave', 'stripe', 'cash'])->default('orange_money');
            $table->string('numero_transaction')->nullable()->unique();
            $table->string('reference_externe')->nullable();
            $table->decimal('frais_transaction', 10, 2)->default(0);
            // Polymorphique : consultation ou commande
            $table->nullableMorphs('payable');
            $table->jsonb('metadata')->default('{}');
            $table->timestamp('confirme_le')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'statut']);
            $table->index('methode_paiement');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('paiements');
    }
};
