<?php

namespace Database\Seeders;

use App\Enums\UserStatus;
use App\Enums\VendorDocumentStatus;
use App\Enums\VendorDocumentType;
use App\Enums\VendorStatus;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

/**
 * Données de démonstration back-office (dev uniquement) :
 * utilisateurs multi-rôles et vendeurs dans chaque état du cycle de vie (Phase 06/07).
 */
class DemoDataSeeder extends Seeder
{
    public function run(): void
    {
        if (Vendor::exists()) {
            $this->command->info('Des vendeurs existent déjà — démo ignorée.');

            return;
        }

        $category = Category::first() ?? Category::create([
            'name' => 'Plats et mets',
            'slug' => 'plats-et-mets',
            'is_active' => true,
        ]);

        $zone = DeliveryZone::first() ?? DeliveryZone::create([
            'name' => 'Cotonou Centre',
            'city' => 'Cotonou',
        ]);

        DeliveryRate::updateOrCreate(
            ['zone_id' => $zone->id, 'vendor_id' => null],
            ['price' => 1000, 'is_active' => true],
        );

        $roleClient = Role::where('slug', 'client')->firstOrFail();
        $roleVendor = Role::where('slug', 'vendor')->firstOrFail();
        $roleDriver = Role::where('slug', 'driver-independent')->firstOrFail();

        // ---- Utilisateurs ----
        $clientUser = User::create([
            'name' => 'Marion Hounsa',
            'phone' => '61000001',
            'email' => 'marion@demo.test',
            'password' => Hash::make('password'),
            'status' => UserStatus::Active->value,
            'phone_verified_at' => now(),
        ]);
        $clientUser->roles()->attach($roleClient->id, ['is_active' => true]);

        $vendorPendingUser = User::create([
            'name' => 'Serge d’Almeida',
            'phone' => '62000001',
            'email' => 'serge@demo.test',
            'password' => Hash::make('password'),
            'status' => UserStatus::Active->value,
            'phone_verified_at' => now(),
        ]);
        $vendorPendingUser->roles()->attach($roleClient->id, ['is_active' => true]);
        $vendorPendingUser->roles()->attach($roleVendor->id, ['is_active' => false]);

        $vendorActiveUser = User::create([
            'name' => 'Aïcha Kora',
            'phone' => '62000002',
            'email' => 'aicha@demo.test',
            'password' => Hash::make('password'),
            'status' => UserStatus::Active->value,
            'phone_verified_at' => now(),
        ]);
        $vendorActiveUser->roles()->attach($roleVendor->id, ['is_active' => true]);

        $driverUser = User::create([
            'name' => 'Rachid Orou',
            'phone' => '63000001',
            'email' => 'rachid@demo.test',
            'password' => Hash::make('password'),
            'status' => UserStatus::Active->value,
            'phone_verified_at' => now(),
        ]);
        $driverUser->roles()->attach($roleClient->id, ['is_active' => true]);
        $driverUser->roles()->attach($roleDriver->id, ['is_active' => false]);

        // ---- Vendeur 1 : en attente de vérification ----
        $pendingVendor = $this->makeVendor($vendorPendingUser, [
            'business_name' => 'Épicerie du Soleil',
            'legal_name' => 'Soleil Distribution SARL',
            'ifu' => '1202400123456',
            'phone' => '+229 62 00 00 01',
            'city' => 'Cotonou',
            'address' => '12è arrondissement, rue des Jardins, Cotonou',
            'description' => 'Épicerie générale : produits locaux et importés.',
            'status' => VendorStatus::PendingVerification->value,
        ]);

        $this->makeDocument($pendingVendor, VendorDocumentType::Ifu, 'ifu-demo.pdf', 'Extrait IFU');
        $this->makeDocument($pendingVendor, VendorDocumentType::IdCard, 'id-demo.pdf', 'Carte nationale d’identité');

        // ---- Vendeur 2 : actif avec boutique complète ----
        $activeVendor = $this->makeVendor($vendorActiveUser, [
            'business_name' => 'Miam Miam Traiteur',
            'legal_name' => 'Miam Miam SARL',
            'ifu' => '1202400789123',
            'phone' => '+229 62 00 00 02',
            'email' => 'contact@miaumiau.demo',
            'city' => 'Porto-Novo',
            'description' => 'Traiteur, plats locaux livrés à domicile.',
            'status' => VendorStatus::Active->value,
            'latitude' => 6.3684,
            'longitude' => 2.4221,
            'approved_at' => now()->subDays(20),
        ]);

        $this->makeDocument($activeVendor, VendorDocumentType::Ifu, 'ifu-miam.pdf', 'Extrait IFU');
        $this->makeDocument($activeVendor, VendorDocumentType::BusinessRegistration, 'rc-miam.pdf', 'Registre de commerce');
        $this->makeDocument($activeVendor, VendorDocumentType::StorePhoto, 'boutique-miam.jpg', 'Photo de la boutique');

        $activeVendor->settings()->create([
            'commission_exception_rate' => 8,
            'delivery_fee_share' => 70,
            'max_preparation_minutes' => 25,
            'auto_accept' => true,
        ]);

        $days = [1, 2, 3, 4, 5, 6];
        foreach ($days as $day) {
            $activeVendor->hours()->create([
                'day_of_week' => $day,
                'opens_at' => '08:00:00',
                'closes_at' => '21:00:00',
                'is_closed' => false,
            ]);
        }
        $activeVendor->hours()->create(['day_of_week' => 0, 'opens_at' => '09:00:00', 'closes_at' => '14:00:00', 'is_closed' => false]);

        $activeVendor->contacts()->create([
            'name' => 'Aïcha Kora',
            'role' => 'Gérante',
            'phone' => '+229 62 00 00 02',
            'email' => 'aicha@demo.test',
            'is_primary' => true,
        ]);
        $activeVendor->contacts()->create([
            'name' => 'Kevin Zannou',
            'role' => 'Responsable livraisons',
            'phone' => '+229 66 00 00 01',
            'is_primary' => false,
        ]);

        $activeVendor->zones()->sync([$zone->id]);

        DeliveryRate::updateOrCreate(
            ['zone_id' => $zone->id, 'vendor_id' => $activeVendor->id],
            ['price' => 1500, 'is_active' => true],
        );

        $products = [
            ['name' => 'Poulet braisé + riz', 'price' => 2500, 'unit' => 'plat', 'stock_qty' => 20],
            ['name' => 'Pâtes sauce tomate au poisson', 'price' => 2000, 'unit' => 'plat', 'stock_qty' => 15],
            ['name' => 'Dégue (boule de manioc)', 'price' => 800, 'unit' => 'portions', 'stock_qty' => 40],
            ['name' => 'Jus de bissap 1L', 'price' => 1200, 'unit' => 'bouteille', 'stock_qty' => 30],
        ];
        foreach ($products as $product) {
            $activeVendor->products()->create([
                'category_id' => $category->id,
                'name' => $product['name'],
                'price' => $product['price'],
                'unit' => $product['unit'],
                'stock_qty' => $product['stock_qty'],
                'is_active' => true,
                'is_available' => true,
                'status' => 'active',
            ]);
        }

        // ---- Vendeur 3 : suspendu ----
        $vendorSuspendedUser = User::create([
            'name' => 'Bako Abou',
            'phone' => '62000003',
            'email' => 'bako@demo.test',
            'password' => Hash::make('password'),
            'status' => UserStatus::Active->value,
            'phone_verified_at' => now(),
        ]);
        $vendorSuspendedUser->roles()->attach($roleVendor->id, ['is_active' => true]);

        $this->makeVendor($vendorSuspendedUser, [
            'business_name' => 'Boutique Royale',
            'ifu' => '1202400345678',
            'phone' => '+229 62 00 00 03',
            'city' => 'Cotonou',
            'status' => VendorStatus::Suspended->value,
            'approved_at' => now()->subDays(30),
        ], [
            ['from' => VendorStatus::Registered, 'to' => VendorStatus::Active, 'reason' => null],
            ['from' => VendorStatus::Active, 'to' => VendorStatus::Suspended, 'reason' => 'Produits non conformes signalés par plusieurs clients.'],
        ]);

        $this->command->info('Données de démonstration back-office créées.');
    }

