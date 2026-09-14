@extends('layouts.app')

@section('content')
<div class="app-main" id="main">
    <div class="container-fluid">
        <!-- begin row -->
        <div class="row">
            <div class="col-md-12 m-b-30">
                <!-- begin page title -->
                <div class="d-block d-sm-flex flex-nowrap align-items-center">
                    <div class="page-title mb-2 mb-sm-0">
                        <h1>Clients</h1>
                    </div>
                    <div class="ml-auto d-flex align-items-center">
                        <nav>
                            <ol class="breadcrumb p-0 m-b-0">
                                <li class="breadcrumb-item">
                                    <a href="{{ route('admin.dashboard') }}"><i class="ti ti-home"></i></a>
                                </li>
                                <li class="breadcrumb-item">Pages</li>
                                <li class="breadcrumb-item active text-primary" aria-current="page">Clients</li>
                            </ol>
                        </nav>
                    </div>
                </div>
                <!-- end page title -->
            </div>
        </div>
        <!-- end row -->

        <!-- start-clients content-->
        <div class="row">
            <div class="col-12">
                <div class="card card-statistics clients-contant">
                    <div class="card-header">
                        <!-- Utilisation de flex-column sur mobile pour empiler les boutons -->
                        <div class="d-flex flex-column flex-sm-row justify-content-between align-items-sm-center">
                            <div class="card-heading mb-3 mb-sm-0">
                                <h4 class="card-title">Liste des Clients</h4>
                            </div>
                            <div class="btn-group btn-group-toggle" data-toggle="buttons">
                                <label class="btn btn-sm btn-round btn-primary">
                                    <input type="radio" name="options" id="option1" checked> Aujourd'hui
                                </label>
                                <label class="btn btn-sm btn-round btn-outline-primary">
                                    <input type="radio" name="options" id="option2"> Semaine
                                </label>
                                <label class="btn btn-sm btn-round btn-outline-primary">
                                    <input type="radio" name="options" id="option3"> Mois
                                </label>
                            </div>
                        </div>
                    </div>
                    <div class="card-body py-0">
                        <!-- Table-responsive permet le défilement horizontal sur mobile -->
                        <div class="table-responsive">
                            <table class="table clients-contant-table mb-0">
                                <thead>
                                    <tr>
                                        <th scope="col">Clients</th>
                                        <th scope="col">Date de transaction</th>
                                        <th scope="col">Montant</th>
                                        <th scope="col">Statut</th>
                                        <th scope="col">Modifier et supprimer</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td>
                                            <div class="d-flex align-items-center">
                                                <div class="bg-img mr-4">
                                                    <img src="{{ asset('assets/img/avtar/01.jpg') }}" class="img-fluid rounded-circle" alt="Clients-01" style="width: 40px; height: 40px;">
                                                </div>
                                                <p class="font-weight-bold mb-0">Adrian Demiandro</p>
                                            </div>
                                        </td>
                                        <td>20/07/2018</td>
                                        <td>230,00 $</td>
                                        <td>
                                            <a href="javascript:void(0)" class="dot bg-success"></a>
                                            <span>Payé</span>
                                        </td>
                                        <td>
                                            <div class="d-flex">
                                                <a href="javascript:void(0)" class="btn btn-icon btn-outline-primary btn-round mr-2"><i class="ti ti-pencil"></i></a>
                                                <a href="javascript:void(0)" class="btn btn-icon btn-outline-danger btn-round"><i class="ti ti-close"></i></a>
                                            </div>
                                        </td>
                                    </tr>
                                    <!-- Ajoutez d'autres lignes ici -->
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <!-- end-clients content-->
    </div>
</div>
@endsection