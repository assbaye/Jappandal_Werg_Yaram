<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Prescription extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'consultation_id', 'medecin_id', 'patient_id',
        'validite_jours', 'instructions', 'est_executee', 'date_execution',
    ];

    protected function casts(): array
    {
        return [
            'est_executee'   => 'boolean',
            'date_execution' => 'datetime',
        ];
    }

    public function consultation(): BelongsTo
    {
        return $this->belongsTo(Consultation::class);
    }

    public function medecin(): BelongsTo
    {
        return $this->belongsTo(Medecin::class);
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(Patient::class);
    }

    public function medicamentsPrescrits(): HasMany
    {
        return $this->hasMany(MedicamentPrescrit::class);
    }

    public function getIsExpireeAttribute(): bool
    {
        return $this->isExpiree();
    }

    public function isExpiree(): bool
    {
        return $this->created_at->addDays($this->validite_jours)->isPast();
    }
}
