<?php

namespace Database\Seeders;

use App\Enums\DriverStatus;
use App\Enums\DriverType;
use App\Enums\UserStatus;
use App\Enums\VendorDocumentStatus;
use App\Enums\VendorDocumentType;
use App\Enums\VendorStatus;
use App\Models\Address;
use App\Models\Category;
use App\Models\DeliveryRate;
use App\Models\DeliveryZone;
use App\Models\Order;
use App\Models\Role;
use App\Models\User;
use App\Models\Vendor;
use App\Services\CartService;
use App\Services\OrderService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

/**
 * Données de démonstration marketplace (dev uniquement) :
 * vendeurs avec boutique + produits, clients, livreurs, et commandes
 * créées via le vrai flux métier (CartService + OrderService).
 *
 * Les identifiants de connexion sont affichés en fin d'exécution.
 */
class ShopDataSeeder extends Seeder
{
    protected const DOMAIN = 'shop.demo';

    private const VENDOR_ACCOUNTS = [
        [
            'name' => 'Edna Dossou',
            'email' => 'edna@shop.demo',
            'phone' => '+22961000011',
            'business_name' => 'Délices d’Edna',
            'description' => 'Traiteur, plats locaux et ménus livrés à domicile.',
            'city' => 'Cotonou',
            'address' => 'Cotonou, rue du stade de l’Amitié',
            'latitude' => 6.3603,
            'longitude' => 2.3943,
        ],
        [
            'name' => 'Koffi Mensah',
            'email' => 'koffi@shop.demo',
            'phone' => '+22962000011',
            'business_name' => 'Primeur du Golfe',
            'description' => 'Fruits et légumes frais, fruits de saison et paniers du marché.',
            'city' => 'Cotonou',
            'address' => 'Cotonou, carrefour Akpakpa',
            'latitude' => 6.3779,
            'longitude' => 2.4389,
        ],
        [
            'name' => 'Rachida Alabi',
            'email' => 'rachida@shop.demo',
            'phone' => '+22963000011',
            'business_name' => 'La Boulangerie du Centre',
            'description' => 'Pains, viennoiseries et pâtisseries fraîches chaque matin.',
            'city' => 'Cotonou',
            'address' => 'Cotonou, avenue Clozel',
            'latitude' => 6.3668,
            'longitude' => 2.4251,
        ],
    ];

    private const CLIENT_ACCOUNTS = [
        ['name' => 'Marion Hounsa', 'email' => 'marion@shop.demo', 'phone' => '+22961000012'],
        ['name' => 'Jean Agbodjan', 'email' => 'jean@shop.demo', 'phone' => '+22961000013'],
        ['name' => 'Fatou Soumanou', 'email' => 'fatou@shop.demo', 'phone' => '+22961000014'],
    ];

    private const DRIVER_ACCOUNTS = [
        ['name' => 'Rachid Orou', 'email' => 'rachid@shop.demo', 'phone' => '+22963000012', 'vehicle' => 'Moto Bajaj 150'],
        ['name' => 'Sylvain Kpoviessi', 'email' => 'sylvain@shop.demo', 'phone' => '+22963000013', 'vehicle' => 'Moto Djakarta'],
    ];

    private const PASSWORD = 'password';

    public function run(): void
    {
        $this->resetShopDemo();

        $zones = $this->ensureZonesAndRates();

        $roleClient = Role::where('slug', 'client')->firstOrFail();
        $roleVendor = Role::where('slug', 'vendor')->firstOrFail();
        $roleDriver = Role::where('slug', 'driver-independent')->firstOrFail();

        // ---- Vendeurs (boutiques) ----
        $vendors = [];
        foreach (self::VENDOR_ACCOUNTS as $i => $account) {
            $user = $this->makeUser($account, $roleVendor);
            $zone = $zones[$i % count($zones)];
            $vendors[] = $this->makeVendor($user, $account, $zone);
        }

        // ---- Clients ----
        $clients = [];
        $cotonouCentre = DeliveryZone::where('name', 'Cotonou Centre')->firstOrFail();
        foreach (self::CLIENT_ACCOUNTS as $account) {
            $user = $this->makeUser($account, $roleClient);
            $address = $this->makeAddress($user, $cotonouCentre);
            $clients[] = ['user' => $user, 'address' => $address];
        }

        // ---- Livreurs ----
        $drivers = [];
        foreach (self::DRIVER_ACCOUNTS as $account) {
            $drivers[] = $this->makeDriver($account, $roleDriver);
        }

        $this->seedOrders($clients, $vendors, $drivers);

        $this->printCredentials();
    }

