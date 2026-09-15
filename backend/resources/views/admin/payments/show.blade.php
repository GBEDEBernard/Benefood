@extends('layouts.app')

@section('content')
<x-admin.page-header title="Transaction" :subtitle="$payment->provider_transaction_id">
    <a href="{{ route('admin.payments.index') }}" class="btn btn-sm">Retour</a>
</x-admin.page-header>

<div class="card">
    <div class="card-body">
        <dl>
            <dt>Provider</dt>
            <dd>{{ $payment->provider }}</dd>
            <dt>Txn ID</dt>
            <dd>{{ $payment->provider_transaction_id }}</dd>
            <dt>Order</dt>
            <dd>@if($payment->order)<a href="{{ route('admin.users.show', $payment->order->user) }}">{{ $payment->order->id }}</a>@else — @endif</dd>
            <dt>Amount</dt>
            <dd>{{ number_format($payment->amount / 100, 2) }} {{ $payment->currency }}</dd>
            <dt>Status</dt>
            <dd>{{ $payment->status }}</dd>
            <dt>Metadata</dt>
            <dd><pre>{{ json_encode($payment->metadata, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre></dd>
        </dl>
    </div>
</div>
@endsection
