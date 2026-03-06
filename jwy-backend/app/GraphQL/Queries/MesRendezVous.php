<?php

namespace App\GraphQL\Queries;

use App\Models\RendezVous;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesRendezVous
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): LengthAwarePaginator
    {
        $user  = $context->user();
        $query = RendezVous::query()->with(['patient', 'medecin']);

        if ($user->patient) {
            $query->where('patient_id', $user->patient->id);
        } elseif ($user->medecin) {
            $query->where('medecin_id', $user->medecin->id);
        }

        if (!empty($args['statut'])) {
            $query->where('statut', $args['statut']);
        }

        return $query->orderBy('date_rendez_vous', 'desc')->paginate($args['first'] ?? 10, ['*'], 'page', $args['page'] ?? 1);
    }
}
