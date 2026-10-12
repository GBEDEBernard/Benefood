@extends('layouts.app')

@section('content')
<x-admin.page-header title="Lots de retraits (Mode B)" subtitle="Cahier v1.0 — Paiements groupés des retraits en attente">
    <a href="{{ route('admin.payouts.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-arrow-left"></i> Retraits individuels
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
        'processing' => ['En cours', 'background-color: #FFF8E1; color: #9A6A08;'],
        'executed' => ['Versé', 'background-color: #E8F5E9; color: #2E7D32;'],
        'partially_failed' => ['Partiel', 'background-color: #FFF3E0; color: #E65100;'],
        'failed' => ['Échec', 'background-color: #FDECEA; color: #C62828;'],
    ];
@endphp

<div class="row mb-4">
    <div class="col-md-6 mb-3">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body d-flex align-items-center">
                <div class="d-flex align-items-center justify-content-center mr-3" style="width: 52px; height: 52px; border-radius: 14px; background-color: #FFF8E1;">
                    <i class="ti ti-stack-2" style="font-size: 24px; color: #9A6A08;"></i>
                </div>
                <div>
                    <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Lots en cours</div>
                    <div style="font-size: 22px; font-weight: 800; color: var(--text-dark);">{{ $counts['processing'] }}</div>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-6 mb-3">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body d-flex align-items-center">
                <div class="d-flex align-items-center justify-content-center mr-3" style="width: 52px; height: 52px; border-radius: 14px; background-color: #E8F5E9;">
                    <i class="ti ti-circle-check" style="font-size: 24px; color: #2E7D32;"></i>
                </div>
                <div>
                    <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Total versé en lots</div>
                    <div style="font-size: 22px; font-weight: 800; color: var(--text-dark);">{{ AdminLabels::priceLabel($totals['executed']) }}</div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover mb-0">
                <thead style="background-color: #F9FAFB;">
                    <tr>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Référence</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Libellé</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Montant</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Retraits</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                        <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Créé le</th>
                        <th class="border-0 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($batches as $batch)
                        @php
                            $status = $batch->status->value;
                            $badge = $badges[$status] ?? [$status, 'background-color: #ECEFF1; color: #37474F;'];
                        @endphp
                        <tr>
                            <td class="py-3" style="font-weight: 800; color: var(--text-dark);">{{ $batch->reference }}</td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $batch->label ?? '—' }}</td>
                            <td class="py-3" style="font-weight: 700;">{{ AdminLabels::priceLabel((int) $batch->total_amount) }}</td>
                            <td class="py-3" style="color: var(--text-muted);">
                                {{ $batch->payouts_count }} retrait(s)
                                <small class="d-block">
                                    <span style="color: #2E7D32;">{{ $batch->executed_count }} versés</span>
                                    @if ((int) $batch->failed_count > 0)
                                        · <span style="color: #C62828;">{{ $batch->failed_count }} échecs</span>
                                    @endif
                                </small>
                            </td>
                            <td class="py-3">
                                <span class="badge badge-pill" style="{{ $badge[1] }} font-weight: 600; padding: 6px 12px; border-radius: 20px;">{{ $badge[0] }}</span>
                            </td>
                            <td class="py-3" style="color: var(--text-muted);">{{ $batch->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                            <td class="py-3 text-right">
                                <a href="{{ route('admin.payouts.batches.show', $batch) }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--benin-green); font-weight: 600;">
                                    <i class="ti ti-eye"></i> Détail
                                </a>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                <i class="ti ti-stack-2" style="font-size: 40px;"></i>
                                <p class="mt-2 mb-0">Aucun lot pour le moment. Sélectionnez des retraits en attente sur la page « Wallets & retraits » puis « Créer un lot ».</p>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($batches->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $batches->links() }}
        </div>
    @endif
</div>
@endsection