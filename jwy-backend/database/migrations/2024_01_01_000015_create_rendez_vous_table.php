<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rendez_vous', function (Blueprint $table) {
            $table->id();
            $table->foreignId('patient_id')->constrained()->cascadeOnDelete();
            $table->foreignId('medecin_id')->constrained()->cascadeOnDelete();
            $table->timestamp('date_rendez_vous');
            $table->integer('duree_estimee')->default(30);
            $table->enum('statut', ['en_attente', 'confirme', 'reporte', 'annule', 'termine'])->default('en_attente');
            $table->enum('type_rendez_vous', ['video', 'chat', 'physique'])->default('video');
            $table->string('lieu_rendez_vous')->nullable();
            $table->text('motif')->nullable();
            $table->boolean('rappel_envoye')->default(false);
            $table->timestamp('rappel_envoye_le')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['patient_id', 'statut']);
            $table->index(['medecin_id', 'date_rendez_vous']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rendez_vous');
    }
};
