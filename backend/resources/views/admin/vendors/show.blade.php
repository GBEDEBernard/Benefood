@extends('layouts.app')

@section('content')
<x-admin.page-header title="Détail vendeur" :subtitle="$vendor->business_name" :back="route('admin.vendors.index')">
    <div class="d-flex align-items-center" style="gap: 8px;">
        {!! \App\Support\AdminLabels::vendorStatusBadge($vendor->status) !!}

        @if (in_array($vendor->status, [\App\Enums\VendorStatus::Registered->value, \App\Enums\VendorStatus::PendingVerification->value, \App\Enums\VendorStatus::Verified->value, \App\Enums\VendorStatus::Suspended->value], true))
            <form method="POST" action="{{ route('admin.vendors.approve', $vendor) }}" onsubmit="return confirm('Valider et activer ce vendeur ?');">
                @csrf
                <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-check"></i> Approuver
                </button>
            </form>
        @endif

        @if ($vendor->status === \App\Enums\VendorStatus::Suspended->value)
            <form method="POST" action="{{ route('admin.vendors.activate', $vendor) }}" onsubmit="return confirm('Réactiver ce vendeur ?');">
                @csrf
                <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                    <i class="ti ti-reload"></i> Réactiver
                </button>
            </form>
        @endif

        @if (! in_array($vendor->status, [\App\Enums\VendorStatus::Suspended->value, \App\Enums\VendorStatus::Closed->value], true))
            <button class="btn btn-sm" style="background-color: var(--benin-red); color: #FFFFFF; border-radius: 8px; font-weight: 500;" data-toggle="modal" data-target="#suspend-modal">
                <i class="ti ti-alert"></i> Suspendre
            </button>
        @endif

        @if ($vendor->status !== \App\Enums\VendorStatus::Closed->value)
            <button class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--benin-red);" data-toggle="modal" data-target="#close-modal">
                <i class="ti ti-x"></i> Fermer
            </button>
        @endif
    </div>
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

<!-- Tabs -->
<ul class="nav nav-tabs mb-4" role="tablist" style="border-bottom-color: var(--border-color);">
    <li class="nav-item">
        <a class="nav-link active" id="infos-tab" data-toggle="tab" href="#infos" role="tab" style="color: var(--text-dark); font-weight: 600;">
            <i class="ti ti-info-alt mr-1"></i> Informations
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="documents-tab" data-toggle="tab" href="#documents" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-file mr-1"></i> Documents
            @if ($vendor->documents->where('status', 'submitted')->count() > 0)
                <span class="badge ml-1" style="background: var(--benin-orange); color: #fff; font-size: 11px;">{{ $vendor->documents->where('status', 'submitted')->count() }}</span>
            @endif
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="produits-tab" data-toggle="tab" href="#produits" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-shopping-cart mr-1"></i> Produits
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="contacts-tab" data-toggle="tab" href="#contacts" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-people mr-1"></i> Contacts & Zones
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="settings-tab" data-toggle="tab" href="#settings" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-settings mr-1"></i> Paramètres & Horaires
        </a>
    </li>
    <li class="nav-item">
        <a class="nav-link" id="history-tab" data-toggle="tab" href="#history" role="tab" style="color: var(--text-muted); font-weight: 600;">
            <i class="ti ti-time mr-1"></i> Historique
        </a>
    </li>
</ul>

