@extends('layouts.app')

@push('styles')
    <link rel="stylesheet" href="{{ asset('assets/css/admin-orders.css') }}">
@endpush

@section('content')
    @php
        $statusInfo = \App\Support\AdminLabels::orderStatus($order->status->value);
        $statusTone = match ($order->status->value) {
            'delivered' => 'success',
            'paid', 'accepted', 'preparing', 'ready', 'assigned', 'picked_up', 'in_delivery' => 'info',
            'awaiting_payment' => 'warning',
            'cancelled', 'disputed' => 'danger',
            'refunded' => 'violet',
            default => 'neutral',
        };
        $payment = $order->payment;
        $paymentInfo = $payment
            ? \App\Support\AdminLabels::paymentStatus($payment->status->value)
            : ['label' => 'Non initié'];
        $paymentTone = match ($payment?->status->value) {
            'confirmed' => 'success',
            'initiated', 'pending' => 'warning',
            'refunded' => 'violet',
            'failed' => 'danger',
            default => 'neutral',
        };
        $delivery = $order->delivery;
        $deliveryStatus = $delivery?->status->value;
        $deliveryLabels = [
            'assigned' => 'Assignée',
            'en_route_pickup' => 'En route vers la boutique',
            'picked_up' => 'Récupérée',
            'in_delivery' => 'En livraison',
            'delivered' => 'Livrée',
            'cancelled' => 'Annulée',
        ];
        $deliveryTone = match ($deliveryStatus) {
            'delivered' => 'success',
            'picked_up', 'in_delivery', 'en_route_pickup' => 'info',
            'assigned' => 'warning',
            'cancelled' => 'danger',
            default => 'neutral',
        };
        $driver = $delivery?->driverProfile?->user;
        $address = is_array($order->address_snapshot) ? $order->address_snapshot : [];
        $hasAddress = $address !== [];
        $addressLabel = $address['label'] ?? 'Adresse de livraison';
        $addressLine = $address['full_address'] ?? null;
        $addressCity = $address['city'] ?? null;
        $addressLandmark = $address['landmark'] ?? null;
        $addressPhone = $address['contact_phone'] ?? $order->user?->phone;
        $addressNotes = $address['notes'] ?? null;
        $totalQuantity = (int) $order->items->sum('quantity');
        $history = $order->statusHistory->sortByDesc('created_at');
        $refunds = $order->refunds->sortByDesc('created_at');
        $complaints = $order->complaints->sortByDesc('created_at');
        $financials = $order->financials;
        $canCancelNow = $canCancel && ! in_array($order->status->value, ['cancelled', 'refunded'], true);
        $customerName = $order->user?->name ?? 'Client supprimé';
    @endphp

    <div class="orders-page order-show-page">
        <section class="orders-hero orders-hero--show">
            <span class="orders-hero__halo" aria-hidden="true"></span>
            <div class="orders-hero__content">
                <a href="{{ route('admin.orders.index') }}" class="orders-back-link">
                    <i class="ti ti-chevron-left" aria-hidden="true"></i>
                    Toutes les commandes
                </a>
                <div class="orders-show-title">
                    <span class="orders-show-title__icon">
                        <i class="ti ti-receipt-2" aria-hidden="true"></i>
                    </span>
                    <div>
                        <span class="orders-eyebrow">
                            <span class="orders-eyebrow__dot" aria-hidden="true"></span>
                            Détail de la commande
                        </span>
                        <div class="orders-show-title__row">
                            <h1>{{ $order->reference }}</h1>
                            <x-admin.status-badge :label="$statusInfo['label']" :tone="$statusTone" />
                        </div>
                        <p>
                            Créée le {{ $order->created_at?->format('d/m/Y à H:i') ?? '—' }}
                            · {{ $totalQuantity }} article{{ $totalQuantity > 1 ? 's' : '' }}
                            · {{ $order->vendor?->business_name ?? 'Boutique supprimée' }}
                        </p>
                    </div>
                </div>
            </div>
            <div class="orders-hero__actions">
                <button type="button" class="orders-action orders-action--glass" data-copy-order="{{ $order->reference }}">
                    <i class="ti ti-copy" aria-hidden="true"></i>
                    <span>Copier la référence</span>
                </button>
                @if ($canCancelNow)
                    <a href="#annulation" class="orders-action orders-action--danger">
                        <i class="ti ti-ban" aria-hidden="true"></i>
                        <span>Annuler</span>
                    </a>
                @endif
            </div>
        </section>

        @if (session('success'))
            <div class="orders-flash orders-flash--success" role="status" data-orders-flash>
                <span class="orders-flash__icon"><i class="ti ti-circle-check" aria-hidden="true"></i></span>
                <p>{{ session('success') }}</p>
                <button type="button" class="orders-flash__close" data-dismiss-flash aria-label="Fermer le message">
                    <i class="ti ti-x" aria-hidden="true"></i>
                </button>
            </div>
        @endif

        @if (session('error'))
            <div class="orders-flash orders-flash--error" role="alert" data-orders-flash>
                <span class="orders-flash__icon"><i class="ti ti-alert-circle" aria-hidden="true"></i></span>
                <p>{{ session('error') }}</p>
                <button type="button" class="orders-flash__close" data-dismiss-flash aria-label="Fermer le message">
                    <i class="ti ti-x" aria-hidden="true"></i>
                </button>
            </div>
        @endif

        <section class="orders-show-summary" aria-label="Résumé de la commande">
            <article class="orders-summary-card" data-tone="green">
                <span class="orders-summary-card__icon">
                    <i class="ti ti-cash" aria-hidden="true"></i>
                </span>
                <div class="orders-summary-card__copy">
                    <span>Total commande</span>
                    <strong>{{ \App\Support\AdminLabels::priceLabel($order->total) }}</strong>
                    <small>{{ $order->currency }}</small>
                </div>
            </article>

            <article class="orders-summary-card" data-tone="{{ $paymentTone === 'success' ? 'emerald' : 'orange' }}">
                <span class="orders-summary-card__icon">
                    <i class="ti ti-wallet" aria-hidden="true"></i>
                </span>
                <div class="orders-summary-card__copy">
                    <span>Paiement</span>
                    <x-admin.status-badge :label="$paymentInfo['label']" :tone="$paymentTone" />
                    <small>{{ $payment?->reference ?? 'Aucune référence' }}</small>
                </div>
            </article>

            <article class="orders-summary-card" data-tone="blue">
                <span class="orders-summary-card__icon">
                    <i class="ti ti-packages" aria-hidden="true"></i>
                </span>
                <div class="orders-summary-card__copy">
                    <span>Articles</span>
                    <strong>{{ $totalQuantity }}</strong>
                    <small>{{ $order->items->count() }} ligne{{ $order->items->count() > 1 ? 's' : '' }}</small>
                </div>
            </article>

            <article class="orders-summary-card" data-tone="{{ $deliveryStatus === 'delivered' ? 'emerald' : 'violet' }}">
                <span class="orders-summary-card__icon">
                    <i class="ti ti-truck-delivery" aria-hidden="true"></i>
                </span>
                <div class="orders-summary-card__copy">
                    <span>Livraison</span>
                    <x-admin.status-badge :label="$deliveryLabels[$deliveryStatus] ?? 'Non assignée'" :tone="$deliveryTone" />
                    <small>{{ $order->zone?->name ?? $addressCity ?? 'Zone non renseignée' }}</small>
                </div>
            </article>
        </section>

        @if ($order->cancelled_at)
            <div class="orders-cancel-banner">
                <span class="orders-cancel-banner__icon"><i class="ti ti-ban" aria-hidden="true"></i></span>
                <div>
                    <strong>Commande annulée le {{ $order->cancelled_at->format('d/m/Y à H:i') }}</strong>
                    @if ($order->cancellation_reason)
                        <p>{{ $order->cancellation_reason }}</p>
                    @endif
                </div>
            </div>
        @endif

        <div class="order-show-grid">
            <div class="order-show-main">
                <section class="orders-panel order-detail-panel" aria-labelledby="order-items-title">
                    <div class="orders-panel__head">
                        <div>
                            <h2 id="order-items-title">Articles commandés</h2>
                            <p>{{ $order->items->count() }} ligne{{ $order->items->count() > 1 ? 's' : '' }} · {{ $totalQuantity }} article{{ $totalQuantity > 1 ? 's' : '' }}</p>
                        </div>
                        <span class="orders-panel__icon">
                            <i class="ti ti-shopping-bag" aria-hidden="true"></i>
                        </span>
                    </div>

                    <div class="order-items">
                        @forelse ($order->items as $item)
                            <div class="order-item">
                                @if ($item->product)
                                    <x-admin.product-thumb :product="$item->product" size="md" />
                                @else
                                    <span class="order-item__icon">
                                        <i class="ti ti-package" aria-hidden="true"></i>
                                    </span>
                                @endif
                                <div class="order-item__main">
                                    <strong>{{ $item->name_snapshot }}</strong>
                                    <span>
                                        {{ $item->quantity }} × {{ \App\Support\AdminLabels::priceLabel($item->unit_price_snapshot) }}
                                        @if ($item->variant_label)
                                            · {{ $item->variant_label }}
                                        @endif
                                    </span>
                                </div>
                                <strong class="order-item__total">{{ \App\Support\AdminLabels::priceLabel($item->subtotal) }}</strong>
                            </div>
                        @empty
                            <div class="orders-empty orders-empty--compact">
                                <span class="orders-empty__icon"><i class="ti ti-package-off" aria-hidden="true"></i></span>
                                <h3>Aucun article</h3>
                                <p>Cette commande ne contient aucun article.</p>
                            </div>
                        @endforelse
                    </div>

                    <div class="order-totals">
                        <div class="order-total-row">
                            <span>Sous-total</span>
                            <span>{{ \App\Support\AdminLabels::priceLabel($order->subtotal) }}</span>
                        </div>
                        <div class="order-total-row">
                            <span>Livraison</span>
                            <span>{{ \App\Support\AdminLabels::priceLabel($order->delivery_fee) }}</span>
                        </div>
                        @if ($order->discount > 0)
                            <div class="order-total-row order-total-row--discount">
                                <span>Remise</span>
                                <span>-{{ \App\Support\AdminLabels::priceLabel($order->discount) }}</span>
                            </div>
                        @endif
                        <div class="order-total-row order-total-row--main">
                            <span>Total client</span>
                            <strong>{{ \App\Support\AdminLabels::priceLabel($order->total) }}</strong>
                        </div>
                    </div>
                </section>

                <section class="orders-panel order-timeline-panel" aria-labelledby="order-timeline-title">
                    <div class="orders-panel__head">
                        <div>
                            <h2 id="order-timeline-title">Parcours de la commande</h2>
                            <p>{{ $history->count() }} transition{{ $history->count() > 1 ? 's' : '' }} enregistrée{{ $history->count() > 1 ? 's' : '' }}</p>
                        </div>
                        <span class="orders-panel__icon">
                            <i class="ti ti-route" aria-hidden="true"></i>
                        </span>
                    </div>

                    @if ($history->isEmpty())
                        <div class="orders-empty orders-empty--compact">
                            <span class="orders-empty__icon"><i class="ti ti-history-off" aria-hidden="true"></i></span>
                            <h3>Aucune transition</h3>
                            <p>Le parcours de cette commande n’a pas encore été enregistré.</p>
                        </div>
                    @else
                        <ol class="order-timeline">
                            @foreach ($history as $entry)
                                <li class="order-timeline__item">
                                    <span class="order-timeline__marker" aria-hidden="true"></span>
                                    <div class="order-timeline__content">
                                        <div class="order-timeline__heading">
                                            <strong>{{ \App\Support\AdminLabels::orderStatus($entry->to_status)['label'] }}</strong>
                                            @if ($entry->from_status)
                                                <span>depuis {{ \App\Support\AdminLabels::orderStatus($entry->from_status)['label'] }}</span>
                                            @endif
                                        </div>
                                        <div class="order-timeline__meta">
                                            <time>{{ $entry->created_at?->format('d/m/Y à H:i') ?? '—' }}</time>
                                            @if ($entry->actor_type)
                                                <span>{{ ucfirst($entry->actor_type) }}</span>
                                            @endif
                                        </div>
                                        @if ($entry->reason)
                                            <p>{{ $entry->reason }}</p>
                                        @endif
                                    </div>
                                </li>
                            @endforeach
                        </ol>
                    @endif
                </section>

                @if ($delivery !== null || $hasAddress)
                    <section class="orders-panel order-delivery-panel" aria-labelledby="order-delivery-title">
                        <div class="orders-panel__head">
                            <div>
                                <h2 id="order-delivery-title">Livraison &amp; adresse</h2>
                                <p>Course, destinataire et informations logistiques.</p>
                            </div>
                            <span class="orders-panel__icon">
                                <i class="ti ti-map-pin" aria-hidden="true"></i>
                            </span>
                        </div>

                        <div class="order-delivery-grid">
                            <div class="order-delivery-card">
                                <div class="order-side-card__title">
                                    <span class="order-side-card__icon"><i class="ti ti-truck" aria-hidden="true"></i></span>
                                    <div>
                                        <h3>Course</h3>
                                        <x-admin.status-badge :label="$deliveryLabels[$deliveryStatus] ?? 'Non assignée'" :tone="$deliveryTone" />
                                    </div>
                                </div>

                                @if ($delivery !== null)
                                    <dl class="order-meta-list">
                                        <div>
                                            <dt>Livreur</dt>
                                            <dd class="order-driver-cell">
                                                @if ($driver)
                                                    <x-admin.avatar :user="$driver" size="sm" />
                                                @endif
                                                <span>{{ $driver?->name ?? 'En attente d’assignation' }}</span>
                                            </dd>
                                        </div>
                                        @if ($driver?->phone)
                                            <div>
                                                <dt>Téléphone</dt>
                                                <dd><a href="tel:{{ $driver->phone }}">{{ $driver->phone }}</a></dd>
                                            </div>
                                        @endif
                                        <div>
                                            <dt>Frais de livraison</dt>
                                            <dd>{{ \App\Support\AdminLabels::priceLabel($delivery->fee) }}</dd>
                                        </div>
                                        <div>
                                            <dt>Part livreur</dt>
                                            <dd>{{ \App\Support\AdminLabels::priceLabel($delivery->partner_amount) }}</dd>
                                        </div>
                                        @if ($delivery->assigned_at)
                                            <div>
                                                <dt>Assignée le</dt>
                                                <dd>{{ $delivery->assigned_at->format('d/m/Y à H:i') }}</dd>
                                            </div>
                                        @endif
                                        @if ($delivery->picked_up_at)
                                            <div>
                                                <dt>Récupérée le</dt>
                                                <dd>{{ $delivery->picked_up_at->format('d/m/Y à H:i') }}</dd>
                                            </div>
                                        @endif
                                        @if ($delivery->delivered_at)
                                            <div>
                                                <dt>Livrée le</dt>
                                                <dd>{{ $delivery->delivered_at->format('d/m/Y à H:i') }}</dd>
                                            </div>
                                        @endif
                                    </dl>
                                @else
                                    <p class="order-muted">Aucune course n’est encore assignée à cette commande.</p>
                                @endif
                            </div>

                            <div class="order-address-card">
                                <div class="order-side-card__title">
                                    <span class="order-side-card__icon"><i class="ti ti-map-pin" aria-hidden="true"></i></span>
                                    <div>
                                        <h3>{{ $addressLabel }}</h3>
                                        <span class="order-muted">Adresse de livraison</span>
                                    </div>
                                </div>

                                @if ($hasAddress)
                                    <address class="order-address">
                                        @if ($addressLine)
                                            <strong>{{ $addressLine }}</strong>
                                        @endif
                                        @if ($addressCity)
                                            <span>{{ $addressCity }}</span>
                                        @endif
                                        @if ($addressLandmark)
                                            <span>{{ $addressLandmark }}</span>
                                        @endif
                                        @if ($addressPhone)
                                            <a href="tel:{{ $addressPhone }}">{{ $addressPhone }}</a>
                                        @endif
                                    </address>
                                    @if ($addressNotes)
                                        <p class="order-address-note">
                                            <i class="ti ti-message-2" aria-hidden="true"></i>
                                            {{ $addressNotes }}
                                        </p>
                                    @endif
                                @else
                                    <p class="order-muted">Aucune adresse n’a été enregistrée.</p>
                                @endif
                            </div>
                        </div>
                    </section>
                @endif

                @if ($refunds->isNotEmpty())
                    <section class="orders-panel" aria-labelledby="order-refunds-title">
                        <div class="orders-panel__head">
                            <div>
                                <h2 id="order-refunds-title">Remboursements</h2>
                                <p>{{ $refunds->count() }} opération{{ $refunds->count() > 1 ? 's' : '' }} de remboursement.</p>
                            </div>
                            <span class="orders-panel__icon">
                                <i class="ti ti-refresh" aria-hidden="true"></i>
                            </span>
                        </div>

                        <div class="order-refund-list">
                            @foreach ($refunds as $refund)
                                @php
                                    $refundInfo = \App\Support\AdminLabels::refundStatus($refund->status->value);
                                    $refundTone = match ($refund->status->value) {
                                        'executed' => 'success',
                                        'pending' => 'warning',
                                        'failed' => 'danger',
                                        default => 'neutral',
                                    };
                                @endphp
                                <div class="order-refund">
                                    <span class="order-refund__icon"><i class="ti ti-arrow-back-up" aria-hidden="true"></i></span>
                                    <div class="order-refund__main">
                                        <strong>{{ \App\Support\AdminLabels::priceLabel($refund->amount) }}</strong>
                                        <span>{{ $refund->reason ?? 'Sans motif renseigné' }}</span>
                                    </div>
                                    <x-admin.status-badge :label="$refundInfo['label']" :tone="$refundTone" />
                                    <time>{{ $refund->executed_at?->format('d/m/Y') ?? $refund->created_at?->format('d/m/Y') ?? '—' }}</time>
                                </div>
                            @endforeach
                        </div>
                    </section>
                @endif

                @if ($complaints->isNotEmpty())
                    <section class="orders-panel" aria-labelledby="order-complaints-title">
                        <div class="orders-panel__head">
                            <div>
                                <h2 id="order-complaints-title">Réclamations liées</h2>
                                <p>{{ $complaints->count() }} dossier{{ $complaints->count() > 1 ? 's' : '' }} de support.</p>
                            </div>
                            <span class="orders-panel__icon">
                                <i class="ti ti-message-report" aria-hidden="true"></i>
                            </span>
                        </div>

                        <div class="order-complaint-list">
                            @foreach ($complaints as $complaint)
                                @php
                                    $complaintInfo = \App\Support\AdminLabels::complaintStatus($complaint->status->value);
                                    $complaintTone = match ($complaint->status->value) {
                                        'open' => 'danger',
                                        'in_progress' => 'warning',
                                        'closed' => 'success',
                                        default => 'neutral',
                                    };
                                @endphp
                                <a href="{{ route('admin.complaints.show', $complaint) }}" class="order-complaint">
                                    <span class="order-complaint__icon"><i class="ti ti-message-report" aria-hidden="true"></i></span>
                                    <span class="order-complaint__main">
                                        <strong>{{ $complaint->subject }}</strong>
                                        <small>{{ ucfirst($complaint->type) }} · {{ $complaint->created_at?->format('d/m/Y') ?? '—' }}</small>
                                    </span>
                                    <x-admin.status-badge :label="$complaintInfo['label']" :tone="$complaintTone" />
                                    <i class="ti ti-arrow-up-right" aria-hidden="true"></i>
                                </a>
                            @endforeach
                        </div>
                    </section>
                @endif
            </div>

            <aside class="order-show-side">
                <section class="orders-panel order-side-card" aria-labelledby="order-client-title">
                    <div class="order-side-card__title">
                        <span class="order-side-card__icon"><i class="ti ti-user" aria-hidden="true"></i></span>
                        <div>
                            <h2 id="order-client-title">Client</h2>
                            <span class="order-muted">Contact et identité</span>
                        </div>
                    </div>

                    <div class="order-party">
                        <x-admin.avatar :user="$order->user" :name="$customerName" size="md" />
                        <div>
                            <strong>{{ $customerName }}</strong>
                            <span>{{ $order->user?->phone ?? 'Téléphone non renseigné' }}</span>
                        </div>
                    </div>

                    <dl class="order-meta-list">
                        <div>
                            <dt>E-mail</dt>
                            <dd>{{ $order->user?->email ?? '—' }}</dd>
                        </div>
                        <div>
                            <dt>Compte créé le</dt>
                            <dd>{{ $order->user?->created_at?->format('d/m/Y') ?? '—' }}</dd>
                        </div>
                        <div>
                            <dt>Identifiant</dt>
                            <dd class="order-mono">{{ $order->user?->id ? \Illuminate\Support\Str::limit($order->user->id, 13, '…') : '—' }}</dd>
                        </div>
                    </dl>
                </section>

                <section class="orders-panel order-side-card" aria-labelledby="order-vendor-title">
                    <div class="order-side-card__title">
                        <span class="order-side-card__icon"><i class="ti ti-building-store" aria-hidden="true"></i></span>
                        <div>
                            <h2 id="order-vendor-title">Boutique</h2>
                            <span class="order-muted">Commerçant partenaire</span>
                        </div>
                    </div>

                    <div class="order-party">
                        <x-admin.vendor-logo :vendor="$order->vendor" size="md" />
                        <div>
                            <strong>{{ $order->vendor?->business_name ?? 'Boutique supprimée' }}</strong>
                            <span>{{ $order->vendor?->city ?? 'Ville non renseignée' }}</span>
                        </div>
                    </div>

                    <dl class="order-meta-list">
                        <div>
                            <dt>Téléphone</dt>
                            <dd>
                                @if ($order->vendor?->phone)
                                    <a href="tel:{{ $order->vendor->phone }}">{{ $order->vendor->phone }}</a>
                                @else
                                    —
                                @endif
                            </dd>
                        </div>
                        <div>
                            <dt>E-mail</dt>
                            <dd>{{ $order->vendor?->email ?? '—' }}</dd>
                        </div>
                        <div>
                            <dt>Zone</dt>
                            <dd>{{ $order->zone?->name ?? '—' }}</dd>
                        </div>
                    </dl>

                    @if ($order->vendor)
                        <a href="{{ route('admin.vendors.show', $order->vendor) }}" class="orders-side-link">
                            Voir la boutique
                            <i class="ti ti-arrow-up-right" aria-hidden="true"></i>
                        </a>
                    @endif
                </section>

                <section class="orders-panel order-side-card" aria-labelledby="order-payment-title">
                    <div class="order-side-card__title">
                        <span class="order-side-card__icon"><i class="ti ti-wallet" aria-hidden="true"></i></span>
                        <div>
                            <h2 id="order-payment-title">Paiement</h2>
                            <span class="order-muted">Transaction et statut</span>
                        </div>
                    </div>

                    <div class="order-payment-status">
                        <span>Statut</span>
                        <x-admin.status-badge :label="$paymentInfo['label']" :tone="$paymentTone" />
                    </div>

                    @if ($payment !== null)
                        <dl class="order-meta-list">
                            <div>
                                <dt>Montant</dt>
                                <dd>{{ \App\Support\AdminLabels::priceLabel($payment->amount) }}</dd>
                            </div>
                            <div>
                                <dt>Passerelle</dt>
                                <dd>{{ $payment->gateway ? ucfirst($payment->gateway) : '—' }}</dd>
                            </div>
                            <div>
                                <dt>Référence</dt>
                                <dd class="order-copy-line">
                                    <span class="order-mono">{{ $payment->reference }}</span>
                                    <button type="button"
                                            class="orders-copy"
                                            data-copy-order="{{ $payment->reference }}"
                                            aria-label="Copier la référence de paiement"
                                            title="Copier la référence">
                                        <i class="ti ti-copy" aria-hidden="true"></i>
                                    </button>
                                </dd>
                            </div>
                            @if ($payment->paid_at)
                                <div>
                                    <dt>Payé le</dt>
                                    <dd>{{ $payment->paid_at->format('d/m/Y à H:i') }}</dd>
                                </div>
                            @endif
                            @if ($payment->gateway_txn_id)
                                <div>
                                    <dt>Transaction</dt>
                                    <dd class="order-mono">{{ \Illuminate\Support\Str::limit($payment->gateway_txn_id, 22, '…') }}</dd>
                                </div>
                            @endif
                        </dl>
                    @else
                        <p class="order-muted">Aucun paiement n’a été initié pour cette commande.</p>
                    @endif
                </section>

                @if ($financials !== null)
                    <section class="orders-panel order-side-card" aria-labelledby="order-financials-title">
                        <div class="order-side-card__title">
                            <span class="order-side-card__icon"><i class="ti ti-chart-pie" aria-hidden="true"></i></span>
                            <div>
                                <h2 id="order-financials-title">Répartition financière</h2>
                                <span class="order-muted">Commission et parts partenaires</span>
                            </div>
                        </div>

                        <dl class="order-meta-list">
                            <div>
                                <dt>Base commission</dt>
                                <dd>{{ \App\Support\AdminLabels::priceLabel($financials->commission_base) }}</dd>
                            </div>
                            <div>
                                <dt>Taux commission</dt>
                                <dd>{{ $financials->commission_rate }}%</dd>
                            </div>
                            <div>
                                <dt>Commission plateforme</dt>
                                <dd>{{ \App\Support\AdminLabels::priceLabel($financials->commission_amount) }}</dd>
                            </div>
                            <div>
                                <dt>Montant boutique</dt>
                                <dd>{{ \App\Support\AdminLabels::priceLabel($financials->vendor_amount) }}</dd>
                            </div>
                            <div>
                                <dt>Part livreur</dt>
                                <dd>{{ \App\Support\AdminLabels::priceLabel($financials->delivery_partner_amount) }}</dd>
                            </div>
                            <div class="order-meta-list__total">
                                <dt>Total client</dt>
                                <dd>{{ \App\Support\AdminLabels::priceLabel($financials->total_client) }}</dd>
                            </div>
                        </dl>
                    </section>
                @endif

                @if ($canCancelNow)
                    <section class="orders-panel order-cancel-card" id="annulation" aria-labelledby="order-cancel-title">
                        <div class="order-side-card__title">
                            <span class="order-side-card__icon order-side-card__icon--danger"><i class="ti ti-ban" aria-hidden="true"></i></span>
                            <div>
                                <h2 id="order-cancel-title">Annuler la commande</h2>
                                <span class="order-muted">Action définitive et journalisée</span>
                            </div>
                        </div>

                        <p class="order-cancel-card__intro">
                            Le stock sera restitué et un remboursement sera planifié si le paiement est confirmé.
                            Un motif est obligatoire.
                        </p>

                        <form method="POST"
                              action="{{ route('admin.orders.cancel', $order) }}"
                              class="order-cancel-form"
                              onsubmit="return confirm('Confirmer l’annulation de cette commande ?');">
                            @csrf
                            <input type="hidden" name="refund_amount" value="{{ $payment?->status->value === 'confirmed' ? $order->total : '' }}">
                            <label for="order-cancel-reason" class="orders-field__label">Motif de l’annulation</label>
                            <textarea id="order-cancel-reason"
                                      name="reason"
                                      rows="3"
                                      class="orders-input orders-textarea"
                                      placeholder="Expliquez la raison de cette annulation"
                                      required
                                      minlength="3"
                                      maxlength="500">{{ old('reason') }}</textarea>
                            <button type="submit" class="orders-button orders-button--danger">
                                <i class="ti ti-ban" aria-hidden="true"></i>
                                <span>Confirmer l’annulation</span>
                            </button>
                        </form>
                    </section>
                @endif
            </aside>
        </div>
    </div>
@endsection

@push('scripts')
    <script src="{{ asset('assets/js/admin-orders.js') }}"></script>
@endpush