    private function makeVendor(User $user, array $data, array $history = []): Vendor
    {
        $vendor = Vendor::create([
            'user_id' => $user->id,
            'business_name' => $data['business_name'],
            'legal_name' => $data['legal_name'] ?? null,
            'ifu' => $data['ifu'] ?? null,
            'description' => $data['description'] ?? null,
            'phone' => $data['phone'],
            'email' => $data['email'] ?? null,
            'city' => $data['city'] ?? null,
            'address' => $data['address'] ?? null,
            'status' => $data['status'] ?? VendorStatus::Registered->value,
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
            'approved_at' => $data['approved_at'] ?? null,
        ]);

        foreach ($history as $entry) {
            $vendor->statusHistory()->create([
                'from_status' => $entry['from']->value,
                'to_status' => $entry['to']->value,
                'reason' => $entry['reason'],
                'actor_type' => 'admin',
                'actor_id' => User::where('email', 'admin@local')->value('id'),
                'created_at' => now()->subDays(15),
            ]);
        }

        return $vendor;
    }

    private function makeDocument(Vendor $vendor, VendorDocumentType $type, string $filename, string $label): void
    {
        $path = "vendor-documents/{$vendor->id}/{$filename}";
        Storage::disk('private')->put($path, "Document de démonstration — {$label} ({$type->value}).");

        $vendor->documents()->create([
            'type' => $type->value,
            'file_path' => $path,
            'status' => VendorDocumentStatus::Submitted->value,
            'submitted_by' => $vendor->user_id,
        ]);
    }
}
