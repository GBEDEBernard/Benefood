<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MeProfileTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function actingUser(array $roles = ['client']): User
    {
        $user = User::factory()->create(['phone' => '+22997000040']);

        $rows = [];
        foreach ($roles as $index => $slug) {
            $role = Role::where('slug', $slug)->firstOrFail();
            $rows[$role->id] = ['is_active' => $index === 0];
        }

        $user->roles()->attach($rows);
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_me_returns_profile_with_roles(): void
    {
        $this->actingUser();

        $this->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.name', User::first()->name)
            ->assertJsonPath('data.phone', '+22997000040')
            ->assertJsonPath('data.roles.0.slug', 'client')
            ->assertJsonPath('data.roles.0.is_active', true);
    }

    public function test_me_requires_authentication(): void
    {
        $this->getJson('/api/v1/me')
            ->assertStatus(401)
            ->assertJsonPath('errors.0.code', 'unauthenticated');
    }

    public function test_me_roles_lists_assigned_roles(): void
    {
        $this->actingUser(['client', 'vendor']);

        $this->getJson('/api/v1/me/roles')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.role.slug', 'client')
            ->assertJsonPath('data.0.is_active', true)
            ->assertJsonPath('data.1.role.slug', 'vendor')
            ->assertJsonPath('data.1.is_active', false);
    }

    public function test_active_role_switches_context(): void
    {
        $user = $this->actingUser(['client', 'vendor']);

        $this->postJson('/api/v1/me/active-role', ['role_slug' => 'vendor'])
            ->assertOk()
            ->assertJsonPath('data.active_role', 'vendor');

        $this->assertTrue($user->fresh()->activeRoleSlug() === 'vendor');

        $this->getJson('/api/v1/me/roles')
            ->assertOk()
            ->assertJsonPath('data.0.role.slug', 'vendor')
            ->assertJsonPath('data.0.is_active', true);

        $this->postJson('/api/v1/me/active-role', ['role_slug' => 'client'])
            ->assertOk()
            ->assertJsonPath('data.active_role', 'client');

        $this->assertTrue($user->fresh()->activeRoleSlug() === 'client');
    }

    public function test_active_role_rejects_unowned_role(): void
    {
        $this->actingUser(['client']);

        $this->postJson('/api/v1/me/active-role', ['role_slug' => 'porteuse'])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'role.not_assigned');
    }

    public function test_active_role_rejects_unknown_role(): void
    {
        $this->actingUser(['client']);

        $this->postJson('/api/v1/me/active-role', ['role_slug' => 'paysan'])
            ->assertStatus(422)
            ->assertJsonPath('errors.0.code', 'role.not_assigned');
    }

    public function test_active_role_requires_authentication(): void
    {
        $this->postJson('/api/v1/me/active-role', ['role_slug' => 'client'])
            ->assertStatus(401)
            ->assertJsonPath('errors.0.code', 'unauthenticated');
    }
}
