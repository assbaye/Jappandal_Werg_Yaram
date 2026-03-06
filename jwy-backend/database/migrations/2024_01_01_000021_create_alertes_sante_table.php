<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('alertes_sante', function (Blueprint $table) {
            $table->id();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->string('type_alerte');
            $table->string('zone');
            $table->enum('niveau_gravite', ['info', 'attention', 'alerte', 'urgence'])->default('info');
            $table->text('description');
            $table->text('recommandations')->nullable();
            $table->timestamp('date_debut');
            $table->timestamp('date_fin')->nullable();
            $table->boolean('est_active')->default(true);
            $table->integer('personnes_touchees')->default(0);
            $table->timestamps();

            $table->index(['zone', 'est_active']);
            $table->index('niveau_gravite');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('alertes_sante');
    }
};
