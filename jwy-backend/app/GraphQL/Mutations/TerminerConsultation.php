<?php

namespace App\GraphQL\Mutations;

use App\Models\Consultation;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class TerminerConsultation
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Consultation
    {
        $user      = $context->user();
        $medecin   = $user->medecin;

        if (! $medecin) {
            throw new Error('Seuls les médecins peuvent terminer une consultation.');
        }

        $consultation = Consultation::findOrFail($args['consultation_id']);

        if ($consultation->medecin_id !== $medecin->id) {
            throw new Error('Cette consultation ne vous est pas adressée.');
        }

        if (! in_array($consultation->statut, ['confirmee', 'en_cours'])) {
            throw new Error('Seule une consultation acceptée ou en cours peut être terminée.');
        }

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
