@extends('layouts.app')

@section('content')
<x-admin.page-header title="Wallets & retraits" subtitle="Cahier v1.0 — Demandes de reversement des vendeurs et livreurs">
    <a href="{{ route('admin.payouts.batches.index') }}" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 600; border: none;">
        <i class="ti ti-stack-2"></i> Lots groupés (Mode B)
    </a>
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

@php
    use App\Support\AdminLabels;
    $statusChips = [
        ['key' => '', 'label' => 'Tous', 'count' => $counts['all'], 'fg' => 'var(--benin-green)'],
        ['key' => 'pending', 'label' => 'À valider', 'count' => $counts['pending'], 'fg' => 'var(--benin-orange)'],
        ['key' => 'executed', 'label' => 'Versés', 'count' => $counts['executed'], 'fg' => 'var(--benin-green)'],
        ['key' => 'failed', 'label' => 'Échecs', 'count' => $counts['failed'], 'fg' => 'var(--benin-red)'],
    ];
    $badges = [
        'pending' => ['En attente', 'background-color: #FFF3E0; color: #E65100;'],
        'processing' => ['En cours', 'background-color: #FFF8E1; color: #9A6A08;'],
        'executed' => ['Versé', 'background-color: #E8F5E9; color: #2E7D32;'],
        'failed' => ['Échec', 'background-color: #FDECEA; color: #C62828;'],
    ];
@endphp

<div class="row mb-4">
    <div class="col-md-6 mb-3">
        <div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body d-flex align-items-center">
                <div class="d-flex align-items-center justify-content-center mr-3" style="width: 52px; height: 52px; border-radius: 14px; background-color: #FFF3E0;">
                    <i class="ti ti-hourglass" style="font-size: 24px; color: #E65100;"></i>
                </div>
                <div>
                    <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Retraits à valider</div>
                    <div style="font-size: 22px; font-weight: 800; color: var(--text-dark);">{{ AdminLabels::priceLabel($totals['pending']) }}</div>
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
                    <div style="color: var(--text-muted); font-size: 12px; text-transform: uppercase; letter-spacing: .4px; font-weight: 600;">Total versé</div>
                    <div style="font-size: 22px; font-weight: 800; color: var(--text-dark);">{{ AdminLabels::priceLabel($totals['executed']) }}</div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="row mb-4">
    <div class="col-12">
        <ul class="nav" style="gap: 8px; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;">
            @foreach ($statusChips as $chip)
                <li class="nav-item">
                    <a class="btn btn-sm"
                       href="{{ route('admin.payouts.index', array_merge(['status' => $chip['key'] ?: null])) }}"
                       style="border-radius: 20px; font-weight: 600; font-size: 13px; padding: 6px 16px; {{ ($filters['status'] ?? '') === $chip['key'] ? 'background-color: '.$chip['fg'].'; color: #FFFFFF;' : 'background: #FFFFFF; border: 1px solid var(--border-color); color: var(--text-dark);' }}">
                        {{ $chip['label'] }} <span class="ml-1" style="font-weight: 700;">{{ $chip['count'] }}</span>
                    </a>
                </li>
            @endforeach
        </ul>
    </div>