    // ------------------------------------------------------------------ création

    private function makeUser(array $account, Role $lowestActiveRole): User
    {
        $user = User::create([
            'name' => $account['name'],
            'phone' => $account['phone'],
            'email' => $account['email'],
            'password' => Hash::make(self::PASSWORD),
            'status' => UserStatus::Active->value,
            'phone_verified_at' => now(),
            'email_verified_at' => now(),
        ]);
        $user->roles()->attach($lowestActiveRole->id, ['is_active' => true]);

        return $user;
    }

    private function makeVendor(User $user, array $account, DeliveryZone $zone): Vendor
    {
        $vendor = Vendor::create([
            'user_id' => $user->id,
            'business_name' => $account['business_name'],
            'legal_name' => $account['business_name'].' SARL',
            'ifu' => '12024'.str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT),
            'description' => $account['description'],
            'phone' => $account['phone'],
            'email' => $account['email'],
            'city' => $account['city'] ?? 'Cotonou',
            'address' => $account['address'] ?? null,
            'latitude' => $account['latitude'] ?? null,
            'longitude' => $account['longitude'] ?? null,
            'status' => VendorStatus::Active->value,
            'approved_at' => now()->subDays(10),
        ]);

        $vendor->settings()->create([
            'commission_exception_rate' => 8,
            'delivery_fee_share' => 70,
            'max_preparation_minutes' => 25,
            'auto_accept' => true,
        ]);

        foreach (range(0, 6) as $day) {
            $vendor->hours()->create([
                'day_of_week' => $day,
                'opens_at' => '00:00:01',
                'closes_at' => '23:59:59',
                'is_closed' => false,
            ]);
        }

        $vendor->contacts()->create([
            'name' => $user->name,
            'role' => 'Responsable',
            'phone' => $account['phone'],
            'email' => $account['email'],
            'is_primary' => true,
        ]);

        $this->makeVendorDocument($vendor, VendorDocumentType::Ifu, 'ifu.pdf', 'Extrait IFU');
        $this->makeVendorDocument($vendor, VendorDocumentType::IdCard, 'id.pdf', 'Carte nationale d’identité');

        $vendor->zones()->sync([$zone->id]);

        DeliveryRate::updateOrCreate(
            ['zone_id' => $zone->id, 'vendor_id' => $vendor->id],
            ['price' => [1000, 1200, 1500][random_int(0, 2)], 'is_active' => true],
        );

        $this->seedProducts($vendor);

