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
        'de_garde_jusqu_au',
    ];

    /** Les horaires et la garde s'entendent à l'heure de Dakar */
    public const FUSEAU = 'Africa/Dakar';

    protected function casts(): array
    {
        return [
            'heures_ouverture'    => 'array',
            'est_partenaire'      => 'boolean',
            'est_active'          => 'boolean',
            'livraison_disponible' => 'boolean',
            'latitude'            => 'decimal:7',
            'longitude'           => 'decimal:7',
            'de_garde_jusqu_au'   => 'datetime',
        ];
    }

    // ─── Garde et horaires ───────────────────────────────────────────────────

    public function getEstDeGardeAttribute(): bool
    {
        return $this->de_garde_jusqu_au !== null && $this->de_garde_jusqu_au->isFuture();
    }

    /** Créneau du jour [ouverture, fermeture], d'après heures_ouverture (clés lun_ven, lun_sam, sam, dim). */
    public function horairesDuJour(?\Carbon\Carbon $quand = null): ?array
    {
        $quand ??= now(self::FUSEAU);
        $h = $this->heures_ouverture ?? [];

        return match (true) {
            $quand->isSunday()   => $h['dim'] ?? null,
            $quand->isSaturday() => $h['sam'] ?? $h['lun_sam'] ?? null,
            default              => $h['lun_ven'] ?? $h['lun_sam'] ?? null,
        };
    }

    public function getEstOuverteAttribute(): bool
    {
        if (! $this->est_active) {
            return false;
        }
        if ($this->est_de_garde) {
            return true;
        }

        $creneau = $this->horairesDuJour();
        if (! $creneau || count($creneau) < 2) {
            return false;
        }

        $maintenant = now(self::FUSEAU)->format('H:i');

        return $maintenant >= $creneau[0] && $maintenant < $creneau[1];
    }

    /** Texte court pour l'affichage : « Ouverte jusqu'à 20:00 », « De garde », « Fermée ». */
    public function getStatutOuvertureAttribute(): string
    {
        if ($this->est_de_garde) {
            return 'De garde jusqu\'au ' . $this->de_garde_jusqu_au->timezone(self::FUSEAU)->translatedFormat('l H:i');
        }
        $creneau = $this->horairesDuJour();

        return $this->est_ouverte
            ? "Ouverte jusqu'à {$creneau[1]}"
            : ($creneau ? "Fermée · ouvre à {$creneau[0]}" : 'Fermée aujourd\'hui');
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
