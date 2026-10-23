@extends('layouts.app')

@section('content')
<x-admin.page-header title="Wallet plateforme" subtitle="Commissions, frais de service et frais de livraison Béninfood">
    <a href="{{ route('admin.payouts.index') }}" class="btn btn-sm" style="background: #FFFFFF; border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-dark);">
        <i class="ti ti-wallet"></i> Wallets & retraits
    </a>
</x-admin.page-header>

<div class="row">
    <div class="col-md-4">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div style="font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: var(--text-muted); font-weight: 700;">Solde disponible</div>
                <div style="font-size: 28px; font-weight: 800; color: var(--benin-green); margin-top: 6px;">
                    {{ number_format((int) $wallet->available_balance, 0, ',', ' ') }} FCFA
                </div>
                <div style="font-size: 13px; color: var(--text-muted); margin-top: 8px;">
                    Solde total : {{ number_format((int) $wallet->balance, 0, ',', ' ') }} FCFA
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div style="font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: var(--text-muted); font-weight: 700;">Encaissé ce mois</div>
                <div style="font-size: 28px; font-weight: 800; color: var(--text-dark); margin-top: 6px;">
                    {{ number_format($monthCredited, 0, ',', ' ') }} FCFA
                </div>
                <div style="font-size: 13px; color: var(--text-muted); margin-top: 8px;">Crédits du mois en cours</div>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card mb-4" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
            <div class="card-body">
                <div style="font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: var(--text-muted); font-weight: 700;">Total encaissé</div>
                <div style="font-size: 28px; font-weight: 800; color: var(--text-dark); margin-top: 6px;">
                    {{ number_format($totalCredited, 0, ',', ' ') }} FCFA
                </div>
                <div style="font-size: 13px; color: var(--text-muted); margin-top: 8px;">Depuis l'ouverture du wallet</div>
            </div>
        </div>
    </div>
</div>

<div class="card" style="border: none; box-shadow: 0 2px 10px rgba(0,0,0,0.05); border-radius: 12px;">
    <div class="card-header" style="background-color: #FFFFFF; border-bottom: 1px solid var(--border-color); border-radius: 12px 12px 0 0;">
        <h6 class="font-weight-bold mb-0" style="color: var(--text-dark);">Historique des mouvements</h6>
    </div>
    <div class="table-responsive">
        <table class="table mb-0" style="font-size: 14px;">
            <thead style="background-color: #F9FAFB;">
                <tr>
                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Date</th>
                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Type</th>
                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Montant</th>
                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Référence</th>
                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Description</th>
                    <th class="border-0" style="color: var(--text-muted); font-weight: 600; font-size: 12px; text-transform: uppercase;">Solde après</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($transactions as $transaction)
                    @php($type = $transaction->type?->value ?? $transaction->type)
                    <tr>
                        <td class="py-3" style="color: var(--text-muted);">{{ $transaction->created_at?->format('d/m/Y H:i') ?? '—' }}</td>
                        <td class="py-3">
                            <span class="badge badge-pill" style="background-color: {{ $type === 'credit' ? '#E8F5E9' : '#FFEBEE' }}; color: {{ $type === 'credit' ? '#2E7D32' : '#C62828' }}; font-weight: 600; padding: 6px 12px; border-radius: 20px;">
                                {{ $type === 'credit' ? 'Crédit' : 'Débit' }}
                            </span>
                        </td>
                        <td class="py-3" style="font-weight: 700; color: {{ $type === 'credit' ? 'var(--benin-green)' : 'var(--benin-red)' }};">
                            {{ $type === 'credit' ? '+' : '−' }}{{ number_format((int) $transaction->amount, 0, ',', ' ') }} FCFA
                        </td>
                        <td class="py-3" style="color: var(--text-muted);">
                            {{ $transaction->reference_type ?? '—' }}
                            @if ($transaction->reference_id)
                                <br><small>{{ \Illuminate\Support\Str::limit((string) $transaction->reference_id, 12) }}</small>
                            @endif
                        </td>
                        <td class="py-3" style="color: var(--text-dark);">{{ $transaction->description }}</td>
                        <td class="py-3" style="color: var(--text-muted);">{{ number_format((int) $transaction->balance_after, 0, ',', ' ') }} FCFA</td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="6" class="text-center py-4" style="color: var(--text-muted);">Aucun mouvement pour le moment.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>
    @if ($transactions->hasPages())
        <div class="card-footer" style="background: #FFFFFF; border-radius: 0 0 12px 12px;">
            {{ $transactions->links() }}
        </div>
    @endif
</div>
@endsection
