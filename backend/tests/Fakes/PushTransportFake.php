<?php

namespace Tests\Fakes;

use App\Services\Push\PushMessage;
use App\Services\Push\PushSendReport;
use App\Services\Push\PushTransport;

/**
 * Transport FCM factice : enregistre les appels et simule des tokens invalides.
 */
final class PushTransportFake implements PushTransport
{
    /** @var list<PushMessage> */
    public array $messages = [];

    /** @var list<list<string>> */
    public array $batches = [];

    public int $calls = 0;

    /**
     * @param  list<string>  $invalid
     * @param  list<string>  $unknown
     */
    public function __construct(
        public array $invalid = [],
        public array $unknown = [],
    ) {}

    public function send(PushMessage $message, array $tokens): PushSendReport
    {
        $this->calls++;

        $this->messages[] = $message;
        $this->batches[] = $tokens;

        return new PushSendReport(
            successes: array_values(array_diff($tokens, $this->invalid, $this->unknown)),
            invalid: $this->invalid,
            unknown: $this->unknown,
        );
    }
}
