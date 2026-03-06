<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class Paiement extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'montant', 'devise', 'statut', 'methode_paiement',
        'numero_transaction', 'reference_externe', 'frais_transaction',
        'payable_type', 'payable_id', 'metadata', 'confirme_le',
    ];

    protected function casts(): array
    {
        return [
            'montant'          => 'decimal:2',
            'frais_transaction' => 'decimal:2',
            'metadata'         => 'array',
            'confirme_le'      => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function payable(): MorphTo
    {
        return $this->morphTo();
    }

    public function facture(): HasOne
    {
        return $this->hasOne(Facture::class);
    }

    public function getMontantTotalAttribute(): float
    {
        return $this->montant + $this->frais_transaction;
    }
}
