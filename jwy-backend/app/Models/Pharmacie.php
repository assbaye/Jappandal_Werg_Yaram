<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\DB;

class Pharmacie extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'nom_pharmacie', 'adresse', 'telephone', 'email',
        'latitude', 'longitude', 'heures_ouverture', 'est_partenaire',
        'est_active', 'livraison_disponible', 'taux_commission', 'photo',
    ];

    protected function casts(): array
    {
        return [
            'heures_ouverture'    => 'array',
            'est_partenaire'      => 'boolean',
            'est_active'          => 'boolean',
            'livraison_disponible' => 'boolean',
            'latitude'            => 'decimal:7',
            'longitude'           => 'decimal:7',
        ];
    }

    // ─── Relations ───────────────────────────────────────────────────────────

    public function pharmaciens(): BelongsToMany
    {
        return $this->belongsToMany(Pharmacien::class, 'pharmacie_pharmacien')
            ->withPivot('est_responsable')
            ->withTimestamps();
    }

    public function stocks(): HasMany
    {
        return $this->hasMany(StockMedicament::class);
    }

    public function commandes(): HasMany
    {
        return $this->hasMany(Commande::class);
    }

    // ─── Scopes ──────────────────────────────────────────────────────────────

    /**
     * Pharmacies dans un rayon donné (km) via Haversine (PostgreSQL compatible).
     */
    public function scopeProche($query, float $lat, float $lng, float $rayonKm = 10)
    {
        // Formule Haversine compatible PostgreSQL (filtrage dans WHERE, pas HAVING)
        $distanceExpr = '( 6371 * acos( LEAST(1.0, cos( radians(?) ) * cos( radians(latitude) ) * cos( radians(longitude) - radians(?) ) + sin( radians(?) ) * sin( radians(latitude) ) ) ) )';

        return $query
            ->selectRaw("*, {$distanceExpr} AS distance", [$lat, $lng, $lat])
            ->whereRaw("{$distanceExpr} <= ?", [$lat, $lng, $lat, $rayonKm])
            ->orderByRaw($distanceExpr, [$lat, $lng, $lat]);
    }
}
