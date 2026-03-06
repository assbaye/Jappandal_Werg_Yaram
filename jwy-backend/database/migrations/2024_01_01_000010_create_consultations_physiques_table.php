<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('consultations_physiques', function (Blueprint $table) {
            $table->id();
            $table->foreignId('consultation_id')->unique()->constrained()->cascadeOnDelete();
            $table->text('adresse_consultation');
            $table->string('salle_consultation')->nullable();
            $table->boolean('presence_confirmee')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('consultations_physiques');
    }
};
