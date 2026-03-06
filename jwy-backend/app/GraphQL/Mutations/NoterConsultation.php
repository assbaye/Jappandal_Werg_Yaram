<?php

namespace App\GraphQL\Mutations;

use App\Models\Consultation;
use App\Models\Medecin;
use GraphQL\Type\Definition\ResolveInfo;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class NoterConsultation
{
    public function __invoke(mixed $root, array $args, GraphQLContext $context, ResolveInfo $resolveInfo): Consultation
    {
        $user    = $context->user();
        $patient = $user->patient;

        abort_if(!$patient, 403, 'Seuls les patients peuvent noter une consultation.');

        $consultation = Consultation::findOrFail($args['consultation_id']);
        abort_if($consultation->patient_id !== $patient->id, 403);
        abort_if($consultation->statut !== 'terminee', 422, 'Vous ne pouvez noter qu\'une consultation terminée.');

        $consultation->update([
            'note_patient' => $args['note'],
            'avis_patient' => $args['avis'] ?? null,
        ]);

        // Recalculer la note moyenne du médecin
        $medecin = $consultation->medecin;
        $noteMoyenne = Consultation::where('medecin_id', $medecin->id)
            ->whereNotNull('note_patient')
            ->avg('note_patient');

        $medecin->update(['note_moyenne' => round($noteMoyenne, 2)]);

        return $consultation->fresh();
    }
}
