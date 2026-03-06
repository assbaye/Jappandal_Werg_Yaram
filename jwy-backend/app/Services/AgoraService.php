<?php

namespace App\Services;

/**
 * Service de génération de tokens RTC Agora.io
 *
 * Basé sur le protocole Agora Token Builder.
 * Docs : https://docs.agora.io/en/video-calling/get-started/authentication-workflow
 *
 * Pour l'installer :  composer require agora/agora-token
 * (ou implémentation manuelle ci-dessous)
 */
class AgoraService
{
    public const ROLE_PUBLISHER  = 1;
    public const ROLE_SUBSCRIBER = 2;

    private ?string $appId;
    private ?string $appCertificate;
    private int $tokenExpiry;

    public function __construct()
    {
        $this->appId          = config('services.agora.app_id');
        $this->appCertificate = config('services.agora.app_certificate');
        $this->tokenExpiry    = (int) config('services.agora.token_expiry', 3600);
    }

    /**
     * Génère un RTC Token Agora pour rejoindre un canal.
     *
     * @param  string  $channel  Nom du canal (ex: jwy-XXXXXXXX)
     * @param  string  $userId   UID de l'utilisateur (converti en int pour Agora)
     * @param  int     $role     ROLE_PUBLISHER (médecin) ou ROLE_SUBSCRIBER (patient)
     * @return string  Le token RTC
     */
    public function generateToken(string $channel, string $userId, int $role = self::ROLE_PUBLISHER): string
    {
        $expireTimestamp = time() + $this->tokenExpiry;

        // Si la librairie officielle est installée :
        // return RtcTokenBuilder::build($this->appId, $this->appCertificate, $channel, (int)$userId, $role, $expireTimestamp);

        // Implémentation manuelle du protocole Agora Token 006
        return $this->buildToken006($channel, (int) $userId, $role, $expireTimestamp);
    }

    /**
     * Implémentation du protocole Agora Token 006.
     * Référence : https://github.com/AgoraIO/Tools/tree/master/DynamicKey/AgoraDynamicKey/php
     */
    private function buildToken006(string $channel, int $uid, int $role, int $expireAt): string
    {
        $message = [
            'salt'        => random_int(1, 4294967295),
            'ts'          => time() + 24 * 3600,
            'privileges'  => $this->buildPrivileges($role, $expireAt),
        ];

        $content = pack('N', $message['salt'])
            . pack('N', $message['ts'])
            . $this->packPrivileges($message['privileges']);

        $sign = hash_hmac(
            'sha256',
            $this->appId . $channel . $uid . $content,
            $this->appCertificate,
            true
        );

        $token = '006' . $this->appId . base64_encode($sign . $content);

        return $token;
    }

    private function buildPrivileges(int $role, int $expireAt): array
    {
        $privileges = [
            1 => $expireAt, // JOIN_CHANNEL
            2 => $expireAt, // PUBLISH_AUDIO_STREAM
            3 => $expireAt, // PUBLISH_VIDEO_STREAM
        ];

        if ($role === self::ROLE_SUBSCRIBER) {
            unset($privileges[2], $privileges[3]);
        }

        return $privileges;
    }

    private function packPrivileges(array $privileges): string
    {
        $result = pack('v', count($privileges));
        foreach ($privileges as $key => $val) {
            $result .= pack('vN', $key, $val);
        }
        return $result;
    }

    /**
     * Crée un nom de canal unique pour une consultation.
     */
    public static function generateChannel(int $consultationId): string
    {
        return 'jwy-cons-' . $consultationId . '-' . bin2hex(random_bytes(4));
    }
}
