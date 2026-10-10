@extends('layouts.app')

@section('content')
<x-admin.page-header title="Colis" subtitle="Cahier v1.0 — Phase 3 — Envois de colis">
    <a href="{{ route('admin.dashboard') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-home"></i> Dashboard
    </a>
</x-admin.page-header>

@if (session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif
@if (session('error'))
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        {{ session('error') }}
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
    </div>
@endif

<!-- Status tabs -->
@php
    $statusChips = [
        ['key' => '', 'label' => 'Tous', 'count' => $counts['all'], 'fg' => 'var(--benin-green)'],
        ['key' => 'awaiting_payment', 'label' => 'À payer', 'count' => $counts['awaiting_payment'], 'fg' => 'var(--benin-orange)'],
        ['key' => 'paid', 'label' => 'À assigner', 'count' => $counts['paid'], 'fg' => 'var(--benin-orange)'],
        ['key' => 'in_progress', 'label' => 'En cours', 'count' => $counts['in_progress'], 'fg' => 'var(--text-dark)'],
        ['key' => 'delivered', 'label' => 'Livrés', 'count' => $counts['delivered'], 'fg' => 'var(--benin-green)'],
        ['key' => 'cancelled', 'label' => 'Annulés', 'count' => $counts['cancelled'], 'fg' => 'var(--benin-red)'],
    ];
@endphp
<div class="row mb-4">
    <div class="col-12">
        <ul class="nav" style="gap: 8px; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;">
            @foreach ($statusChips as $chip)
                <li class="nav-item">
                    <a class="btn btn-sm"
                       href="{{ route('admin.parcels.index', array_merge(['status' => $chip['key'] ?: null, 'q' => $filters['q'] ?? null])) }}"
                       style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === $chip['key'] ? 'background-color: '.$chip['fg'].'; color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                        {{ $chip['label'] }} <span class="ml-1" style="font-weight: 700;">{{ $chip['count'] }}</span>
                    </a>
                </li>
            @endforeach
        </ul>
    </div>
</div>

<!-- Filters -->
<form method="GET" action="{{ route('admin.parcels.index') }}">
    @if (! empty($filters['status']))
        <input type="hidden" name="status" value="{{ $filters['status'] }}">
    @endif
    <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
        <div class="card-body py-3">
            <div class="row align-items-center">
                <div class="col-md-4">
                    <input type="text" name="q" value="{{ $filters['q'] ?? '' }}" class="form-control" placeholder="Référence, expéditeur...">
                </div>
                <div class="col-md-2">
                    <input type="date" name="from" value="{{ $filters['from'] ?? '' }}" class="form-control" title="Du">
                </div>
                <div class="col-md-2">
                    <input type="date" name="to" value="{{ $filters['to'] ?? '' }}" class="form-control" title="Au">
                </div>
                <div class="col-md-4 d-flex">
                    <button type="submit" class="btn mr-2" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-search"></i>
                    </button>
                    <a href="{{ route('admin.parcels.index') }}" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                        Réinitialiser
                    </a>
                </div>
            </div>
        </div>
    </div>
</form>

<!-- Table -->
<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Référence</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Expéditeur</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Livreur</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Distance</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Frais</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Paiement</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Date</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($parcels as $parcel)
                        @php
                            $paymentBadge = $parcel->payment
                                ? \App\Support\AdminLabels::paymentStatusBadge($parcel->payment->status->value)
                                : '<span class="badge badge-pill" style="background:#ECEFF1;color:#37474F;">Non initié</span>';
                        @endphp
                        <tr>
                            <td class="py-3"><a href="{{ route('admin.parcels.show', $parcel) }}" style="color: var(--benin-green); font-weight: 600; font-family: monospace;">{{ $parcel->reference }}</a></td>
                            <td class="py-3" style="color: var(--text-dark);">{{ $parcel->user?->name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $parcel->driverProfile?->user?->name ?? '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark);">{{ $parcel->distance_km !== null ? number_format((float) $parcel->distance_km, 1).' km' : '—' }}</td>
                            <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ \App\Support\AdminLabels::priceLabel($parcel->delivery_fee) }}</td>
                            <td class="py-3">{!! $paymentBadge !!}</td>
                            <td class="py-3">{!! \App\Support\AdminLabels::parcelStatusBadge($parcel->status->value) !!}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $parcel->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.parcels.show', $parcel) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                    <i class="ti ti-eye"></i> Voir
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="9" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-package" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun colis trouvé.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($parcels->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $parcels->links() }}
        </div>
    @endif
</div>
@endsection