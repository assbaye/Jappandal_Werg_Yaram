<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('email')->unique();
            $table->string('password');
            $table->string('telephone', 20)->nullable()->unique();
            $table->enum('role', ['patient', 'medecin', 'pharmacien', 'admin'])->default('patient');
            $table->string('langue_preferee', 5)->default('fr');
            $table->boolean('est_actif')->default(true);
            $table->timestamp('dernier_login')->nullable();
            $table->string('fcm_token')->nullable();
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();

            $table->index('role');
            $table->index('est_actif');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
