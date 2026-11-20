<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\GeoCountryResource;
use App\Http\Resources\GeoDivisionResource;
use App\Http\Resources\GeoLocalityResource;
use App\Models\GeoCountry;
use App\Models\GeoDivision;
use App\Models\GeoLocality;
use App\Services\GeocodingService;
use App\Support\Api;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator as Paginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;

/**
 * Référentiel géographique partagé (pays, subdivisions, localités) et
 * géocodage serveur. Toutes les données administratives proviennent de
 * sources officielles et conservent leur code, leur source et leur date.
 */
class GeoController extends Controller
{
    public function __construct(private readonly GeocodingService $geocodingService) {}

    public function countries(): JsonResponse
    {
        $countries = Cache::remember(
            'geo:countries',
            now()->addSeconds((int) config('beninfood.geography.cache_ttl', 3600)),
            fn () => GeoCountry::query()->active()->orderBy('name')->get(),
        );

        return Api::ok(GeoCountryResource::collection($countries)->resolve());
    }

    public function divisions(Request $request): JsonResponse
    {
        $data = $request->validate([
            'country' => ['sometimes', 'string', 'size:2', 'exists:geo_countries,code'],
            'level' => ['sometimes', 'string', 'max:50'],
            'parent_id' => ['sometimes', 'integer', 'exists:geo_divisions,id'],
            'q' => ['sometimes', 'string', 'max:100'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'page' => ['sometimes', 'integer', 'min:1'],
        ]);

        $country = isset($data['country'])
            ? GeoCountry::query()->where('code', strtoupper($data['country']))->firstOrFail()
            : null;

        $query = GeoDivision::query()
            ->active()
            ->when($country !== null, fn ($builder) => $builder->where('country_id', $country->id))
            ->when(isset($data['level']), fn ($builder) => $builder->where('level', $data['level']))
            ->when(isset($data['parent_id']), fn ($builder) => $builder->where('parent_id', $data['parent_id']))
            ->when(isset($data['q']) && trim($data['q']) !== '', function ($builder) use ($data): void {
                $term = trim($data['q']);
                $builder->where(function ($inner) use ($term): void {
                    $inner->where('name', 'like', '%'.$term.'%')
                        ->orWhere('name_normalized', 'like', '%'.$term.'%')
                        ->orWhere('code', 'like', '%'.$term.'%');
                });
            })
            ->with('country', 'parent.parent.parent')
            ->orderBy('level')
            ->orderBy('name');

        $divisions = Cache::remember(
            'geo:divisions:'.md5(json_encode($data)),
            now()->addSeconds((int) config('beninfood.geography.cache_ttl', 3600)),
            fn () => $query->get(),
        );

        $paginator = $this->paginate($divisions, (int) ($data['per_page'] ?? config('beninfood.pagination.per_page', 15)), $data['page'] ?? null);

        return Api::ok(
            GeoDivisionResource::collection($paginator->items())->resolve(),
            $this->paginationMeta($paginator),
        );
    }

    public function localities(Request $request): JsonResponse
    {
        $data = $request->validate([
            'country' => ['sometimes', 'string', 'size:2', 'exists:geo_countries,code'],
            'division_id' => ['sometimes', 'integer', 'exists:geo_divisions,id'],
            'kind' => ['sometimes', 'string', 'max:30'],
            'q' => ['sometimes', 'string', 'max:100'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'page' => ['sometimes', 'integer', 'min:1'],
        ]);

        $country = isset($data['country'])
            ? GeoCountry::query()->where('code', strtoupper($data['country']))->firstOrFail()
            : null;

        $query = GeoLocality::query()
            ->active()
            ->when($country !== null, fn ($builder) => $builder->where('country_id', $country->id))
            ->when(isset($data['division_id']), fn ($builder) => $builder->where('division_id', $data['division_id']))
            ->when(isset($data['kind']), fn ($builder) => $builder->where('kind', $data['kind']))
            ->when(isset($data['q']) && trim($data['q']) !== '', function ($builder) use ($data): void {
                $term = trim($data['q']);
                $builder->where(function ($inner) use ($term): void {
                    $inner->where('name', 'like', '%'.$term.'%')
                        ->orWhere('name_normalized', 'like', '%'.$term.'%')
                        ->orWhere('code', 'like', '%'.$term.'%');
                });
            })
            ->with('division.country', 'division.parent.parent.parent')
            ->orderBy('name');

        $localities = Cache::remember(
            'geo:localities:'.md5(json_encode($data)),
            now()->addSeconds((int) config('beninfood.geography.cache_ttl', 3600)),
            fn () => $query->get(),
        );

        $paginator = $this->paginate($localities, (int) ($data['per_page'] ?? config('beninfood.pagination.per_page', 15)), $data['page'] ?? null);

        return Api::ok(
            GeoLocalityResource::collection($paginator->items())->resolve(),
            $this->paginationMeta($paginator),
        );
    }

    public function search(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:2', 'max:100'],
            'country' => ['sometimes', 'string', 'size:2'],
            'level' => ['sometimes', 'string', 'max:50'],
            'parent_id' => ['sometimes', 'integer'],
            'division_id' => ['sometimes', 'integer'],
            'limit' => ['sometimes', 'integer', 'min:1', 'max:50'],
        ]);

        $filters = array_intersect_key($data, array_flip(['country', 'level', 'parent_id', 'division_id']));
        $limit = (int) ($data['limit'] ?? config('beninfood.geography.search_per_page', 20));

        return Api::ok(
            $this->geocodingService->searchLocal($data['q'], $filters, $limit),
            [
                'source' => config('beninfood.geography.source'),
                'source_url' => config('beninfood.geography.source_url'),
                'data_updated_at' => config('beninfood.geography.data_updated_at'),
            ],
        );
    }

    public function geocode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:3', 'max:200'],
            'country' => ['sometimes', 'string', 'size:2'],
            'latitude' => ['sometimes', 'required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'required_with:latitude', 'numeric', 'between:-180,180'],
            'limit' => ['sometimes', 'integer', 'min:1', 'max:5'],
        ]);

        $context = array_intersect_key($data, array_flip(['country', 'latitude', 'longitude']));

        return Api::ok($this->geocodingService->geocode(
            $data['q'],
            $context,
            (int) ($data['limit'] ?? 5),
        ));
    }

    public function reverse(Request $request): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'country' => ['sometimes', 'string', 'size:2'],
        ]);

        $result = $this->geocodingService->reverse(
            (float) $data['latitude'],
            (float) $data['longitude'],
            $data['country'] ?? null,
        );

        if ($result === null) {
            return Api::error('Aucune localité connue pour ces coordonnées.', 'not_found', 404);
        }

        return Api::ok($result);
    }

    /**
     * @param  Collection<int, mixed>  $items
     */
    private function paginate($items, int $perPage, mixed $page): LengthAwarePaginator
    {
        $page = max(1, (int) ($page ?? 1));

        return new Paginator($items->forPage($page, $perPage)->values(), $items->count(), $perPage, $page, [
            'path' => request()->url(),
            'query' => request()->query(),
        ]);
    }

    /**
     * @return array<string, int>
     */
    private function paginationMeta(LengthAwarePaginator $paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page' => max(1, $paginator->lastPage()),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ];
    }
}
