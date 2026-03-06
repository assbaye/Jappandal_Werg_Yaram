<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationJwy extends Model
{
    use HasFactory;

    protected $table = 'notifications_jwy';

    protected $fillable = [
        'user_id', 'titre', 'message', 'type', 'priorite',
        'est_lue', 'lue_le', 'data', 'action_url',
    ];

    protected function casts(): array
    {
        return [
            'est_lue' => 'boolean',
            'lue_le'  => 'datetime',
            'data'    => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function marquerLue(): void
    {
        $this->update(['est_lue' => true, 'lue_le' => now()]);
    }

    public function scopeNonLues($query)
    {
        return $query->where('est_lue', false);
    }
}
