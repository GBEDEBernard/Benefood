<?php

namespace App\Services\Push;

use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;

/**
 * Transport push via Firebase Cloud Messaging (Admin SDK, J126).
 */
final class FirebasePushTransport implements PushTransport
{
    public function __construct(private readonly Messaging $messaging) {}

    public function send(PushMessage $message, array $tokens): PushSendReport
    {
        $cloudMessage = CloudMessage::new()
            ->withNotification(['title' => $message->title, 'body' => $message->body])
            ->withData($message->dataForTransport());

        $report = $this->messaging->sendMulticast($cloudMessage, $tokens);

        $failures = [];

        foreach ($report->failures()->getItems() as $item) {
            $failures[$item->target()->value()] = $item->error()?->getMessage() ?? 'Envoi échoué';
        }

        return new PushSendReport(
            successes: $report->validTokens(),
            invalid: $report->invalidTokens(),
            unknown: $report->unknownTokens(),
            failures: $failures,
        );
    }
}