<div class="tab-content">
    <!-- ========== INFOS ========== -->
    <div class="tab-pane fade show active" id="infos" role="tabpanel">
        <div class="row">
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Informations de la boutique</h6>
                    </div>
                    <div class="card-body">
                        <table class="table table-borderless mb-0" style="color: var(--text-dark);">
                            <tr><td style="color: var(--text-muted); width: 150px;">Nom commercial</td><td style="font-weight: 600;">{{ $vendor->business_name }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Nom légal</td><td>{{ $vendor->legal_name ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">IFU</td><td style="font-family: monospace;">{{ $vendor->ifu ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Téléphone</td><td>{{ $vendor->phone }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Email</td><td>{{ $vendor->email ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Ville</td><td>{{ $vendor->city ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Adresse</td><td>{{ $vendor->address ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Description</td><td>{{ $vendor->description ?? '—' }}</td></tr>
                            @if ($vendor->latitude && $vendor->longitude)
                            <tr><td style="color: var(--text-muted);">GPS</td><td style="font-family: monospace;">{{ $vendor->latitude }}, {{ $vendor->longitude }}</td></tr>
                            @endif
                        </table>
                    </div>
                </div>
            </div>
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Compte associé & dates</h6>
                    </div>
                    <div class="card-body">
                        <table class="table table-borderless mb-0" style="color: var(--text-dark);">
                            <tr>
                                <td style="color: var(--text-muted); width: 150px;">Utilisateur</td>
                                <td>
                                    {{ $vendor->user?->name ?? '—' }}
                                    <br><small style="color: var(--text-muted);">{{ $vendor->user?->email ?? $vendor->user?->phone ?? '' }}</small>
                                </td>
                            </tr>
                            <tr><td style="color: var(--text-muted);">Statut</td><td>{!! \App\Support\AdminLabels::vendorStatusBadge($vendor->status) !!}</td></tr>
                            <tr><td style="color: var(--text-muted);">Créé le</td><td>{{ $vendor->created_at?->format('d/m/Y H:i') }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Approuvé le</td><td>{{ $vendor->approved_at?->format('d/m/Y H:i') ?? '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Fermé le</td><td>{{ $vendor->closed_at?->format('d/m/Y H:i') ?? '—' }}</td></tr>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- ========== DOCUMENTS ========== -->
    <div class="tab-pane fade" id="documents" role="tabpanel">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Type</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Statut</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Raison</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Document</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($vendor->documents as $document)
                                <tr>
                                    <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ \App\Support\AdminLabels::documentTypeLabel($document->type) }}</td>
                                    <td class="py-3">{!! \App\Support\AdminLabels::documentStatusBadge($document->status) !!}</td>
                                    <td class="py-3" style="color: var(--text-muted); max-width: 200px;">{{ $document->reason ?? '—' }}</td>
                                    <td class="py-3">
                                        <a href="{{ route('admin.vendors.documents.download', [$vendor, $document]) }}" target="_blank" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
                                            <i class="ti ti-download"></i> Voir
                                        </a>
                                    </td>
                                    <td class="py-3">
                                        @if ($document->status === 'submitted')
                                        <div class="d-flex" style="gap: 6px;">
                                            <form method="POST" action="{{ route('admin.vendors.documents.review', [$vendor, $document]) }}" onsubmit="return confirm('Valider ce document ?');">
                                                @csrf
                                                <input type="hidden" name="status" value="valid">
                                                <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #fff; border-radius: 8px; padding: 4px 10px;">
                                                    <i class="ti ti-check"></i>
                                                </button>
                                            </form>
                                            <form method="POST" action="{{ route('admin.vendors.documents.review', [$vendor, $document]) }}">
                                                @csrf
                                                <input type="hidden" name="status" value="invalid">
                                                <input type="hidden" name="reason" value="Non conforme">
                                                <button type="submit" class="btn btn-sm" style="background-color: var(--benin-red); color: #fff; border-radius: 8px; padding: 4px 10px;" onclick="event.preventDefault(); var r=prompt('Raison du rejet :','Non conforme'); if(r && r.trim().length>0){this.closest('form').querySelector('input[name=reason]').value=r.trim(); this.closest('form').submit();}">
                                                    <i class="ti ti-x"></i>
                                                </button>
                                            </form>
                                        </div>
                                        @endif
                                    </td>
                                </tr>
                            @empty
                                <tr><td colspan="5" class="text-center py-5" style="color: var(--text-muted);">Aucun document soumis.</td></tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <!-- ========== PRODUITS ========== -->
    <div class="tab-pane fade" id="produits" role="tabpanel">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0">
                        <thead style="background-color: #F9FAFB;">
                            <tr>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Nom</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Prix</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Unité</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Stock</th>
                                <th class="border-0 py-3" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Statut</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($vendor->products as $product)
                                <tr>
                                    <td class="py-3" style="color: var(--text-dark); font-weight: 600;">{{ $product->name }}</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ number_format($product->price, 0, ',', ' ') }} FCFA</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ $product->unit }}</td>
                                    <td class="py-3" style="color: var(--text-muted);">{{ $product->stock_qty ?? '∞' }}</td>
                                    <td class="py-3">
                                        @if ($product->is_active)
                                            <span class="badge badge-pill" style="background-color: #E8F5E9; color: #2E7D32; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Actif</span>
                                        @else
                                            <span class="badge badge-pill" style="background-color: #FFEBEE; color: #C62828; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Inactif</span>
                                        @endif
                                    </td>
                                </tr>
                            @empty
                                <tr><td colspan="5" class="text-center py-5" style="color: var(--text-muted);">Aucun produit.</td></tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <!-- ========== CONTACTS & ZONES ========== -->
    <div class="tab-pane fade" id="contacts" role="tabpanel">
        <div class="row">
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Contacts</h6>
                    </div>
                    <div class="card-body p-0">
                        @forelse ($vendor->contacts as $contact)
                        <div class="px-3 py-3" style="border-bottom: 1px solid var(--border-color);">
                            <div class="d-flex justify-content-between align-items-center">
                                <div>
                                    <strong style="color: var(--text-dark);">{{ $contact->name }}</strong>
                                    @if ($contact->role) <small style="color: var(--text-muted);">({{ $contact->role }})</small> @endif
                                    @if ($contact->is_primary)
                                        <span class="badge ml-1" style="background: #E8F5E9; color: var(--benin-green); font-size: 10px;">Principal</span>
                                    @endif
                                </div>
                            </div>
                            <div class="mt-1">
                                @if ($contact->phone) <small style="color: var(--text-muted);"><i class="ti ti-mobile mr-1"></i>{{ $contact->phone }}</small> @endif
                                @if ($contact->email) <small class="ml-2" style="color: var(--text-muted);"><i class="ti ti-email mr-1"></i>{{ $contact->email }}</small> @endif
                            </div>
                        </div>
                        @empty
                            <div class="text-center py-4" style="color: var(--text-muted);">Aucun contact</div>
                        @endforelse
                    </div>
                </div>
            </div>
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Zones de livraison</h6>
                    </div>
                    <div class="card-body">
                        @forelse ($vendor->zones as $zone)
                            <span class="badge mr-1 mb-1" style="background-color: #E1F5FE; color: #0277BD; font-weight: 600; padding: 6px 12px; border-radius: 20px;">
                                <i class="ti ti-map-pin mr-1"></i>{{ $zone->name }}<small class="ml-1">({{ $zone->city }})</small>
                            </span>
                        @empty
                            <div class="text-center py-4" style="color: var(--text-muted);">Aucune zone</div>
                        @endforelse
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- ========== PARAMÈTRES & HORAIRES ========== -->
    <div class="tab-pane fade" id="settings" role="tabpanel">
        <div class="row">
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Paramètres</h6>
                    </div>
                    <div class="card-body">
                        @if ($vendor->settings)
                        <table class="table table-borderless mb-0" style="color: var(--text-dark);">
                            <tr><td style="color: var(--text-muted); width: 200px;">Taux commission exception</td><td>{{ $vendor->settings->commission_exception_rate !== null ? $vendor->settings->commission_exception_rate.'%' : '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Part livreur (%)</td><td>{{ $vendor->settings->delivery_fee_share !== null ? $vendor->settings->delivery_fee_share.'%' : '—' }}</td></tr>
                            <tr><td style="color: var(--text-muted);">Délai max. préparation</td><td>{{ $vendor->settings->max_preparation_minutes }} min</td></tr>
                            <tr><td style="color: var(--text-muted);">Acceptation automatique</td>
                                <td>
                                    @if ($vendor->settings->auto_accept)
                                        <span class="badge badge-pill" style="background-color: #E8F5E9; color: #2E7D32; font-weight: 600; padding: 6px 12px; border-radius: 20px;">Activée</span>
                                    @else
                                        <span class="badge badge-pill" style="background-color: #F1F3F4; color: var(--text-muted); font-weight: 600; padding: 6px 12px; border-radius: 20px;">Désactivée</span>
                                    @endif
                                </td>
                            </tr>
                        </table>
                        @else
                            <p class="text-muted mb-0">Aucun paramètre enregistré.</p>
                        @endif
                    </div>
                </div>
            </div>
            <div class="col-lg-6 mb-4">
                <div class="card h-100" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
                    <div class="card-header" style="background: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
                        <h6 class="mb-0" style="color: var(--text-dark); font-weight: 700;">Horaires d'ouverture</h6>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead style="background-color: #F9FAFB;">
                                    <tr>
                                        <th class="border-0" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Jour</th>
                                        <th class="border-0" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Ouverture</th>
                                        <th class="border-0" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Fermeture</th>
                                        <th class="border-0" style="color: var(--text-muted); font-size: 12px; text-transform: uppercase;">Statut</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @php $daysFound = collect($vendor->hours)->pluck('day_of_week')->toArray(); @endphp
                                    @foreach (range(0, 6) as $day)
                                        @php $hour = $vendor->hours->firstWhere('day_of_week', $day); @endphp
                                        <tr>
                                            <td class="py-2" style="color: var(--text-dark); font-weight: 600;">{{ \App\Support\AdminLabels::dayLabel($day) }}</td>
                                            <td class="py-2" style="color: var(--text-muted);">{{ $hour?->opens_at ?? '—' }}</td>
                                            <td class="py-2" style="color: var(--text-muted);">{{ $hour?->closes_at ?? '—' }}</td>
                                            <td class="py-2">
                                                @if ($hour && $hour->is_closed)
                                                    <span class="badge badge-pill" style="background-color: #FFEBEE; color: #C62828; font-weight: 600; padding: 4px 10px; border-radius: 20px; font-size: 11px;">Fermé</span>
                                                @elseif ($hour)
                                                    <span class="badge badge-pill" style="background-color: #E8F5E9; color: #2E7D32; font-weight: 600; padding: 4px 10px; border-radius: 20px; font-size: 11px;">Ouvert</span>
                                                @else
                                                    <span class="badge badge-pill" style="background-color: #F1F3F4; color: var(--text-muted); font-weight: 600; padding: 4px 10px; border-radius: 20px; font-size: 11px;">—</span>
                                                @endif
                                            </td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- ========== HISTORIQUE ========== -->
    <div class="tab-pane fade" id="history" role="tabpanel">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                @forelse ($histories as $entry)
                    <div class="d-flex mb-4 {{ ! $loop->last ? 'pb-4 border-bottom' : '' }}">
                        <div class="mr-3">
                            <div class="rounded-circle d-flex align-items-center justify-content-center" style="width: 36px; height: 36px; background-color: #E8F5E9;">
                                <i class="ti ti-time" style="color: var(--benin-green);"></i>
                            </div>
                        </div>
                        <div class="flex-grow-1">
                            <div class="d-flex justify-content-between">
                                <div>
                                    <strong style="color: var(--text-dark);">{{ $entry->to_status }}</strong>
                                    @if ($entry->from_status) <small style="color: var(--text-muted);">depuis {{ $entry->from_status }}</small> @endif
                                </div>
                                <small style="color: var(--text-muted);">{{ $entry->created_at?->format('d/m/Y H:i') ?? '—' }}</small>
                            </div>
                            @if ($entry->reason)
                                <p class="mb-1 mt-1" style="color: var(--benin-red); font-size: 13px;"><i class="ti ti-info-circle mr-1"></i>{{ $entry->reason }}</p>
                            @endif
                            <small style="color: var(--text-muted);">
                                @if ($entry->actor_id && isset($actors[$entry->actor_id]))
                                    Par {{ $actors[$entry->actor_id] }}
                                @elseif ($entry->actor_type)
                                    Par {{ $entry->actor_type }}
                                @endif
                            </small>
                        </div>
                    </div>
                @empty
                    <div class="text-center py-5" style="color: var(--text-muted);">
                        <i class="ti ti-time" style="font-size: 40px;"></i>
                        <p class="mt-2 mb-0">Aucun historique de statut.</p>
                    </div>
                @endforelse
            </div>
        </div>
    </div>
</div>

<!-- ===== MODAL SUSPENDRE ===== -->
@if (! in_array($vendor->status, [\App\Enums\VendorStatus::Suspended->value, \App\Enums\VendorStatus::Closed->value], true))
<div class="modal fade" id="suspend-modal" tabindex="-1" role="dialog" aria-labelledby="suspend-modal-label" aria-hidden="true">
    <div class="modal-dialog" role="document">
        <div class="modal-content" style="border-radius: 12px; border: none;">
            <div class="modal-header" style="border-bottom: 1px solid var(--border-color);">
                <h5 class="modal-title" id="suspend-modal-label" style="color: var(--text-dark); font-weight: 700;">Suspendre ce vendeur</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            </div>
            <form method="POST" action="{{ route('admin.vendors.suspend', $vendor) }}">
                @csrf
                <div class="modal-body">
                    <p style="color: var(--text-muted);">Veuillez indiquer la raison de la suspension (obligatoire).</p>
                    <textarea name="reason" class="form-control" rows="4" required minlength="3" maxlength="500" placeholder="Ex : Non conformité des documents, plainte client, etc."></textarea>
                </div>
                <div class="modal-footer" style="border-top: 1px solid var(--border-color);">
                    <button type="button" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);" data-dismiss="modal">Annuler</button>
                    <button type="submit" class="btn" style="background-color: var(--benin-red); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-alert"></i> Confirmer la suspension
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
@endif

<!-- ===== MODAL FERMER ===== -->
@if ($vendor->status !== \App\Enums\VendorStatus::Closed->value)
<div class="modal fade" id="close-modal" tabindex="-1" role="dialog" aria-labelledby="close-modal-label" aria-hidden="true">
    <div class="modal-dialog" role="document">
        <div class="modal-content" style="border-radius: 12px; border: none;">
            <div class="modal-header" style="border-bottom: 1px solid var(--border-color);">
                <h5 class="modal-title" id="close-modal-label" style="color: var(--text-dark); font-weight: 700;">Fermer ce vendeur</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            </div>
            <form method="POST" action="{{ route('admin.vendors.close', $vendor) }}">
                @csrf
                <div class="modal-body">
                    <p style="color: var(--text-muted);">La fermeture est définitive. Veuillez indiquer la raison (obligatoire).</p>
                    <textarea name="reason" class="form-control" rows="4" required minlength="3" maxlength="500" placeholder="Raison de la fermeture définitive..."></textarea>
                </div>
                <div class="modal-footer" style="border-top: 1px solid var(--border-color);">
                    <button type="button" class="btn" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);" data-dismiss="modal">Annuler</button>
                    <button type="submit" class="btn" style="background-color: var(--benin-red); color: #FFFFFF; border-radius: 8px; font-weight: 500;">
                        <i class="ti ti-x"></i> Confirmer la fermeture
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
@endif
@endsection