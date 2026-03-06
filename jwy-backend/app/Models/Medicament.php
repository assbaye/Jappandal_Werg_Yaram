<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Medicament extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'nom_commercial', 'principe_actif', 'dosage', 'forme',
        'fabricant', 'prix_unitaire', 'code_barre',
        'necessite_ordonnance', 'description',
        'contre_indications', 'effets_secondaires',
    ];

    protected function casts(): array
    {
        return [
            'necessite_ordonnance' => 'boolean',
            'prix_unitaire'        => 'decimal:2',
            'contre_indications'   => 'array',
            'effets_secondaires'   => 'array',
        ];
    }

    public function stocks(): HasMany
    {
        return $this->hasMany(StockMedicament::class);
    }

    public function medicamentsPrescrits(): HasMany
    {
        return $this->hasMany(MedicamentPrescrit::class);
    }

    public function scopeRecherche($query, string $terme)
    {
        return $query->where('nom_commercial', 'ilike', "%{$terme}%")
            ->orWhere('principe_actif', 'ilike', "%{$terme}%");
    }
}
