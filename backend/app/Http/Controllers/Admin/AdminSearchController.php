<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Complaint;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Parcel;
use App\Models\Payment;
use App\Models\Product;
use App\Models\User;
use App\Models\Vendor;
use App\Support\AdminSearchCatalog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminSearchController extends Controller
{
    public function index(Request $request): View|JsonResponse
    {
        $this->authorize('manage', User::class);

        $query = mb_substr(trim((string) $request->query('q', '')), 0, 80);
        $suggestions = $request->expectsJson();
        $groups = $this->groups($query, $suggestions ? 5 : 25, $suggestions);

        if ($suggestions) {
            return response()->json([
                'query' => $query,
                'groups' => $groups,
                'total' => array_sum(array_map(
                    static fn (array $group): int => count($group['items']),
                    $groups,
                )),
            ]);
        }

        return view('admin.search.index', [
            'query' => $query,
            'groups' => $groups,
        ]);
    }

    /**
     * @return array<int, array{key: string, label: string, icon: string, items: array<int, array{label: string, description: string, url: string, icon: string}>}>
     */
    private function groups(string $query, int $limit, bool $suggestions): array
    {
        if ($query === '') {
            $pages = AdminSearchCatalog::pages();

            if ($suggestions) {
                $pages = array_slice($pages, 0, 8);
            }

            return [[
                'key' => 'pages',
                'label' => $suggestions ? 'Accès rapide' : 'Toutes les pages',
                'icon' => 'ti-view-grid',
                'items' => AdminSearchCatalog::items($pages),
            ]];
        }

        if (mb_strlen($query) < 2) {
            return [];
        }

        $groups = [];
        $pageMatches = AdminSearchCatalog::search($query);

        if ($suggestions) {
            $pageMatches = array_slice($pageMatches, 0, 3);
        }

        if ($pageMatches !== []) {
            $groups[] = [
                'key' => 'pages',
                'label' => 'Pages',
                'icon' => 'ti-view-grid',
                'items' => AdminSearchCatalog::items($pageMatches),
            ];
        }

        $like = '%'.addcslashes($query, '\\%_').'%';

        $orders = Order::query()
            ->with(['user:id,name', 'vendor:id,business_name'])
            ->where(function ($builder) use ($like): void {
                $builder->where('reference', 'like', $like)
                    ->orWhereHas('user', fn ($user) => $user
                        ->where('name', 'like', $like)
                        ->orWhere('phone', 'like', $like))
                    ->orWhereHas('vendor', fn ($vendor) => $vendor
                        ->where('business_name', 'like', $like));
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (Order $order): array => [
                'label' => $order->reference,
                'description' => $this->context([
                    $order->user?->name,
                    $order->vendor?->business_name,
                    $this->money($order->total),
                ]),
                'url' => route('admin.orders.show', $order),
                'icon' => 'ti-shopping-cart',
            ])
            ->all();

        $this->pushGroup($groups, 'orders', 'Commandes', 'ti-shopping-cart', $orders);

        $clients = User::query()
            ->whereHas('roles', fn ($role) => $role->where('slug', 'client'))
            ->where(function ($builder) use ($like): void {
                $builder->where('name', 'like', $like)
                    ->orWhere('phone', 'like', $like)
                    ->orWhere('email', 'like', $like);
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (User $user): array => [
                'label' => $user->name,
                'description' => $this->context([$user->phone, $user->email]) ?: 'Compte client',
                'url' => route('admin.clients.show', $user),
                'icon' => 'ti-user',
            ])
            ->all();

        $this->pushGroup($groups, 'clients', 'Clients', 'ti-user', $clients);

        $drivers = DriverProfile::query()
            ->with(['user:id,name,phone,email'])
            ->where(function ($builder) use ($like): void {
                $builder->where('vehicle', 'like', $like)
                    ->orWhereHas('user', fn ($user) => $user
                        ->where('name', 'like', $like)
                        ->orWhere('phone', 'like', $like)
                        ->orWhere('email', 'like', $like));
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (DriverProfile $driver): array => [
                'label' => $driver->user?->name ?? 'Livreur',
                'description' => $this->context([$driver->vehicle, $driver->user?->phone]) ?: 'Profil livreur',
                'url' => route('admin.drivers.show', $driver),
                'icon' => 'ti-truck',
            ])
            ->all();

        $this->pushGroup($groups, 'drivers', 'Livreurs', 'ti-truck', $drivers);

        $vendors = Vendor::query()
            ->where(function ($builder) use ($like): void {
                $builder->where('business_name', 'like', $like)
                    ->orWhere('legal_name', 'like', $like)
                    ->orWhere('phone', 'like', $like)
                    ->orWhere('email', 'like', $like)
                    ->orWhere('city', 'like', $like);
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (Vendor $vendor): array => [
                'label' => $vendor->business_name,
                'description' => $this->context([$vendor->city, $vendor->phone]) ?: 'Boutique partenaire',
                'url' => route('admin.vendors.show', $vendor),
                'icon' => 'ti-briefcase',
            ])
            ->all();

        $this->pushGroup($groups, 'vendors', 'Vendeurs', 'ti-briefcase', $vendors);

        $products = Product::query()
            ->with(['vendor:id,business_name'])
            ->where(function ($builder) use ($like): void {
                $builder->where('name', 'like', $like)
                    ->orWhere('description', 'like', $like)
                    ->orWhereHas('vendor', fn ($vendor) => $vendor
                        ->where('business_name', 'like', $like));
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (Product $product): array => [
                'label' => $product->name,
                'description' => $this->context([$product->vendor?->business_name, $this->money($product->price)]),
                'url' => route('admin.products.show', $product),
                'icon' => 'ti-package',
            ])
            ->all();

        $this->pushGroup($groups, 'products', 'Produits', 'ti-package', $products);

        $parcels = Parcel::query()
            ->with(['user:id,name'])
            ->where(function ($builder) use ($like): void {
                $builder->where('reference', 'like', $like)
                    ->orWhere('description', 'like', $like)
                    ->orWhereHas('user', fn ($user) => $user
                        ->where('name', 'like', $like)
                        ->orWhere('phone', 'like', $like));
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (Parcel $parcel): array => [
                'label' => $parcel->reference,
                'description' => $this->context([$parcel->user?->name, $parcel->status?->value]),
                'url' => route('admin.parcels.show', $parcel),
                'icon' => 'ti-package',
            ])
            ->all();

        $this->pushGroup($groups, 'parcels', 'Colis', 'ti-package', $parcels);

        $complaints = Complaint::query()
            ->with(['user:id,name', 'order:id,reference'])
            ->where(function ($builder) use ($like): void {
                $builder->where('subject', 'like', $like)
                    ->orWhere('description', 'like', $like)
                    ->orWhere('type', 'like', $like)
                    ->orWhereHas('user', fn ($user) => $user
                        ->where('name', 'like', $like)
                        ->orWhere('phone', 'like', $like))
                    ->orWhereHas('order', fn ($order) => $order
                        ->where('reference', 'like', $like));
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (Complaint $complaint): array => [
                'label' => $complaint->subject,
                'description' => $this->context([$complaint->user?->name, $complaint->order?->reference]) ?: 'Réclamation client',
                'url' => route('admin.complaints.show', $complaint),
                'icon' => 'ti-comments',
            ])
            ->all();

        $this->pushGroup($groups, 'complaints', 'Réclamations', 'ti-comments', $complaints);

        $payments = Payment::query()
            ->with(['order:id,reference'])
            ->where(function ($builder) use ($like): void {
                $builder->where('reference', 'like', $like)
                    ->orWhere('gateway_txn_id', 'like', $like)
                    ->orWhereHas('order', fn ($order) => $order
                        ->where('reference', 'like', $like));
            })
            ->latest('created_at')
            ->limit($limit)
            ->get()
            ->map(fn (Payment $payment): array => [
                'label' => $payment->reference,
                'description' => $this->context([$payment->order?->reference, $this->money($payment->amount)]),
                'url' => route('admin.payments.show', $payment),
                'icon' => 'ti-wallet',
            ])
            ->all();

        $this->pushGroup($groups, 'payments', 'Paiements', 'ti-wallet', $payments);

        return $groups;
    }

    /**
     * @param  array<int, array{key: string, label: string, icon: string, items: array<int, array{label: string, description: string, url: string, icon: string}>}>  $groups
     * @param  array<int, array{label: string, description: string, url: string, icon: string}>  $items
     */
    private function pushGroup(array &$groups, string $key, string $label, string $icon, array $items): void
    {
        if ($items === []) {
            return;
        }

        $groups[] = [
            'key' => $key,
            'label' => $label,
            'icon' => $icon,
            'items' => $items,
        ];
    }

    /**
     * @param  array<int, string|null>  $parts
     */
    private function context(array $parts): string
    {
        return implode(' · ', array_values(array_filter(
            $parts,
            static fn (?string $part): bool => $part !== null && trim($part) !== '',
        )));
    }

    private function money(?int $amount): string
    {
        return number_format((int) $amount, 0, ',', ' ').' FCFA';
    }
}
