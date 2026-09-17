<?php

namespace App\Services\Push;

interface PushTransport
{
    /**
     * Envoie un message push à une liste de tokens FCM (le job découpe en lots ≤ 500).
     *
     * @param  list<string>  $tokens
     */
    public function send(PushMessage $message, array $tokens): PushSendReport;
}
