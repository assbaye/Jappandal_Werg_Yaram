<?php

namespace App\GraphQL\Mutations;

use App\Models\AlerteUrgence;
use App\Models\Medecin;
use App\Services\NotificationService;
use GraphQL\Error\Error;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

class DeclencherAlerteUrgence
{
    public function __construct(private NotificationService $notif) {}

    public function __invoke(mixed $root, array $args, GraphQLContext $context): AlerteUrgence
    {
        $patient = $context->user()->patient;

        if (! $patient) {
            throw new Error('Seul un patient peut déclencher une alerte d\'urgence.');
        }

        // Une seule alerte en cours par patient : un nouvel appui met à jour la position
        $alerte = AlerteUrgence::where('patient_id', $patient->id)->enCours()->latest()->first();

        if ($alerte) {
            $alerte->update([
                'latitude'  => $args['latitude'],
                'longitude' => $args['longitude'],
            ]);

            return $alerte;
        }

        $alerte = AlerteUrgence::create([
            'patient_id'   => $patient->id,
            'type_urgence' => $args['type_urgence'],
            'description'  => $args['description'] ?? null,
            'latitude'     => $args['latitude'],
            'longitude'    => $args['longitude'],
            'statut'       => 'active',
        ]);

        // Médecins disponibles en priorité ; à défaut, tous les médecins
        $medecins = Medecin::where('disponible_maintenant', true)->get();
        if ($medecins->isEmpty()) {
            $medecins = Medecin::all();
        }

        foreach ($medecins as $medecin) {
            $this->notif->sendToUser(
                userId: $medecin->user_id,
                titre: '🚨 Urgence : ' . $alerte->type_urgence,
                message: "{$patient->nom_complet} a déclenché une alerte d'urgence.",
                type: 'urgence',
                data: ['alerte_urgence_id' => $alerte->id],
                priorite: 'urgente',
            );
        }

        return $alerte;
    }
}
