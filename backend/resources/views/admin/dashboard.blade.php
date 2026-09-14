@extends('layouts.app')

@section('content')
    <div class="row">
        <div class="col-md-3">
            <div class="card p-3">
                <h5>Vendeurs</h5>
                <p class="display-6">{{ $vendors }}</p>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card p-3">
                <h5>Produits</h5>
                <p class="display-6">{{ $products }}</p>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card p-3">
                <h5>Utilisateurs</h5>
                <p class="display-6">{{ $users }}</p>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card p-3">
                <h5>Zones</h5>
                <p class="display-6">{{ $zones }}</p>
            </div>
        </div>
    </div>

    <div class="mt-4">
        <h4>Actions rapides</h4>
        <div class="d-flex gap-2">
            <a href="#" class="btn btn-primary">Voir vendeurs</a>
            <a href="#" class="btn btn-secondary">Gérer produits</a>
        </div>
    </div>
@endsection
