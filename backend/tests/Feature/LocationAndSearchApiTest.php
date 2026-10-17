<?php

namespace Tests\Feature;

use App\Enums\VendorStatus;
use App\Models\Category;
use App\Models\Neighborhood;
use App\Models\Product;
use App\Models\Vendor;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LocationAndSearchApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_locations_index_groups_active_neighborhoods_by_city(): void
    {
        Neighborhood::factory()->create(['city' => 'Cotonou', 'name' => 'Akpakpa']);
        Neighborhood::factory()->create(['city' => 'Cotonou', 'name' => 'Fidjrossè']);
        Neighborhood::factory()->create(['city' => 'Abomey-Calavi', 'name' => 'Calavi-Centre']);
        Neighborhood::factory()->create(['city' => 'Cotonou', 'name' => 'Inactif', 'is_active' => false]);

        $response = $this->getJson('/api/v1/locations')->assertOk();

        $this->assertSame(['Abomey-Calavi', 'Cotonou'], array_column($response->json('data'), 'city'));

        $cotonou = collect($response->json('data'))->firstWhere('city', 'Cotonou');
        $this->assertCount(2, $cotonou['neighborhoods']);
        $this->assertArrayHasKey('latitude', $cotonou['neighborhoods'][0]);
        $this->assertArrayHasKey('longitude', $cotonou['neighborhoods'][0]);
    }

    public function test_vendors_search_filters_by_area_and_matches_area_in_query(): void
    {
        $target = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Maquis Akpakpa',
            'city' => 'Cotonou',
            'area' => 'Akpakpa',
        ]);
        Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Boutique Fidjrossè',
            'city' => 'Cotonou',
            'area' => 'Fidjrossè',
        ]);

        $this->getJson('/api/v1/vendors?area=Akpakpa')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $target->id)
            ->assertJsonPath('data.0.area', 'Akpakpa');

        $this->getJson('/api/v1/vendors?q=Fidjross')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.business_name', 'Boutique Fidjrossè');
    }

    public function test_vendors_search_sorts_and_filters_by_distance(): void
    {
        // Cotonou centre (Ganhi) : ~0 km du point de référence.
        $near = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Proche',
            'latitude' => 6.3668,
            'longitude' => 2.4251,
        ]);

        // Abomey-Calavi : ~9-10 km du point de référence.
        $far = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'business_name' => 'Loin',
            'latitude' => 6.4489,
            'longitude' => 2.3556,
        ]);

        $this->getJson('/api/v1/vendors?latitude=6.3668&longitude=2.4251&sort=distance')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $near->id)
            ->assertJsonPath('data.1.id', $far->id);

        $nearDistance = $this->getJson('/api/v1/vendors?latitude=6.3668&longitude=2.4251&sort=distance')
            ->json('data.0.distance_km');
        $this->assertLessThan(1.0, $nearDistance);

        $this->getJson('/api/v1/vendors?latitude=6.3668&longitude=2.4251&radius_km=3')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $near->id);
    }

    public function test_products_search_filters_by_vendor_area_and_distance(): void
    {
        $category = Category::factory()->create();

        $nearVendor = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'city' => 'Cotonou',
            'area' => 'Akpakpa',
            'latitude' => 6.3668,
            'longitude' => 2.4251,
        ]);
        $farVendor = Vendor::factory()->create([
            'status' => VendorStatus::Active->value,
            'city' => 'Abomey-Calavi',
            'area' => 'Calavi-Centre',
            'latitude' => 6.4489,
            'longitude' => 2.3556,
        ]);

        // Alignés sur le nom d'un plat pour la recherche par nom.
        Product::factory()->create([
            'vendor_id' => $nearVendor->id,
            'category_id' => $category->id,
            'name' => 'Riz au gras poulet',
            'stock_qty' => 10,
        ]);
        Product::factory()->create([
            'vendor_id' => $farVendor->id,
            'category_id' => $category->id,
            'name' => 'Riz au gras poisson',
            'stock_qty' => 10,
        ]);

        $this->getJson('/api/v1/products?q=Riz au gras&area=Akpakpa')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.vendor_id', $nearVendor->id);

        $this->getJson('/api/v1/products?latitude=6.3668&longitude=2.4251&radius_km=3&sort=distance')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.vendor_id', $nearVendor->id);

        $this->assertLessThan(
            1.0,
            $this->getJson('/api/v1/products?latitude=6.3668&longitude=2.4251&radius_km=3&sort=distance')
                ->json('data.0.distance_km'),
        );
    }
}