        return $vendor;
    }

    private function makeVendorDocument(Vendor $vendor, VendorDocumentType $type, string $filename, string $label): void
    {
        $path = "vendor-documents/{$vendor->id}/{$filename}";
        Storage::disk('private')->put($path, "Document de démonstration — {$label} ({$type->value}).");

        $vendor->documents()->create([
            'type' => $type->value,
            'file_path' => $path,
            'status' => VendorDocumentStatus::Valid->value,
            'submitted_by' => $vendor->user_id,
            'reviewed_by' => User::where('email', 'admin@local')->value('id'),
            'reviewed_at' => now()->subDays(9),
        ]);
    }

    private function seedProducts(Vendor $vendor): void
    {
        $categories = Category::pluck('id', 'slug');

        $catalog = [
            'epicerie' => [
                ['name' => 'Huile végétale 1L', 'price' => 1200, 'unit' => 'bouteille', 'stock_qty' => 60],
                ['name' => 'Sucre en poudre 1kg', 'price' => 900, 'unit' => 'sac', 'stock_qty' => 80],
                ['name' => 'Riz parfumé 5kg', 'price' => 3500, 'unit' => 'sac', 'stock_qty' => 40],
                ['name' => 'Tomate concentrée 400g', 'price' => 700, 'unit' => 'boîte', 'stock_qty' => 100],
                ['name' => 'Sel iodé 500g', 'price' => 250, 'unit' => 'paquet', 'stock_qty' => 120],
                ['name' => 'Sardines à l’huile (boîte)', 'price' => 600, 'unit' => 'boîte', 'stock_qty' => 90],
                ['name' => 'Farine de blé 1kg', 'price' => 800, 'unit' => 'sac', 'stock_qty' => 65],
                ['name' => 'Pâtes alimentaires 500g', 'price' => 450, 'unit' => 'paquet', 'stock_qty' => 85],
            ],
            'snacks-et-restauration' => [
                ['name' => 'Poulet braisé + riz', 'price' => 2500, 'unit' => 'plat', 'stock_qty' => 30],
                ['name' => 'Riz au gras avec légumes', 'price' => 1800, 'unit' => 'plat', 'stock_qty' => 30],
                ['name' => 'Pâtes sauce tomate au poisson', 'price' => 2000, 'unit' => 'plat', 'stock_qty' => 25],
                ['name' => 'Akassa sauce arachide', 'price' => 1200, 'unit' => 'portion', 'stock_qty' => 35],
                ['name' => 'Sauce graine + poisson', 'price' => 2200, 'unit' => 'plat', 'stock_qty' => 20],
                ['name' => 'Brochettes de bœuf (5)', 'price' => 1500, 'unit' => 'brochette', 'stock_qty' => 45],
                ['name' => 'Aloko (banane plantain frite)', 'price' => 800, 'unit' => 'portion', 'stock_qty' => 50],
                ['name' => 'Jus de bissap 1L', 'price' => 1200, 'unit' => 'bouteille', 'stock_qty' => 40],
            ],
            'fruits-et-legumes' => [
                ['name' => 'Banane plantain (régime)', 'price' => 1500, 'unit' => 'régime', 'stock_qty' => 30],
                ['name' => 'Tomates fraîches 1kg', 'price' => 800, 'unit' => 'kg', 'stock_qty' => 50],
                ['name' => 'Oignons rouges 1kg', 'price' => 600, 'unit' => 'kg', 'stock_qty' => 45],
                ['name' => 'Mangues (barquette)', 'price' => 1000, 'unit' => 'barquette', 'stock_qty' => 35],
                ['name' => 'Ananas (pièce)', 'price' => 700, 'unit' => 'pièce', 'stock_qty' => 40],
                ['name' => 'Gombo frais 500g', 'price' => 400, 'unit' => 'sac', 'stock_qty' => 60],
                ['name' => 'Avocats (pièce)', 'price' => 400, 'unit' => 'pièce', 'stock_qty' => 55],
                ['name' => 'Laitue (pièce)', 'price' => 350, 'unit' => 'pièce', 'stock_qty' => 30],
            ],
            'boulangerie' => [
                ['name' => 'Pain baguette', 'price' => 250, 'unit' => 'pièce', 'stock_qty' => 100],
                ['name' => 'Croissant', 'price' => 400, 'unit' => 'pièce', 'stock_qty' => 60],
                ['name' => 'Pain au chocolat', 'price' => 450, 'unit' => 'pièce', 'stock_qty' => 55],
                ['name' => 'Baguette garnie', 'price' => 750, 'unit' => 'pièce', 'stock_qty' => 40],
                ['name' => 'Pain de mie (tranches)', 'price' => 1300, 'unit' => 'paquet', 'stock_qty' => 35],
                ['name' => 'Chausson aux légumes', 'price' => 500, 'unit' => 'pièce', 'stock_qty' => 45],
                ['name' => 'Tarte à la banane', 'price' => 1200, 'unit' => 'part', 'stock_qty' => 20],
                ['name' => 'Beignets (sachet de 5)', 'price' => 500, 'unit' => 'sachet', 'stock_qty' => 70],
            ],
        ];

        // Catalogue principal du vendeur + compléments des autres rayons.
        $business = $vendor->business_name;
        $mainCat = match (true) {
            str_contains($business, 'Primeur') => 'fruits-et-legumes',
            str_contains($business, 'Boulangerie') => 'boulangerie',
            default => 'snacks-et-restauration',
        };

        $chosen = $catalog[$mainCat];
        $others = array_values(array_filter($catalog, fn ($key) => $key !== $mainCat, ARRAY_FILTER_USE_KEY));

        $slots = [];

        foreach ($chosen as $product) {
            $slots[] = ['slug' => $mainCat, 'data' => $product];
        }

        foreach ($others as $list) {
            foreach ($list as $product) {
                $slots[] = ['slug' => null, 'data' => $product];
            }
        }

        // Déduplication par nom, puis création (10 produits minimum par boutique).
        $unique = [];
        foreach ($slots as $slot) {
            $unique[$slot['data']['name']] = $slot;
        }

        $created = 0;

        foreach ($unique as $slot) {
            if ($created >= 10) {
                break;
            }

            $slug = $slot['slug'] ?? $mainCat;

            $vendor->products()->create([
                'category_id' => $categories->get($slug) ?? Category::where('slug', 'snacks-et-restauration')->value('id'),
                'name' => $slot['data']['name'],
                'price' => $slot['data']['price'],
                'unit' => $slot['data']['unit'],
                'stock_qty' => $slot['data']['stock_qty'],
                'is_active' => true,
                'is_available' => true,
                'status' => 'active',
            ]);

            $created++;
        }
    }

    private function makeAddress(User $user, DeliveryZone $zone): Address
    {
        return Address::create([
            'user_id' => $user->id,
            'label' => 'Domicile',
            'zone_id' => $zone->id,
            'is_default' => true,
            'full_address' => 'Cotonou, quartier Gbégamey, rue des Fleurs',
            'area' => 'Cotonou Centre',
            'city' => 'Cotonou',
            'latitude' => 6.3668,
            'longitude' => 2.4251,
        ]);
    }

    private function makeDriver(array $account, Role $roleDriver): User
    {
        $user = $this->makeUser($account, $roleDriver);

        $profile = $user->driverProfile()->create([
            'type' => DriverType::Independent->value,
            'status' => DriverStatus::Active->value,
            'vehicle' => $account['vehicle'],
            'available' => true,
            'rating' => 4.5,
        ]);

        $profile->statusHistory()->create([
            'from_status' => null,
            'to_status' => DriverStatus::Active->value,
            'actor_type' => 'admin',
            'actor_id' => User::where('email', 'admin@local')->value('id'),
            'reason' => 'Création via seeder de démonstration.',
        ]);

        return $user;
    }

    // ------------------------------------------------------------------ commandes

    private function seedOrders(array $clients, array $vendors, array $drivers): void
    {
        $cartService = app(CartService::class);
        $orderService = app(OrderService::class);

        // Références de scénarios : le même client peut commander chez plusieurs boutiques.
        $scenarios = [
            // client, vendeur, étapes
            [0, 0, ['delivered']],           // 1. livrée intégralement
            [1, 1, ['in_delivery']],         // 2. en cours de livraison
            [2, 2, ['ready']],               // 3. prête, course assignée
            [0, 1, ['preparing']],           // 4. en préparation
            [1, 2, ['paid']],                // 5. payée
            [2, 0, ['awaiting_payment']],    // 6. en attente de paiement
            [0, 2, ['cancelled']],           // 7. annulée par le client
        ];

        $driverProfiles = collect($drivers)->map->driverProfile->values();

        foreach ($scenarios as $index => [$clientIndex, $vendorIndex, $steps]) {
            $client = $clients[$clientIndex];
            $vendor = $vendors[$vendorIndex];
            $address = $client['address'];

            $cart = $cartService->getOrCreateOpenCart($client['user'], $vendor);

            $products = $vendor->products()->orderable()->orderBy('id')->limit(3)->get();

            foreach ($products as $product) {
                $cartService->addItem($cart, $product, random_int(1, 2));
            }

            $order = $orderService->createFromCart($cart, $address, 'Merci de livrer avant 20h.');

            foreach ($steps as $step) {
                match ($step) {
                    'awaiting_payment' => null,
                    'paid' => $orderService->confirmPayment($order, $order->total),
                    'preparing' => $this->progressToPreparing($orderService, $order),
                    'ready' => $this->progressToReady($orderService, $order, $driverProfiles),
                    'in_delivery' => $this->progressToInDelivery($orderService, $order, $driverProfiles),
                    'delivered' => $this->progressToDelivered($orderService, $order, $driverProfiles),
                    'cancelled' => $this->cancelByClient($orderService, $order),
                    default => null,
                };
            }

            $this->command->info("Commande #{$order->reference} → {$order->status->value} ({$vendor->business_name})");
        }
    }

    private function progressToPreparing(OrderService $orderService, Order $order): void
    {
        $orderService->confirmPayment($order, $order->total);
        $orderService->acceptVendorOrder($order);
        $orderService->markPreparing($order);
    }

    private function progressToReady(OrderService $orderService, Order $order, $driverProfiles): void
    {
        $this->progressToPreparing($orderService, $order);
        $orderService->markReady($order);
        $orderService->assignDriver($order, $driverProfiles->first()->id);
    }

    private function progressToInDelivery(OrderService $orderService, Order $order, $driverProfiles): void
    {
        $this->progressToReady($orderService, $order, $driverProfiles);
        $orderService->markPickedUp($order);
        $orderService->markInDelivery($order);
    }

    private function progressToDelivered(OrderService $orderService, Order $order, $driverProfiles): void
    {
        $this->progressToInDelivery($orderService, $order, $driverProfiles);
        $orderService->markDelivered($order);
    }

    private function cancelByClient(OrderService $orderService, Order $order): void
    {
        $orderService->confirmPayment($order, $order->total);
        $orderService->cancelClientOrder($order, $order->user_id, 'Commande annulée par le client (démonstration).');
    }

    // ------------------------------------------------------------------ purges

    private function resetShopDemo(): void
    {
        $userIds = User::where('email', 'like', '%@'.self::DOMAIN)->pluck('id');
        $vendorIds = Vendor::whereIn('user_id', $userIds)->pluck('id');
        $productIds = DB::table('products')->whereIn('vendor_id', $vendorIds)->pluck('id');
        $cartIds = DB::table('carts')->whereIn('user_id', $userIds)->pluck('id');
        $orderIds = DB::table('orders')
            ->whereIn('user_id', $userIds)
            ->orWhereIn('vendor_id', $vendorIds)
            ->pluck('id');
        $paymentIds = DB::table('payments')->whereIn('order_id', $orderIds)->pluck('id');
        $deliveryIds = DB::table('deliveries')->whereIn('order_id', $orderIds)->pluck('id');
        $driverProfileIds = DB::table('driver_profiles')->whereIn('user_id', $userIds)->pluck('id');
        $complaintIds = DB::table('complaints')->whereIn('order_id', $orderIds)->pluck('id');

        DB::table('delivery_status_history')->whereIn('delivery_id', $deliveryIds)->delete();
        DB::table('deliveries')->whereIn('id', $deliveryIds)->delete();
        DB::table('order_status_history')->whereIn('order_id', $orderIds)->delete();
        DB::table('order_items')->whereIn('order_id', $orderIds)->delete();
        DB::table('order_financials')->whereIn('order_id', $orderIds)->delete();
        DB::table('refunds')->whereIn('order_id', $orderIds)->delete();
        DB::table('refunds')->whereIn('payment_id', $paymentIds)->delete();
        DB::table('financial_transactions')->whereIn('payment_id', $paymentIds)->delete();
        DB::table('financial_transactions')->whereIn('order_id', $orderIds)->delete();
        DB::table('complaint_messages')->whereIn('complaint_id', $complaintIds)->delete();
        DB::table('complaints')->whereIn('id', $complaintIds)->delete();
        DB::table('payments')->whereIn('id', $paymentIds)->delete();
        DB::table('notifications')->whereIn('user_id', $userIds)->delete();
        DB::table('orders')->whereIn('id', $orderIds)->delete();

        DB::table('cart_items')->whereIn('cart_id', $cartIds)->delete();
        DB::table('carts')->whereIn('id', $cartIds)->delete();
        DB::table('addresses')->whereIn('user_id', $userIds)->delete();

        DB::table('product_price_history')->whereIn('product_id', $productIds)->delete();
        DB::table('stock_logs')->whereIn('product_id', $productIds)->delete();
        DB::table('product_images')->whereIn('product_id', $productIds)->delete();
        DB::table('products')->whereIn('id', $productIds)->delete();

        DB::table('vendor_zones')->whereIn('vendor_id', $vendorIds)->delete();
        DB::table('vendor_settings')->whereIn('vendor_id', $vendorIds)->delete();
        DB::table('vendor_hours')->whereIn('vendor_id', $vendorIds)->delete();
        DB::table('vendor_contacts')->whereIn('vendor_id', $vendorIds)->delete();
        DB::table('vendor_documents')->whereIn('vendor_id', $vendorIds)->delete();
        DB::table('vendor_status_history')->whereIn('vendor_id', $vendorIds)->delete();
        DB::table('vendors')->whereIn('id', $vendorIds)->delete();

        DB::table('driver_availability_logs')->whereIn('driver_profile_id', $driverProfileIds)->delete();
        DB::table('driver_status_history')->whereIn('driver_profile_id', $driverProfileIds)->delete();
        DB::table('driver_documents')->whereIn('driver_profile_id', $driverProfileIds)->delete();
        DB::table('deliveries')->whereIn('driver_profile_id', $driverProfileIds)->delete();
        DB::table('driver_profiles')->whereIn('id', $driverProfileIds)->delete();

        DB::table('user_roles')->whereIn('user_id', $userIds)->delete();
        DB::table('users')->whereIn('id', $userIds)->delete();

        // Tarifs par défaut couvrant chaque zone (évite le 422 zone_not_found/rate_not_configured).
        foreach (DeliveryZone::all() as $zone) {
            DeliveryRate::updateOrCreate(
                ['zone_id' => $zone->id, 'vendor_id' => null],
                ['price' => 1000, 'is_active' => true],
            );
        }
    }

    private function ensureZonesAndRates(): array
    {
        return DeliveryZone::active()->orderBy('sort_order')->get()->values()->all();
    }

    // ------------------------------------------------------------------ affichage

    private function printCredentials(): void
    {
        $rows = [];

        foreach (self::VENDOR_ACCOUNTS as $account) {
            $rows[] = [$account['email'], self::PASSWORD, 'vendeur', $account['business_name']];
        }

        foreach (self::CLIENT_ACCOUNTS as $account) {
            $rows[] = [$account['email'], self::PASSWORD, 'client', '—'];
        }

        foreach (self::DRIVER_ACCOUNTS as $account) {
            $rows[] = [$account['email'], self::PASSWORD, 'livreur', '—'];
        }

        $rows[] = ['admin@local', 'password', 'admin', 'Dashboard'];

        $this->command->newLine();
        $this->command->info('======= Identifiants de connexion (BeneFood) =======');
        $this->command->table(['Email', 'Mot de passe', 'Rôle', 'Boutique'], $rows);
        $this->command->info('Connexion via l’API : POST /api/v1/auth/login  { login: <email>, password }');
        $this->command->newLine();
    }
}
