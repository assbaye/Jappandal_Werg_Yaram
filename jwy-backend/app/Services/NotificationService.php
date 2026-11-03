<?php

namespace App\Services;

use App\Events\NewNotification;
use App\Models\AlerteSante;
use App\Models\NotificationJwy;
use App\Models\User;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Log;

/**
 * Service centralisé de notifications :
 * - Stockage en base de données
 * - Broadcast WebSocket (Pusher protocol via Laravel WebSockets)
 * - Push FCM (optionnel via firebase/php-jwt)
 */
class NotificationService
{
    /**
     * Envoyer une notification à un utilisateur spécifique.
     *
     * @param  int    $userId   ID de l'utilisateur cible
     * @param  string $titre    Titre de la notification
     * @param  string $message  Corps du message
     * @param  string $type     Type parmi : TypeNotification enum
     * @param  array  $data     Données additionnelles (IDs, etc.)
     * @param  string $priorite faible | normale | haute | urgente
     */
    public function sendToUser(
        int $userId,
        string $titre,
        string $message,
        string $type = 'systeme',
        array $data = [],
        string $priorite = 'normale'
    ): NotificationJwy {
        $notification = NotificationJwy::create([
            'user_id'  => $userId,
            'titre'    => $titre,
            'message'  => $message,
            'type'     => $type,
            'priorite' => $priorite,
            'data'     => $data,
        ]);

        // Broadcast temps réel via WebSocket
        try {
            event(new NewNotification($notification));
        } catch (\Throwable $e) {
            Log::warning("Broadcast notification failed: {$e->getMessage()}");
        }

        // Push FCM si le token est disponible
        $user = User::find($userId);
        if ($user?->fcm_token) {
            $this->sendFcmPush($user->fcm_token, $titre, $message, $data);
        }

        return $notification;
    }

    /**
     * Envoyer une alerte santé à tous les utilisateurs d'une zone.
     */
    public function sendHealthAlert(AlerteSante $alerte): void
    {
        // Récupérer tous les patients (en production, filtrer par zone/GPS)
        User::where('role', 'patient')
            ->where('est_actif', true)
            ->chunk(100, function ($users) use ($alerte) {
                foreach ($users as $user) {
                    $this->sendToUser(
                        userId: $user->id,
                        titre: "Alerte santé : {$alerte->type_alerte}",
                        message: $alerte->description,
                        type: 'alerte_sante',
                        data: ['alerte_id' => $alerte->id, 'zone' => $alerte->zone],
                        priorite: match ($alerte->niveau_gravite) {
                            'urgence' => 'urgente',
                            'alerte'  => 'haute',
                            default   => 'normale',
                        }
                    );
                }
            });
    }

    /**
     * Envoyer un rappel de médicament.
     */
    public function sendMedicamentReminder(int $userId, string $medicamentNom, string $posologie): NotificationJwy
    {
        return $this->sendToUser(
            userId: $userId,
            titre: "Rappel de médicament",
            message: "Il est l'heure de prendre : {$medicamentNom} - {$posologie}",
            type: 'rappel_medicament',
            priorite: 'haute'
        );
    }

    /**
     * Envoi push via Firebase Cloud Messaging (FCM).
     * Nécessite : composer require kreait/firebase-php
     */
    private function sendFcmPush(string $fcmToken, string $titre, string $message, array $data = []): void
    {
        // Implémentation avec kreait/firebase-php ou l'API HTTP FCM v1 directement
        // Exemple simplifié :
        try {
            \Illuminate\Support\Facades\Http::withHeaders([
                'Authorization' => 'Bearer ' . config('services.fcm.server_key'),
                'Content-Type'  => 'application/json',
            ])->post('https://fcm.googleapis.com/fcm/send', [
                'to' => $fcmToken,
                'notification' => [
                    'title' => $titre,
                    'body'  => $message,
                ],
                'data' => $data,
            ]);
        } catch (\Throwable $e) {
            Log::warning("FCM push failed: {$e->getMessage()}");
        }
    }
}
