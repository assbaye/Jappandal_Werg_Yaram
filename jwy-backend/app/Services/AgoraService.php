<?php

namespace App\Services;

use GraphQL\Error\Error;

/**
 * Service de génération de tokens RTC Agora.io.
 *
 * - Projet Agora en « mode test » (App ID seul, pas de certificat) : aucun token n'est
 *   nécessaire, on renvoie une chaîne vide.
 * - Projet en « mode sécurisé » (App ID + App Certificate) : token au format 006,
 *   portage de RtcTokenBuilder::buildTokenWithUid du dépôt officiel AgoraIO/Tools
 *   (DynamicKey/AgoraDynamicKey/php).
 */
class AgoraService
{
    // Privilèges du format 006
    private const JOIN_CHANNEL         = 1;
    private const PUBLISH_AUDIO_STREAM = 2;
    private const PUBLISH_VIDEO_STREAM = 3;
    private const PUBLISH_DATA_STREAM  = 4;

    private ?string $appId;
    private ?string $appCertificate;
    private int $tokenExpiry;

    public function __construct()
    {
        $this->appId          = config('services.agora.app_id');
        $this->appCertificate = config('services.agora.app_certificate');
        $this->tokenExpiry    = (int) config('services.agora.token_expiry', 3600);
    }

    public function appId(): string
    {
        if (empty($this->appId)) {
            throw new Error('La vidéo n\'est pas encore configurée sur le serveur (AGORA_APP_ID manquant).');
        }

        return $this->appId;
    }

    /**
     * Token RTC permettant à $uid de rejoindre $channel et d'y émettre audio et vidéo
     * (patient comme médecin : les deux doivent se voir et s'entendre).
     */
    public function generateToken(string $channel, int $uid): string
    {
        $appId = $this->appId();

        if (empty($this->appCertificate)) {
            return ''; // mode test Agora
        }

        $expireAt = time() + $this->tokenExpiry;

        $message = pack('V', random_int(1, 99999999))   // salt
            . pack('V', time() + 24 * 3600)               // ts
            . $this->packMapUint32([
                self::JOIN_CHANNEL         => $expireAt,
                self::PUBLISH_AUDIO_STREAM => $expireAt,
                self::PUBLISH_VIDEO_STREAM => $expireAt,
                self::PUBLISH_DATA_STREAM  => $expireAt,
            ]);

        $uidStr    = $uid === 0 ? '' : (string) $uid;
        $signature = hash_hmac('sha256', $appId . $channel . $uidStr . $message, $this->appCertificate, true);

        $content = $this->packString($signature)
            . pack('V', crc32($channel) & 0xffffffff)
            . pack('V', crc32($uidStr) & 0xffffffff)
            . $this->packString($message);

        return '006' . $appId . base64_encode($content);
    }

    private function packString(string $value): string
    {
        return pack('v', strlen($value)) . $value;
    }

    private function packMapUint32(array $map): string
    {
        ksort($map);
        $out = pack('v', count($map));
        foreach ($map as $key => $value) {
            $out .= pack('v', $key) . pack('V', $value);
        }

        return $out;
    }
}
