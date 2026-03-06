<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockMedicament extends Model
{
    protected $table = 'stocks_medicaments';

    protected $fillable = [
        'pharmacie_id', 'medicament_id', 'quantite_disponible',
        'quantite_minimale', 'date_expiration', 'prix_vente', 'emplacement_stock',
    ];

    protected function casts(): array
    {
        return [
            'date_expiration' => 'date',
            'prix_vente'      => 'decimal:2',
        ];
    }

    public function pharmacie(): BelongsTo
    {
        return $this->belongsTo(Pharmacie::class);
    }

    public function medicament(): BelongsTo
    {
        return $this->belongsTo(Medicament::class);
    }

    public function isStockFaible(): bool
    {
        return $this->quantite_disponible <= $this->quantite_minimale;
    }

    public function isExpireSous(int $jours = 30): bool
    {
        return $this->date_expiration?->diffInDays(now()) <= $jours;
    }

    public function scopeDisponible($query)
    {
        return $query->where('quantite_disponible', '>', 0);
    }
}
