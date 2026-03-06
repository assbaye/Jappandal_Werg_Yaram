<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications_jwy', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('titre');
            $table->text('message');
            $table->enum('type', [
                'rendez_vous',
                'consultation',
                'prescription',
                'paiement',
                'commande',
                'alerte_sante',
                'rappel_medicament',
                'urgence',
                'systeme'
            ])->default('systeme');
            $table->enum('priorite', ['faible', 'normale', 'haute', 'urgente'])->default('normale');
            $table->boolean('est_lue')->default(false);
            $table->timestamp('lue_le')->nullable();
            $table->jsonb('data')->default('{}');
            $table->string('action_url')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'est_lue']);
            $table->index('type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications_jwy');
    }
};
