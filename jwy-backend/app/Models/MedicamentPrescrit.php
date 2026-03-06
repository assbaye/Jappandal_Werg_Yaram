<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MedicamentPrescrit extends Model
{
    protected $table = 'medicaments_prescrits';

    protected $fillable = [
        'prescription_id', 'medicament_id', 'quantite',
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

    public function getCoutTotalAttribute(): float
    {
        return $this->quantite * ($this->medicament->prix_unitaire ?? 0);
    }
}
