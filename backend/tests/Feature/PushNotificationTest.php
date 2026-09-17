<?php

namespace Tests\Feature;

use App\Jobs\SendPushNotifications;
use App\Models\NotificationTemplate;
use App\Models\User;
use App\Models\UserDevice;
use App\Services\NotificationService;
use App\Services\Push\PushTransport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\Fakes\PushTransportFake;
use Tests\TestCase;

class PushNotificationTest extends TestCase
{
    use RefreshDatabase;

    private PushTransportFake $transport;

    protected function setUp(): void
    {
        parent::setUp();

        $this->transport = new PushTransportFake;
        $this->app->instance(PushTransport::class, $this->transport);
    }

    public function test_sends_push_to_active_device_with_event_type_in_data(): void
    {
        $user = User::factory()->create();
        $token = 'token-actif-1234567890';
        UserDevice::factory()->create(['user_id' => $user->id, 'fcm_token' => $token]);
        UserDevice::factory()->create([
            'user_id' => $user->id,
            'fcm_token' => 'token-inactif-1234567890',
            'is_active' => false,
        ]);

        SendPushNotifications::dispatch(
            'order.new_paid',
            'Nouvelle commande BF-001',
            'Commande BF-001 payée.',
            ['reference' => 'BF-001'],
            [$user->id],
        );

        $this->assertSame(1, $this->transport->calls);
        $this->assertSame([$token], $this->transport->batches[0]);

        $message = $this->transport->messages[0];
        $this->assertSame('Nouvelle commande BF-001', $message->title);
        $this->assertSame('Commande BF-001 payée.', $message->body);
        $this->assertSame('order.new_paid', $message->data['type']);
        $this->assertSame('BF-001', $message->data['reference']);
    }

    public function test_invalid_tokens_are_deactivated(): void
    {
        $user = User::factory()->create();
        $stale = UserDevice::factory()->create(['user_id' => $user->id]);
        UserDevice::factory()->create(['user_id' => $user->id]);

        $this->transport->invalid = [$stale->fcm_token];

        SendPushNotifications::dispatch('order.accepted', 'Commande', 'Acceptée.', [], [$user->id]);

        $this->assertSame(1, $this->transport->calls);
        $this->assertFalse($stale->refresh()->is_active);
        $this->assertSame(1, UserDevice::query()->where('is_active', true)->count());
    }

    public function test_skips_send_when_no_active_device(): void
    {
        $user = User::factory()->create();
        UserDevice::factory()->create(['user_id' => $user->id, 'is_active' => false]);

        SendPushNotifications::dispatch('order.ready', 'Commande', 'Prête.', [], [$user->id]);

        $this->assertSame(0, $this->transport->calls);
    }

    public function test_notification_service_dispatches_push_job_and_stores_in_app_notification(): void
    {
        config(['beninfood.push.enabled' => true]);

        Queue::fake();

        $user = User::factory()->create();
        NotificationTemplate::factory()->create([
            'event' => 'order.new_paid',
            'channel' => 'push',
            'subject' => 'Nouvelle commande {reference}',
            'body' => 'Commande {reference} payée.',
        ]);

        app(NotificationService::class)->notifyEvent('order.new_paid', [$user], ['reference' => 'BF-001']);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $user->id,
            'type' => 'order.new_paid',
            'title' => 'Nouvelle commande BF-001',
        ]);

        Queue::assertPushedOn('push', SendPushNotifications::class, function (SendPushNotifications $job) use ($user): bool {
            return $job->event === 'order.new_paid'
                && $job->userIds === [$user->id]
                && $job->data === ['reference' => 'BF-001']
                && $job->title === 'Nouvelle commande BF-001';
        });
    }

    public function test_notification_service_skips_push_when_template_is_inactive(): void
    {
        Queue::fake();

        $user = User::factory()->create();
        NotificationTemplate::factory()->create([
            'event' => 'order.new_paid',
            'channel' => 'push',
            'is_active' => false,
        ]);

        app(NotificationService::class)->notifyEvent('order.new_paid', [$user], ['reference' => 'BF-001']);

        Queue::assertNotPushed(SendPushNotifications::class);
    }
}
