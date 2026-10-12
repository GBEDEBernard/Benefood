@extends('layouts.app')

@section('content')
<x-admin.page-header title="{{ $batch->reference }}" subtitle="Lot de retraits — Mode B (cahier v1.0)">
    <a href="{{ route('admin.payouts.batches.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-arrow-left"></i> Tous les lots
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

@php
    use App\Support\AdminLabels;
    $badges = [
        'pending' => ['En attente', 'background-color: #FFF3E0; color: #E65100;'],
        'processing' => ['En cours', 'background-color: #FFF8E1; color: #9A6A08;'],
        'executed' => ['Versé', 'background-color: #E8F5E9; color: #2E7D32;'],
        'failed' => ['Échec', 'background-color: #FDECEA; color: #C62828;'],
    ];
    $batchBadge = [
        'processing' => ['En cours', 'background-color: #FFF8E1; color: #9A6A08;'],
        'executed' => ['Versé', 'background-color: #E8F5E9; color: #2E7D32;'],
        'partially_failed' => ['Partiel', 'background-color: #FFF3E0; color: #E65100;'],
        'failed' => ['Échec', 'background-color: #FDECEA; color: #C62828;'],
    ][$batch->status->value] ?? ['—', ''];
@endphp

<div class="row mb-4">
    <div class="col-md-3 mb-3">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Montant total</div>
                <div style="font-size: 22px; font-weight: 800; color: var(--text-dark);">{{ AdminLabels::priceLabel((int) $batch->total_amount) }}</div>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-3">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Retraits</div>
                <div style="font-size: 22px; font-weight: 800; color: var(--text-dark);">{{ $batch->payouts_count }}</div>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-3">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Statut</div>
                <div class="mt-1">
                    <span class="badge badge-pill" style="{{ $batchBadge[1] }} font-weight: 600; padding: 6px 12px; border-radius: 20px;">{{ $batchBadge[0] }}</span>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-3 mb-3">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Créé par</div>
                <div style="font-weight: 700; color: var(--text-dark);">{{ $batch->creator?->name ?? '—' }}</div>
            </div>
        </div>
    </div>
</div>

@if (! in_array($batch->status->value, ['executed', 'failed'], true))
    <div class="alert alert-warning" style="border-radius: 12px; background-color: #FFF8E1; border: 1px solid #F2E2A6; color: #9A6A08;">
        <form method="POST" action="{{ route('admin.payouts.batches.execute', $batch) }}" class="d-inline">
            @csrf
            <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 600;">
                <i class="ti ti-check"></i> Exécuter tout le lot
            </button>
        </form>
        <span class="ml-2">Marque tous les retraits en attente du lot comme versés en une seule opération.</span>
    </div>
@endif

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Bénéficiaire</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Montant</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Raison d'échec</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($payouts as $payout)
                        @php
                            $wallet = $payout->wallet;
                            $status = $payout->status->value;
                            $badge = $badges[$status] ?? [$status, 'background-color: #ECEFF1; color: #37474F;'];
                        @endphp
                        <tr>
                            <td class="py-3">
                                <div style="font-weight: 700; color: var(--text-dark);">{{ $wallet?->ownerName() ?? '—' }}</div>
                                <small style="color: var(--text-muted);">{{ $wallet?->ownerRoleLabel() ?? '—' }}</small>
                            </td>
                            <td class="py-3" style="font-weight: 700;">{{ AdminLabels::priceLabel((int) $payout->amount) }}</td>
                            <td class="py-3">
                                <span class="badge badge-pill" style="{{ $badge[1] }} font-weight: 600; padding: 6px 12px; border-radius: 20px;">{{ $badge[0] }}</span>
                            </td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $payout->failed_reason ?? '—' }}</td>
                            <td class="py-3 text-right">
                                @if (in_array($status, ['pending', 'processing'], true))
                                    <form method="POST" action="{{ route('admin.payouts.batches.payouts.fail', [$batch, $payout]) }}" class="d-inline"
                                          onsubmit="var r = prompt('Raison de l\'échec (optionnel) :') || ''; document.getElementById('reason-{{ $payout->id }}').value = r; return confirm('Marquer ce retrait en échec et re-créditer le wallet ?');">
                                        @csrf
                                        <input type="hidden" name="reason" id="reason-{{ $payout->id }}" value="">
                                        <button type="submit" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--benin-red); font-weight: 600;">
                                            <i class="ti ti-x"></i> Échec
                                        </button>
                                    </form>
                                @else
                                    <span style="color: var(--text-muted);">—</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-stack-2" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun retrait dans ce lot.</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($payouts->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $payouts->links() }}
        </div>
    @endif
</div>
@endsection