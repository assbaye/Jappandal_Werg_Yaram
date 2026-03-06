<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('factures', function (Blueprint $table) {
            $table->id();
            $table->foreignId('paiement_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('numero_facture')->unique();
            $table->timestamp('date_emission');
            $table->timestamp('date_echeance')->nullable();
            $table->decimal('montant_ht', 10, 2);
            $table->decimal('tva', 5, 2)->default(18.00);
            $table->decimal('montant_ttc', 10, 2);
            $table->enum('statut', ['emise', 'payee', 'annulee'])->default('emise');
            $table->string('pdf_url')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('factures');
    }
};
