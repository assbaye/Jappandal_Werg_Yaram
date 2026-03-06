<?php

namespace App\GraphQL\Queries;

use App\Models\Paiement;
use GraphQL\Type\Definition\ResolveInfo;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class MesPaiements
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): LengthAwarePaginator
    {
        $user = $context->user();

        return Paiement::whereHasMorph('payable', ['App\Models\Consultation', 'App\Models\Commande'], function ($q) use ($user) {
            if ($user->patient) {
                $q->where('patient_id', $user->patient->id);
            }
        })->orderBy('created_at', 'desc')->paginate($args['first'] ?? 10, ['*'], 'page', $args['page'] ?? 1);
    }
}
