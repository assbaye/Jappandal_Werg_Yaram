<?php

namespace App\GraphQL\Queries;

use App\Models\Consultation;
use App\Models\Medecin;
use App\Models\Patient;
use App\Models\Pharmacie;
use App\Models\User;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DashboardStats
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): array
    {
        abort_if(!$context->user()->hasRole('admin'), 403);

        return [
            'total_patients'        => Patient::count(),
            'total_medecins'        => Medecin::count(),
            'total_pharmacies'      => Pharmacie::count(),
            'consultations_du_jour' => Consultation::whereDate('created_at', today())->count(),
            'medecins_disponibles'  => Medecin::where('disponible_maintenant', true)->count(),
            'nouveaux_utilisateurs' => User::whereDate('created_at', today())->count(),
        ];
    }
}
