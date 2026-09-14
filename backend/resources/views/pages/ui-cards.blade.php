@extends('layouts.app')
@section('content')
                <!-- begin app-main -->
                <div class="app-main" id="main">
                    <!-- begin container-fluid -->
                    <div class="container-fluid">
                        <!-- begin row -->
                        <div class="row">
                            <div class="col-md-12 m-b-30">
                                <!-- begin page title -->
                                <div class="d-block d-sm-flex flex-nowrap align-items-center">
                                    <div class="page-title mb-2 mb-sm-0">
                                        <h1>Cards</h1>
                                    </div>
                                    <div class="ml-auto d-flex align-items-center">
                                        <nav>
                                            <ol class="breadcrumb p-0 m-b-0">
                                                <li class="breadcrumb-item">
                                                    <a href="{{ route('admin.dashboard') }}"><i class="ti ti-home"></i></a>
                                                </li>
                                                <li class="breadcrumb-item">
                                                    UI Kit
                                                </li>
                                                <li class="breadcrumb-item active text-primary" aria-current="page">Cards</li>
                                            </ol>
                                        </nav>
                                    </div>
                                </div>
                                <!-- end page title -->
                            </div>
                        </div>
                        <!-- end row -->
                        <!-- begin row -->
                        <div class="row">
                            <div class="col-md-6">
                                <div class="card card-statistics ">
                                    <img class="card-img-top" src="{{ asset('assets/img/widget/01.jpg') }}" alt="Card image cap">
                                    <div class="card-body">
                                        <h4 class="card-title">Commitment</h4>
                                        <p class="card-text">Commitment is something that comes from understanding that everything has its price and then having the willingness to pay that price. This is important because nobody wants to put significant effort into something, only to find out after the fact that the price was too high.The price is something not necessarily defined as financial. It could be time, effort, sacrifice, money or perhaps, something else.</p>
                                        <a href="javascript:void(0)" class="btn btn-primary mt-2">Read More</a>
                                    </div>
                                </div>
                            </div>
                            <!-- More card examples omitted for brevity -->
                        </div>
                        <!-- end row -->
                    </div>
                    <!-- end container-fluid -->
                </div>
                <!-- end app-main -->
@endsection
