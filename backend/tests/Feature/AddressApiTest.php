<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AddressApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function clientUser(): User
    {
        $user = User::factory()->create(['phone' => '+22997000044']);
        $role = Role::where('slug', 'client')->firstOrFail();
        $user->roles()->attach($role, ['is_active' => true]);

        Sanctum::actingAs($user);

        return $user;
    }

    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'label' => 'Maison',
            'full_address' => 'Avenue Jean-Paul II, Cotonou',
            'landmark' => 'En face de la pharmacie',
            'city' => 'Cotonou',
            'latitude' => 6.357,
            'longitude' => 2.402,
        ], $overrides);
    }

    public function test_first_address_becomes_default(): void
    {
        $user = $this->clientUser();

        $this->postJson('/api/v1/addresses', $this->validPayload())
            ->assertCreated()
            ->assertJsonPath('data.is_default', true);

        $this->assertDatabaseHas('addresses', [
            'user_id' => $user->id,
            'is_default' => true,
        ]);
    }

    public function test_new_default_resets_previous_default(): void
    {
        $user = $this->clientUser();
        $first = Address::factory()->default()->create(['user_id' => $user->id]);
        $second = Address::factory()->create(['user_id' => $user->id]);

        $this->postJson('/api/v1/addresses', $this->validPayload(['is_default' => true]))
            ->assertCreated();

        $this->assertFalse($first->fresh()->is_default);
        $this->assertFalse($second->fresh()->is_default);
    }

    public function test_owner_can_list_and_does_not_see_other_addresses(): void
    {
        $user = $this->clientUser();
        Address::factory()->count(2)->create(['user_id' => $user->id]);
        Address::factory()->create();

        $this->getJson('/api/v1/addresses')
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_owner_can_update_address(): void
    {
        $user = $this->clientUser();
        $address = Address::factory()->create(['user_id' => $user->id, 'full_address' => '123 Main St']);

        $this->patchJson("/api/v1/addresses/{$address->id}", [
            'full_address' => '456 Bureau St',
            'label' => 'Bureau',
        ])
            ->assertOk()
            ->assertJsonPath('data.label', 'Bureau')
            ->assertJsonPath('data.full_address', '456 Bureau St');

        $this->assertSame('Bureau', $address->fresh()->label);
    }

    public function test_foreign_address_update_returns_404(): void
    {
        $this->clientUser();
        $foreign = Address::factory()->create();

        $this->patchJson("/api/v1/addresses/{$foreign->id}", ['label' => 'Bureau'])
            ->assertStatus(404)
            ->assertJsonPath('errors.0.code', 'not_found');
    }

    public function test_owner_can_delete_address(): void
    {
        $user = $this->clientUser();
        $address = Address::factory()->create(['user_id' => $user->id]);

        $this->deleteJson("/api/v1/addresses/{$address->id}")
            ->assertNoContent();

        $this->assertDatabaseMissing('addresses', ['id' => $address->id]);
    }

    public function test_address_validation_requires_full_address(): void
    {
        $this->clientUser();

        $this->postJson('/api/v1/addresses', [])
            ->assertStatus(422)
            ->assertJsonStructure(['errors' => [['code', 'message', 'field']]]);
    }
}
