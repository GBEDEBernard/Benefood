@extends('layouts.app')

@section('content')
<x-admin.page-header title="Transactions" subtitle="Gestion des paiements">
    <a href="{{ route('admin.dashboard') }}" class="btn btn-sm">Dashboard</a>
</x-admin.page-header>

<div class="card">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table mb-0">
                <thead>
                    <tr>
                        <th>Txn ID</th>
                        <th>Order</th>
                        <th>Provider</th>
                        <th>Amount</th>
                        <th>Status</th>
                        <th>Créé</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($payments as $p)
                        <tr>
                            <td>{{ $p->provider_transaction_id }}</td>
                            <td>@if($p->order)<a href="{{ route('admin.orders.index') }}?q={{ $p->order->id }}">{{ $p->order->id }}</a>@else — @endif</td>
                            <td>{{ $p->provider }}</td>
                            <td>{{ number_format($p->amount / 100, 2) }} {{ $p->currency }}</td>
                            <td>{{ $p->status }}</td>
                            <td>{{ $p->created_at?->format('d/m/Y H:i') }}</td>
                            <td class="text-right"><a href="{{ route('admin.payments.show', $p) }}" class="btn btn-sm">Voir</a></td>
                        </tr>
                    @empty
                        <tr><td colspan="7" class="text-center text-muted">Aucune transaction.</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @if ($payments->hasPages())
        <div class="card-footer">{{ $payments->links() }}</div>
    @endif
</div>
@endsection
