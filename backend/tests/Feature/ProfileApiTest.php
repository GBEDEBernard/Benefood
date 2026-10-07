<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        Storage::fake('public');
    }

    private function actingClient(string $phone = '+22997000060'): User
    {
        $user = User::factory()->create([
            'phone' => $phone,
            'password' => Hash::make('secret123'),
        ]);
        $user->roles()->attach(Role::where('slug', 'client')->first()->id, ['is_active' => true]);
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_stats_returns_real_profile_counters(): void
    {
        $user = $this->actingClient();
        $user->update(['wallet_balance' => 24500]);

        $product = Product::factory()->create();
        $user->favorites()->create(['product_id' => $product->id]);
        $user->userCoupons()->create([
            'code' => 'BIENVENUE10',
            'label' => '10 %',
            'discount_type' => 'percent',
            'discount_value' => 10,
        ]);
        $user->userCoupons()->create([
            'code' => 'EXPIRE',
            'label' => 'Expiré',
            'discount_type' => 'fixed',
            'discount_value' => 500,
            'expires_at' => now()->subDay(),
        ]);
        Notification::create([
            'user_id' => $user->id,
            'type' => 'order.accepted',
            'title' => 'Commande acceptée',
            'body' => 'Votre commande #BF-0001 a été acceptée.',
        ]);

        $this->getJson('/api/v1/me/stats')
            ->assertOk()
            ->assertJsonPath('data.orders_count', 0)
            ->assertJsonPath('data.favorites_count', 1)
            ->assertJsonPath('data.coupons_count', 1)
            ->assertJsonPath('data.wallet_balance', 24500)
            ->assertJsonPath('data.unread_notifications', 1);
    }

    public function test_client_can_manage_favorites(): void
    {
        $user = $this->actingClient();
        $product = Product::factory()->create(['name' => 'Pain frais']);

        $this->postJson('/api/v1/me/favorites', ['product_id' => $product->id])
            ->assertCreated()
            ->assertJsonPath('data.product_id', $product->id);

        $this->postJson('/api/v1/me/favorites', ['product_id' => $product->id])
            ->assertCreated();

        $this->getJson('/api/v1/me/favorites')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.product.name', 'Pain frais');

        $this->deleteJson("/api/v1/me/favorites/{$product->id}")->assertNoContent();

        $this->getJson('/api/v1/me/favorites')->assertOk()->assertJsonCount(0, 'data');
        $this->assertDatabaseCount('favorites', 0);
    }

    public function test_favorite_rejects_unknown_product(): void
    {
        $this->actingClient();

        $this->postJson('/api/v1/me/favorites', ['product_id' => '11111111-1111-1111-1111-111111111111'])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'validation_error.product_id');
    }

    public function test_payment_methods_default_lifecycle(): void
    {
        $user = $this->actingClient();

        $first = $this->postJson('/api/v1/me/payment-methods', [
            'type' => 'mobile_money',
            'provider' => 'Moov Money',
            'label' => 'Mon Moov',
            'last4' => '4242',
        ])->assertCreated()->json('data');

        $this->assertTrue($first['is_default']);

        $second = $this->postJson('/api/v1/me/payment-methods', [
            'type' => 'card',
            'provider' => 'Visa',
            'label' => 'Visa perso',
        ])->assertCreated()->json('data');

        $this->assertFalse($second['is_default']);

        $this->getJson('/api/v1/me/payment-methods')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $first['id'])
            ->assertJsonPath('data.0.is_default', true)
            ->assertJsonPath('data.1.id', $second['id'])
            ->assertJsonPath('data.1.is_default', false);

        $this->patchJson("/api/v1/me/payment-methods/{$second['id']}", ['is_default' => true])
            ->assertOk()
            ->assertJsonPath('data.is_default', true);

        $this->assertDatabaseHas('payment_methods', ['id' => $first['id'], 'is_default' => false]);

        $this->deleteJson("/api/v1/me/payment-methods/{$second['id']}")->assertNoContent();

        $this->assertDatabaseHas('payment_methods', ['id' => $first['id'], 'is_default' => true]);
    }

    public function test_payment_method_validation_rejects_pan(): void
    {
        $this->actingClient();

        $this->postJson('/api/v1/me/payment-methods', [
            'type' => 'card',
            'provider' => 'Visa',
            'label' => 'Carte',
            'last4' => '4111111111111111',
        ])->assertStatus(422);
    }

    public function test_payment_method_of_other_user_is_hidden(): void
    {
        $owner = User::factory()->create(['phone' => '+22997000061']);
        $method = $owner->paymentMethods()->create([
            'type' => 'card',
            'provider' => 'Visa',
            'label' => 'Autre carte',
        ]);

        $this->actingClient();

        $this->deleteJson("/api/v1/me/payment-methods/{$method->id}")->assertNotFound();
        $this->assertDatabaseHas('payment_methods', ['id' => $method->id]);
    }

    public function test_notifications_list_and_read_flow(): void
    {
        $user = $this->actingClient();
        $other = User::factory()->create(['phone' => '+22997000062']);

        $mine = Notification::create([
            'user_id' => $user->id,
            'type' => 'order.delivered',
            'title' => 'Commande livrée',
            'body' => 'Votre commande #BF-0002 a été livrée.',
        ]);
        Notification::create([
            'user_id' => $other->id,
            'type' => 'order.delivered',
            'title' => 'Autre commande',
            'body' => 'Chez un autre client.',
        ]);

        $this->getJson('/api/v1/me/notifications')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $mine->id)
            ->assertJsonPath('data.0.title', 'Commande livrée');

        $this->postJson("/api/v1/me/notifications/{$mine->id}/read")
            ->assertOk()
            ->assertJsonPath('data.read_at', fn ($value) => $value !== null);

        $this->assertDatabaseHas('notifications', ['id' => $mine->id]);
        $this->assertNotNull($mine->fresh()->read_at);
    }

    public function test_notification_of_other_user_returns_404(): void
    {
        $other = User::factory()->create(['phone' => '+22997000063']);
        $foreign = Notification::create([
            'user_id' => $other->id,
            'type' => 'order.paid',
            'title' => 'Commande reçue',
            'body' => 'Chez un autre vendeur.',
        ]);

        $this->actingClient();

        $this->postJson("/api/v1/me/notifications/{$foreign->id}/read")->assertNotFound();
        $this->assertNull($foreign->fresh()->read_at);
    }

    public function test_mark_all_notifications_read(): void
    {
        $user = $this->actingClient();

        foreach (range(1, 3) as $i) {
            Notification::create([
                'user_id' => $user->id,
                'type' => 'order.accepted',
                'title' => 'Commande acceptée',
                'body' => "Notification {$i}.",
            ]);
        }

        $this->postJson('/api/v1/me/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('data.updated', 3);

        $this->assertSame(0, $user->appNotifications()->whereNull('read_at')->count());
    }

    public function test_change_password_updates_and_rejects_wrong_current(): void
    {
        $user = $this->actingClient();

        $this->postJson('/api/v1/me/password', [
            'current_password' => 'wrong-password',
            'password' => 'newsecret123',
            'password_confirmation' => 'newsecret123',
        ])->assertStatus(422)
            ->assertJsonPath('errors.0.field', 'current_password');

        $this->postJson('/api/v1/me/password', [
            'current_password' => 'secret123',
            'password' => 'newsecret123',
            'password_confirmation' => 'newsecret123',
        ])->assertOk();

        $this->assertTrue(Hash::check('newsecret123', $user->fresh()->password));
    }

    public function test_avatar_upload_sets_avatar_url(): void
    {
        $user = $this->actingClient();

        $this->postJson('/api/v1/me/avatar', [
            'avatar' => UploadedFile::fake()->image('profil.jpg', 200, 200),
        ])->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.avatar_url', fn ($url) => str_contains((string) $url, '/storage/avatars/'));

        $this->assertNotNull($user->fresh()->avatar_path);
        Storage::disk('public')->assertExists($user->fresh()->avatar_path);
    }

    public function test_avatar_upload_rejects_non_image(): void
    {
        $this->actingClient();

        $this->postJson('/api/v1/me/avatar', [
            'avatar' => UploadedFile::fake()->create('doc.pdf', 100, 'application/pdf'),
        ])->assertStatus(422);
    }

    public function test_coupons_list_exposes_availability(): void
    {
        $user = $this->actingClient();

        $user->userCoupons()->create([
            'code' => 'BIENVENUE10',
            'label' => '10 % sur votre première commande',
            'discount_type' => 'percent',
            'discount_value' => 10,
            'expires_at' => now()->addDays(10),
        ]);
        $user->userCoupons()->create([
            'code' => 'UTILISE',
            'label' => 'Déjà utilisé',
            'discount_type' => 'fixed',
            'discount_value' => 500,
            'used_at' => now(),
        ]);

        $this->getJson('/api/v1/me/coupons')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.code', 'BIENVENUE10')
            ->assertJsonPath('data.0.is_available', true)
            ->assertJsonPath('data.1.is_available', false);
    }

    public function test_profile_requires_authentication(): void
    {
        $this->getJson('/api/v1/me/stats')->assertStatus(401);
        $this->getJson('/api/v1/me/favorites')->assertStatus(401);
        $this->getJson('/api/v1/me/notifications')->assertStatus(401);
        $this->getJson('/api/v1/me/coupons')->assertStatus(401);
        $this->getJson('/api/v1/me/payment-methods')->assertStatus(401);
    }
}
