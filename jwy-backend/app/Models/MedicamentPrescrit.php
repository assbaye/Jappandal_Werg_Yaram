<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MedicamentPrescrit extends Model
{
    protected $table = 'medicaments_prescrits';

    protected $fillable = [
        'prescription_id', 'medicament_id', 'nom_libre', 'quantite',
        'posologie', 'duree_traitement', 'instructions_speciales',
    ];

    public function prescription(): BelongsTo
    {
        return $this->belongsTo(Prescription::class);
    }

    public function medicament(): BelongsTo
    {
        return $this->belongsTo(Medicament::class);
    }

    /** Nom affiché : celui du catalogue, ou celui saisi par le médecin (hors catalogue) */
    public function getNomAttribute(): string
    {
        return $this->medicament?->nom_commercial ?? $this->nom_libre ?? '';
    }

    public function getHorsCatalogueAttribute(): bool
    {
        return $this->medicament_id === null;
    }

    public function getCoutTotalAttribute(): float
    {
        return $this->quantite * ($this->medicament?->prix_unitaire ?? 0);
    }
}
