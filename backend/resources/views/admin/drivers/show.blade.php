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
@if ($errors->any())
    <div class="alert alert-danger" role="alert">
        <strong>La décision n’a pas été enregistrée.</strong>
        <ul class="mb-0 mt-1">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    </div>
@endif

<div class="row">
    <div class="col-md-4">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div class="d-flex align-items-center mb-3">
                    <x-admin.avatar :user="$driver->user" size="lg" class="mr-3" :online="$driver->available" />
                    <div>
                        <strong style="color: var(--text-dark); display: block;">{{ $driver->user?->name ?? 'Livreur' }}</strong>
                        <small style="color: var(--text-muted);">{{ $driver->user?->phone ?? 'Téléphone non renseigné' }}</small>
                    </div>
                </div>
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
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-header d-flex justify-content-between align-items-center" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                <div>
                    <h6 class="font-weight-bold mb-1" style="color: var(--text-dark);">Documents du livreur</h6>
                    <small style="color: var(--text-muted);">Consultez chaque pièce avant de la valider. Les fichiers restent privés.</small>
                </div>
                <span class="badge badge-light">{{ $driver->documents->count() }} document(s)</span>
            </div>
            <div class="card-body">
                @forelse ($driver->documents as $document)
                    @php
                        $extension = strtolower(pathinfo($document->file_path, PATHINFO_EXTENSION));
                        $documentUrl = route('admin.drivers.documents.download', [$driver, $document]);
                    @endphp
                    <article class="mb-4 p-3" style="border: 1px solid var(--border-color); border-radius: 12px; background: #FFFFFF;">
                        <div class="d-flex flex-wrap justify-content-between align-items-start mb-3" style="gap: 12px;">
                            <div>
                                <h6 class="mb-1" style="font-weight: 700; color: var(--text-dark);">
                                    {{ \App\Support\AdminLabels::driverDocumentTypeLabel($document->type) }}
                                </h6>
                                <small style="color: var(--text-muted);">
                                    Envoyé le {{ $document->created_at?->format('d/m/Y à H:i') ?? '—' }}
                                    @if ($document->reviewed_at)
                                        · Vérifié le {{ $document->reviewed_at->format('d/m/Y à H:i') }}
                                        @if ($document->reviewer)
                                            par {{ $document->reviewer->name }}
                                        @endif
                                    @endif
                                </small>
                            </div>
                            {!! \App\Support\AdminLabels::documentStatusBadge($document->status) !!}
                        </div>

                        @if (in_array($extension, ['jpg', 'jpeg', 'png', 'webp'], true))
                            <a href="{{ $documentUrl }}" target="_blank" rel="noopener" aria-label="Ouvrir le document en grand">
                                <img src="{{ $documentUrl }}" alt="{{ \App\Support\AdminLabels::driverDocumentTypeLabel($document->type) }}" loading="lazy"
                                     style="display: block; width: 100%; max-height: 460px; object-fit: contain; background: #F6F8F7; border-radius: 8px;">
                            </a>
                        @elseif ($extension === 'pdf')
                            <iframe src="{{ $documentUrl }}" title="{{ \App\Support\AdminLabels::driverDocumentTypeLabel($document->type) }}"
                                    loading="lazy" style="width: 100%; height: 480px; border: 1px solid var(--border-color); border-radius: 8px;"></iframe>
                        @else
                            <a href="{{ $documentUrl }}" target="_blank" rel="noopener" class="btn btn-sm btn-outline-secondary mb-3">
                                <i class="ti ti-external-link mr-1"></i> Ouvrir le fichier
                            </a>
                        @endif

                        @if ($document->status === \App\Enums\DriverDocumentStatus::Invalid->value && $document->reason)
                            <div class="alert alert-danger mt-3 mb-0 py-2">
                                <strong>Motif du rejet :</strong> {{ $document->reason }}
                            </div>
                        @endif

                        <form method="POST" action="{{ route('admin.drivers.documents.review', [$driver, $document]) }}"
                              class="mt-3 d-flex flex-wrap align-items-center" style="gap: 8px;">
                            @csrf
                            <label for="document-status-{{ $document->id }}" class="mb-0 font-weight-bold">Décision</label>
                            <select id="document-status-{{ $document->id }}" name="status" class="form-control form-control-sm"
                                    style="width: auto;" onchange="this.form.querySelector('[name=reason]').required = this.value === 'invalid';">
                                <option value="submitted" @selected($document->status === 'submitted')>En attente</option>
                                <option value="valid" @selected($document->status === 'valid')>Valider</option>
                                <option value="invalid" @selected($document->status === 'invalid')>Rejeter</option>
                            </select>
                            <input type="text" name="reason" class="form-control form-control-sm"
                                   value="{{ $document->reason }}" placeholder="Motif obligatoire en cas de rejet"
                                   aria-label="Motif du rejet" minlength="3" maxlength="500"
                                   @required($document->status === \App\Enums\DriverDocumentStatus::Invalid->value)
                                   style="flex: 1 1 220px; max-width: 360px;">
                            <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px;">
                                <i class="ti ti-check mr-1"></i> Enregistrer la décision
                            </button>
                        </form>
                    </article>
                @empty
                    <div class="text-center py-4" style="color: var(--text-muted);">
                        Aucun document soumis par ce livreur.
                    </div>
                @endforelse
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
                                        <td style="color: var(--text-muted);">{{ ucfirst(str_replace('_', ' ', $delivery->status->value)) }}</td>
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