</div>

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    @if ($counts['pending'] > 0 || $counts['processing'] > 0)
        <div class="card-header d-flex align-items-center justify-content-between" style="background: #FFFFFF; border-radius: 12px 12px 0 0; border-bottom: 1px solid var(--border-color);">
            <span style="color: var(--text-muted); font-size: 13px;">Cochez plusieurs retraits puis créez un lot pour les payer en une fois (Mode B).</span>
            <form method="GET" action="{{ route('admin.payouts.index') }}" class="d-inline">
                <input type="hidden" name="status" value="pending">
                <button type="submit" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark); font-weight: 600;">Voir les retraits à valider</button>
            </form>
        </div>
    @endif
    <form method="POST" action="{{ route('admin.payouts.batches.store') }}">
        @csrf
        <input type="hidden" name="label" value="Régularisation {{ now()->format('d/m/Y') }}">
        <div class="card-body p-0">
            <div class="table-responsive">
                <table class="table table-hover mb-0">
                    <thead style="background-color: #F9FAFB;">
                        <tr>
                            <th class="border-0 py-3" style="width: 44px;"></th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Bénéficiaire</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Montant</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Méthode</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Statut</th>
                            <th class="border-0 py-3" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Demandé le</th>
                            <th class="border-0 py-3"></th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($payouts as $payout)
                            @php
                                $wallet = $payout->wallet;
                                $status = $payout->status->value;
                                $badge = $badges[$status] ?? [$status, 'background-color: #ECEFF1; color: #37474F;'];
                                $selectable = in_array($status, ['pending', 'processing'], true);
                            @endphp
                            <tr>
                                <td class="py-3">
                                    @if ($selectable)
                                        <input type="checkbox" name="payout_ids[]" value="{{ $payout->id }}" style="transform: scale(1.2);">
                                    @endif
                                </td>
                                <td class="py-3">
                                    <div style="font-weight: 700; color: var(--text-dark);">{{ $wallet?->ownerName() ?? '—' }}</div>
                                    <small style="color: var(--text-muted);">{{ $wallet?->ownerRoleLabel() ?? '—' }}</small>
                                </td>
                                <td class="py-3" style="font-weight: 700;">{{ AdminLabels::priceLabel((int) $payout->amount) }}</td>
                                <td class="py-3" style="color: var(--text-muted);">{{ $payout->method === 'bank' ? 'Banque' : 'Mobile Money' }}</td>
                                <td class="py-3">
                                    <span class="badge badge-pill" style="{{ $badge[1] }} font-weight: 600; padding: 6px 12px; border-radius: 20px;">{{ $badge[0] }}</span>
                                    @if ($payout->failed_reason)
                                        <small class="d-block" style="color: var(--text-muted);">{{ $payout->failed_reason }}</small>
                                    @endif
                                </td>
                                <td class="py-3" style="color: var(--text-muted);">{{ $payout->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                                <td class="py-3 text-right">
                                    @if ($status === 'pending' || $status === 'processing')
                                        <form method="POST" action="{{ route('admin.payouts.execute', $payout) }}" class="d-inline">
                                            @csrf
                                            <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 600;">
                                                <i class="ti ti-check"></i> Marquer versé
                                            </button>
                                        </form>
                                        <form method="POST" action="{{ route('admin.payouts.fail', $payout) }}" class="d-inline" onsubmit="return confirm('Marquer ce retrait en échec et re-créditer le wallet ?');">
                                            @csrf
                                            <button type="submit" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--benin-red); font-weight: 600;">
                                                <i class="ti ti-x"></i>
                                            </button>
                                        </form>
                                    @else
                                        <span style="color: var(--text-muted);">—</span>
                                    @endif
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="text-center py-5" style="color: var(--text-muted);">
                                    <i class="ti ti-wallet" style="font-size: 40px;"></i>
                                    <p class="mt-2 mb-0">Aucun retrait trouvé.</p>
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
        @if ($counts['pending'] > 0 || $counts['processing'] > 0)
            <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px; border-top: 1px solid var(--border-color);">
                <button type="submit" class="btn btn-sm" style="background-color: var(--benin-green); color: #FFFFFF; border-radius: 8px; font-weight: 600; border: none;" onclick="return confirm('Créer un lot avec les retraits cochés ?');">
                    <i class="ti ti-stack-2"></i> Créer un lot des retraits cochés
                </button>
                <span class="ml-2" style="color: var(--text-muted); font-size: 13px;">Les retraits cochés passeront au statut « En cours ».</span>
            </div>
        @endif
    </form>
    @if ($payouts->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $payouts->links() }}
        </div>
    @endif
</div>
@endsection
