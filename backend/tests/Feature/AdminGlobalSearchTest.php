<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminGlobalSearchTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['email' => 'admin@local']);
        $admin->roles()->attach(Role::where('slug', 'admin-technique')->first()->id, ['is_active' => true]);

        return $admin;
    }

    private function client(): User
    {
        $client = User::factory()->create([
            'name' => 'Awa Sossou',
            'phone' => '+22997100001',
        ]);
        $client->roles()->attach(Role::where('slug', 'client')->first()->id, ['is_active' => true]);

        return $client;
    }

    public function test_client_cannot_use_global_search(): void
    {
        $this->actingAs($this->client())
            ->get(route('admin.search.index'))
            ->assertForbidden();
    }

    public function test_admin_can_search_an_order_by_reference(): void
    {
        $client = $this->client();
        $vendor = Vendor::factory()->create(['business_name' => 'Chez Awa']);
        $order = Order::create([
            'reference' => 'BEN-RECHERCHE-001',
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'paid',
            'subtotal' => 1000,
            'total' => 1000,
        ]);

        $response = $this->actingAs($this->admin())
            ->getJson(route('admin.search.index', ['q' => 'RECHERCHE-001']));

        $response->assertOk()
            ->assertJsonPath('query', 'RECHERCHE-001');

        $orders = collect($response->json('groups'))->firstWhere('key', 'orders');

        $this->assertNotNull($orders);
        $this->assertSame('Commandes', $orders['label']);
        $this->assertSame($order->reference, $orders['items'][0]['label']);
        $this->assertSame(route('admin.orders.show', $order), $orders['items'][0]['url']);
    }

    public function test_admin_can_find_pages_from_the_global_search(): void
    {
        $response = $this->actingAs($this->admin())
            ->getJson(route('admin.search.index', ['q' => 'commissions']));

        $response->assertOk();

        $pages = collect($response->json('groups'))->firstWhere('key', 'pages');

        $this->assertNotNull($pages);
        $this->assertTrue(collect($pages['items'])->contains(
            fn (array $item): bool => $item['url'] === route('admin.commissions.index'),
        ));
    }

    public function test_search_requires_at_least_two_characters(): void
    {
        $this->actingAs($this->admin())
            ->getJson(route('admin.search.index', ['q' => 'a']))
            ->assertOk()
            ->assertJsonCount(0, 'groups')
            ->assertJsonPath('total', 0);
    }

    public function test_global_search_page_renders_results(): void
    {
        $client = $this->client();
        $vendor = Vendor::factory()->create();
        $order = Order::create([
            'reference' => 'BEN-PAGE-001',
            'user_id' => $client->id,
            'vendor_id' => $vendor->id,
            'status' => 'paid',
            'subtotal' => 2000,
            'total' => 2000,
        ]);

        $this->actingAs($this->admin())
            ->get(route('admin.search.index', ['q' => 'BEN-PAGE-001']))
            ->assertOk()
            ->assertSee('Recherche globale')
            ->assertSee($order->reference)
            ->assertSee(route('admin.orders.show', $order));
    }

    public function test_empty_search_lists_all_pages(): void
    {
        $this->actingAs($this->admin())
            ->get(route('admin.search.index'))
            ->assertOk()
            ->assertSee('Toutes les pages')
            ->assertSee('Tableau de bord');
    }
}
