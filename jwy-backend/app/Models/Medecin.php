<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Medecin extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id', 'numero_ordre', 'nom', 'prenom', 'specialite',
        'hopital_rattachement', 'tarif_consultation', 'heures_disponibilite',
        'est_certifie', 'disponible_maintenant', 'photo', 'biographie',
        'annees_experience', 'note_moyenne', 'nombre_consultations',
    ];

    protected function casts(): array
    {
        return [
            'heures_disponibilite'  => 'array',
            'est_certifie'          => 'boolean',
            'disponible_maintenant' => 'boolean',
            'tarif_consultation'    => 'decimal:2',
            'note_moyenne'          => 'decimal:2',
        ];
    }

    // ─── Relations ───────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function consultations(): HasMany
    {
        return $this->hasMany(Consultation::class);
    }

    public function prescriptions(): HasMany
    {
        return $this->hasMany(Prescription::class);
    }

    public function rendezVous(): HasMany
    {
        return $this->hasMany(RendezVous::class);
    }

    // ─── Scopes ──────────────────────────────────────────────────────────────

    public function scopeDisponible($query)
    {
        return $query->where('disponible_maintenant', true);
    }

    public function scopeSpecialite($query, string $specialite)
    {
        return $query->where('specialite', 'ilike', "%{$specialite}%");
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    public function getNomCompletAttribute(): string
    {
        return "{$this->prenom} {$this->nom}";
    }
}
