<?php

namespace App\Jobs;

use App\Models\UserDevice;
use App\Services\Push\PushMessage;
use App\Services\Push\PushSendReport;
use App\Services\Push\PushTransport;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

/**
 * Envoi des notifications push FCM en file d'attente (J126, J33 §10).
 */
class SendPushNotifications implements ShouldQueue
{
    use Queueable;

    public int $timeout = 60;

    public int $tries = 3;

    /**
     * @param  list<string>  $userIds
     * @param  array<string, mixed>  $data
     */
    public function __construct(
        public string $event,
        public string $title,
        public string $body,
        public array $data = [],
        public array $userIds = [],
    ) {}

    /**
     * @return list<int>
     */
    public function backoff(): array
    {
        return [30, 120];
    }

    public function handle(PushTransport $transport): void
    {
        $payload = $this->data;
        $payload['type'] = $this->event;

        $devices = UserDevice::query()
            ->whereIn('user_id', $this->userIds)
            ->where('is_active', true)
            ->get();

        if ($devices->isEmpty()) {
            Log::channel('beninfood')->info('Envoi push ignoré : aucun appareil actif', [
                'event' => $this->event,
            ]);

            return;
        }

        $message = new PushMessage($this->title, $this->body, $payload);
        $report = new PushSendReport;

        foreach ($devices->pluck('fcm_token')->chunk(500) as $chunk) {
            $report = $report->merge($transport->send($message, $chunk->all()));
        }

        $invalid = $report->invalidTokens();

        if ($invalid !== []) {
            UserDevice::query()->whereIn('fcm_token', $invalid)->update(['is_active' => false]);
        }

        Log::channel('beninfood')->info('Notifications push envoyées', [
            'event' => $this->event,
            'recipients' => count(array_unique($this->userIds)),
            'devices' => $devices->count(),
            'successes' => count($report->successes()),
            'invalid_tokens' => count($invalid),
            'unknown_tokens' => count($report->unknownTokens()),
            'failures' => $report->failures(),
        ]);
    }
}
