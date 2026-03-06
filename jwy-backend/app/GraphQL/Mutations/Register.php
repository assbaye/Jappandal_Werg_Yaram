<?php

namespace App\GraphQL\Mutations;

use App\Models\Medecin;
use App\Models\Patient;
use App\Models\Pharmacien;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class Register
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context): array
    {
        return DB::transaction(function () use ($args) {
            $user = User::create([
                'email'           => $args['email'],
                'password'        => $args['password'],
                'telephone'       => $args['telephone'] ?? null,
                'role'            => $args['role'],
                'langue_preferee' => $args['langue_preferee'] ?? 'fr',
            ]);

            $user->assignRole($args['role']);

            match ($args['role']) {
                'patient' => Patient::create([
                    'user_id'        => $user->id,
                    'numero_patient' => 'PAT-' . strtoupper(Str::random(8)),
                    'nom'            => $args['nom'],
                    'prenom'         => $args['prenom'],
                    'date_naissance' => $args['date_naissance'] ?? null,
                    'genre'          => $args['genre'] ?? null,
                    'groupe_sanguin' => $args['groupe_sanguin'] ?? null,
                ]),

                'medecin' => Medecin::create([
                    'user_id'              => $user->id,
                    'numero_ordre'         => $args['numero_ordre'] ?? 'ORD-' . strtoupper(Str::random(8)),
                    'nom'                  => $args['nom'],
                    'prenom'               => $args['prenom'],
                    'specialite'           => $args['specialite'] ?? 'Médecin généraliste',
                    'hopital_rattachement' => $args['hopital_rattachement'] ?? null,
                    'tarif_consultation'   => $args['tarif_consultation'] ?? 15000,
                ]),

                'pharmacien' => Pharmacien::create([
                    'user_id'       => $user->id,
                    'numero_ordre'  => $args['numero_ordre'] ?? 'PHR-' . strtoupper(Str::random(8)),
                    'nom'           => $args['nom'],
                    'prenom'        => $args['prenom'],
                ]),

                default => null,
            };

            $token = auth('api')->login($user);

            return $this->respondWithToken($token, $user);
        });
    }

    private function respondWithToken(string $token, User $user): array
    {
        return [
            'access_token' => $token,
            'token_type'   => 'bearer',
            'expires_in'   => auth('api')->factory()->getTTL() * 60,
            'user'         => $user,
        ];
    }
}
