<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Spatie\Permission\Traits\HasRoles;
use Tymon\JWTAuth\Contracts\JWTSubject;

class User extends Authenticatable implements JWTSubject
{
    use HasFactory, Notifiable, HasRoles;

    protected string $guard_name = 'api';

    protected $fillable = [
        'email',
        'password',
        'telephone',
        'role',
        'langue_preferee',
        'est_actif',
        'fcm_token',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'est_actif' => 'boolean',
            'dernier_login' => 'datetime',
            'password' => 'hashed',
        ];
    }

    // ─── JWTSubject ──────────────────────────────────────────────────────────

    public function getJWTIdentifier(): mixed
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims(): array
    {
        return ['role' => $this->role];
    }

    // ─── Relations ───────────────────────────────────────────────────────────

    public function patient(): HasOne
    {
        return $this->hasOne(Patient::class);
    }

    public function medecin(): HasOne
    {
        return $this->hasOne(Medecin::class);
    }

    public function pharmacien(): HasOne
    {
        return $this->hasOne(Pharmacien::class);
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(NotificationJwy::class);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    public function isPatient(): bool
    {
        return $this->role === 'patient';
    }

    public function isMedecin(): bool
    {
        return $this->role === 'medecin';
    }

    public function isPharmacien(): bool
    {
        return $this->role === 'pharmacien';
    }

    public function isAdmin(): bool
    {
        return $this->role === 'admin';
    }

    public function getProfile(): Patient|Medecin|Pharmacien|null
    {
        return match ($this->role) {
            'patient'    => $this->patient,
            'medecin'    => $this->medecin,
            'pharmacien' => $this->pharmacien,
            default      => null,
        };
    }
}
