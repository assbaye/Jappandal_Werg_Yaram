<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Patient extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id', 'numero_patient', 'nom', 'prenom', 'date_naissance',
        'genre', 'adresse', 'numero_urgence', 'groupe_sanguin',
        'allergies', 'latitude', 'longitude', 'photo',
    ];

    protected function casts(): array
    {
        return [
            'date_naissance' => 'date',
            'allergies'      => 'array',
            'latitude'       => 'decimal:7',
            'longitude'      => 'decimal:7',
        ];
    }

    // ─── Boot ────────────────────────────────────────────────────────────────

    protected static function booted(): void
    {
        static::creating(function (Patient $patient) {
            if (empty($patient->numero_patient)) {
                $patient->numero_patient = 'PAT-' . strtoupper(uniqid());
            }
        });

        static::created(function (Patient $patient) {
            $patient->dossierMedical()->create([]);
        });
    }

    // ─── Relations ───────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function dossierMedical(): HasOne
    {
        return $this->hasOne(DossierMedical::class);
    }

    public function consultations(): HasMany
    {
        return $this->hasMany(Consultation::class);
    }

    public function rendezVous(): HasMany
    {
        return $this->hasMany(RendezVous::class);
    }

    public function commandes(): HasMany
    {
        return $this->hasMany(Commande::class);
    }

    public function prescriptions(): HasMany
    {
        return $this->hasMany(Prescription::class);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    public function getNomCompletAttribute(): string
    {
        return "{$this->prenom} {$this->nom}";
    }

    public function getAgeAttribute(): ?int
    {
        return $this->date_naissance?->age;
    }
}
