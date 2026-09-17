@extends('layouts.app')

@section('content')
<x-admin.page-header title="{{ $driver->user?->name ?? 'Livreur' }}" subtitle="Profil livreur — inscription {{ $driver->created_at?->format('d/m/Y') }}" :back="route('admin.drivers.index')">
    {!! \App\Support\AdminLabels::driverStatusBadge($driver->status) !!}
    {!! \App\Support\AdminLabels::availableBadge((bool) $driver->available) !!}
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

<div class="row">
    <div class="col-md-4">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Informations</h6>
                <ul class="list-unstyled mb-0" style="font-size: 14px;">
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Téléphone</span><strong>{{ $driver->user?->phone ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Email</span><strong>{{ $driver->user?->email ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Type</span><strong>{{ $driver->type === 'beninfood' ? 'Beninfood' : 'Indépendant' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Véhicule</span><strong>{{ $driver->vehicle ?? '—' }}</strong></li>
                    <li class="d-flex justify-content-between py-1"><span style="color: var(--text-muted);">Note</span><strong>{{ $driver->rating ?? '—' }}</strong></li>
                </ul>
            </div>
        </div>

        <!-- Actions -->
        @if (! in_array($driver->status, ['closed'], true))
            <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                <div class="card-body">
                    <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Actions</h6>
                    @if (! in_array($driver->status, ['active'], true))
                        <form method="POST" action="{{ route('admin.drivers.activate', $driver) }}" class="mb-2">
                            @csrf
                            <button type="submit" class="btn btn-sm btn-block" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px;">
                                <i class="ti ti-check"></i> Activer le livreur
                            </button>
                        </form>
                    @endif
                    @if ($driver->status !== 'suspended')
                        <form method="POST" action="{{ route('admin.drivers.suspend', $driver) }}">
                            @csrf
                            <div class="form-group mb-2">
                                <input type="text" name="reason" class="form-control form-control-sm" placeholder="Motif obligatoire" required minlength="3">
                            </div>
                            <button type="submit" class="btn btn-sm btn-block" style="background-color: var(--benin-orange); color: #FFFFFF; border-radius: 8px;">
                                <i class="ti ti-pause"></i> Suspendre
                            </button>
                        </form>
                    @endif
                    <form method="POST" action="{{ route('admin.drivers.close', $driver) }}" class="mt-2"
                          onsubmit="return confirm('Fermer définitivement ce compte livreur ?');">
                        @csrf
                        <div class="form-group mb-2">
                            <input type="text" name="reason" class="form-control form-control-sm" placeholder="Motif obligatoire" required minlength="3">
                        </div>
                        <button type="submit" class="btn btn-sm btn-block" style="background-color: var(--benin-red); color: #FFFFFF; border-radius: 8px;">
                            <i class="ti ti-x"></i> Fermer le compte
                        </button>
                    </form>
                </div>
            </div>
        @endif
    </div>

    <div class="col-md-8">
        <!-- Documents -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                    <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Documents</h6>
                </div>
                <div class="table-responsive">
                    <table class="table mb-0" style="font-size: 14px;">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Document</th>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Soumis le</th>
                                <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($driver->documents as $document)
                                <tr>
                                    <td style="font-weight: 600;">{{ \App\Support\AdminLabels::driverDocumentTypeLabel($document->type) }}</td>
                                    <td>{!! \App\Support\AdminLabels::documentStatusBadge($document->status) !!}</td>
                                    <td style="color: var(--text-muted);">{{ $document->created_at?->format('d/m/Y') ?? '—' }}</td>
                                    <td>
                                        <a href="{{ route('admin.drivers.documents.download', [$driver, $document]) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                            <i class="ti ti-download"></i>
                                        </a>
                                        <form method="POST" action="{{ route('admin.drivers.documents.review', [$driver, $document]) }}" class="d-inline-flex align-items-center" style="gap: 6px;">
                                            @csrf
                                            <select name="status" class="form-control form-control-sm" style="width: auto;">
                                                @foreach (\App\Enums\DriverDocumentStatus::cases() as $docStatus)
                                                    <option value="{{ $docStatus->value }}" @selected($document->status === $docStatus->value)>{{ ucfirst($docStatus->value) }}</option>
                                                @endforeach
                                            </select>
                                            <input type="text" name="reason" class="form-control form-control-sm" placeholder="Motif (rejet)" style="width: 140px;">
                                            <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px;">
                                                <i class="ti ti-check"></i>
                                            </button>
                                        </form>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="4" class="text-center py-4" style="color: var(--text-muted);">Aucun document soumis.</td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Historique de statut -->
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <h6 class="font-weight-bold mb-3" style="color: var(--text-dark);">Historique des statuts</h6>
                @forelse ($driver->statusHistory->sortByDesc('created_at') as $history)
                    <div class="d-flex align-items-start mb-3">
                        <div class="mr-3" style="width: 10px; height: 10px; border-radius: 50%; background-color: var(--benin-green); margin-top: 6px;"></div>
                        <div>
                            <div style="font-weight: 600; color: var(--text-dark);">{{ $history->from_status ?? '—' }} → {{ $history->to_status }}</div>
                            <small style="color: var(--text-muted);">{{ $history->created_at?->format('d/m/Y H:i') ?? '—' }}@if ($history->reason) — {{ $history->reason }} @endif</small>
                        </div>
                    </div>
                @empty
                    <p class="mb-0" style="color: var(--text-muted);">Aucun historique.</p>
                @endforelse
            </div>
        </div>

        <!-- Dernières livraisons -->
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                    <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Dernières livraisons</h6>
                </div>
                @if (count($driver->deliveries) > 0)
                    <div class="table-responsive">
                        <table class="table mb-0" style="font-size: 14px;">
                            <thead style="background-color: #F9FAFB;">
                                <tr>
                                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Commande</th>
                                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Boutique</th>
                                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Frais</th>
                                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($driver->deliveries->sortByDesc('created_at')->take(10) as $delivery)
                                    <tr>
                                        <td><a href="{{ route('admin.orders.show', $delivery->order) }}" style="color: var(--benin-green); font-family: monospace;">{{ $delivery->order?->reference }}</a></td>
                                        <td style="color: var(--text-muted);">{{ $delivery->order?->vendor?->business_name ?? '—' }}</td>
                                        <td>{{ \App\Support\AdminLabels::priceLabel($delivery->fee) }}</td>
                                        <td style="color: var(--text-muted);">{{ ucfirst(str_replace('_', ' ', $delivery->status)) }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                @else
                    <div class="text-center py-4" style="color: var(--text-muted);">Aucune livraison.</div>
                @endif
            </div>
        </div>
    </div>
</div>
@endsection