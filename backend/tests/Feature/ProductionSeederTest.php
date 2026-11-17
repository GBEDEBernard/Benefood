<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\DeliveryZone;
use App\Models\NotificationTemplate;
use App\Models\Role;
use App\Models\User;
use Database\Seeders\ProductionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ProductionSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_seeds_reference_data_when_tables_are_empty(): void
    {
        config()->set('beninfood.admin_seed.password', 'admin-password');

        $this->seed(ProductionSeeder::class);

        $this->assertTrue(Role::query()->where('slug', 'admin-technique')->exists());
        $this->assertSame(9, Category::query()->count());
        $this->assertSame(9, DeliveryZone::query()->count());
        $this->assertSame(20, NotificationTemplate::query()->count());
    }

    public function test_creates_admin_who_can_log_in_with_configured_password(): void
    {
        config()->set('beninfood.admin_seed.name', 'GBEDE Bernard');
        config()->set('beninfood.admin_seed.email', 'admin@benefood.test');
        config()->set('beninfood.admin_seed.password', 'admin-password');

        $this->seed(ProductionSeeder::class);

        $this->post('/login', [
            'email' => 'admin@benefood.test',
            'password' => 'admin-password',
        ])->assertRedirect(route('admin.dashboard'));

        $admin = User::query()->where('email', 'admin@benefood.test')->firstOrFail();
        $this->assertSame('GBEDE Bernard', $admin->name);
        $this->assertTrue($admin->hasRole('admin-technique'));
    }

    public function test_does_not_create_admin_without_configured_password(): void
    {
        config()->set('beninfood.admin_seed.password', null);

        $this->seed(ProductionSeeder::class);

        $this->assertDatabaseMissing('users', ['email' => 'gbedebernard60@gmail.com']);
        $this->assertTrue(Role::query()->where('slug', 'admin-technique')->exists());
    }

    public function test_does_not_reset_existing_admin_password(): void
    {
        $admin = User::factory()->create([
            'email' => 'gbedebernard60@gmail.com',
            'password' => 'original-password',
        ]);
        config()->set('beninfood.admin_seed.password', 'new-password');

        $this->seed(ProductionSeeder::class);

        $admin->refresh();
        $this->assertTrue(Hash::check('original-password', $admin->password));
        $this->assertFalse(Hash::check('new-password', $admin->password));
    }
}
