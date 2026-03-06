<?php

namespace App\GraphQL\Mutations;

use App\Models\Consultation;
use App\Services\NotificationService;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class TerminerConsultation
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Consultation
    {
        $user      = $context->user();
        $medecin   = $user->medecin;

        abort_if(!$medecin, 403, 'Seuls les médecins peuvent terminer une consultation.');

        $consultation = Consultation::findOrFail($args['consultation_id']);
        abort_if($consultation->medecin_id !== $medecin->id, 403);

        $consultation->update([
            'statut'           => 'terminee',
            'diagnostic'       => $args['diagnostic'],
            'recommandations'  => $args['recommandations'] ?? null,
            'notes_consultation' => $args['notes'] ?? null,
        ]);

        // Incrémenter le compteur de consultations du médecin
        $medecin->increment('nombre_consultations');

        // Notifier le patient
        app(NotificationService::class)->sendToUser(
            userId: $consultation->patient->user_id,
            titre: 'Consultation terminée',
            message: "Dr. {$medecin->nom_complet} a finalisé votre consultation.",
            type: 'consultation',
            data: ['consultation_id' => $consultation->id],
        );

        return $consultation->fresh();
    }
}
