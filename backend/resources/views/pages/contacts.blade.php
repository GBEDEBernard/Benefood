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
                                        <h1>Contacts</h1>
                                    </div>
                                    <div class="ml-auto d-flex align-items-center">
                                        <nav>
                                            <ol class="breadcrumb p-0 m-b-0">
                                                <li class="breadcrumb-item">
                                                    <a href="{{ route('admin.dashboard') }}"><i class="ti ti-home"></i></a>
                                                </li>
                                                <li class="breadcrumb-item">
                                                    Pages
                                                </li>
                                                <li class="breadcrumb-item active text-primary" aria-current="page">Contacts</li>
                                            </ol>
                                        </nav>
                                    </div>
                                </div>
                                <!-- end page title -->
                            </div>
                        </div>
                        <!-- end row -->

                        <!--start contact contant-->

                        <div class="row">
                            <div class="col-xxl-3 col-xl-4  col-sm-6">
                                <div class="card card-statistics contact-contant">
                                    <div class="card-body py-4">
                                        <div class="d-flex align-items-center">
                                            <div class="bg-img">
                                                <img src="{{ asset('assets/img/avtar/01.jpg') }}" alt="" class="img-fluid">
                                            </div>
                                            <div class="ml-3">
                                                <h4 class="mb-0">Lizzy Halfman</h4>
                                                <p><span class="badge badge-warning-inverse px-2 py-1 mt-1">Home</span></p>
                                            </div>
                                        </div>
                                        <div>
                                            <ul class="nav">
                                                <li class="nav-item">
                                                    <div class="img-icon"><i class="fa fa-mobile"></i></div>
                                                </li>
                                                <li class="nav-item">
                                                    <p>021-843-8478</p>
                                                </li>
                                            </ul>
                                            <ul class="nav">
                                                <li class="nav-item">
                                                    <div class="img-icon"><i class="fa fa-phone"></i></div>
                                                </li>
                                                <li class="nav-item">
                                                    <p>40-1440-8546</p>
                                                </li>
                                            </ul>
                                            <ul class="nav">
                                                <li class="nav-item">
                                                    <div class="img-icon"><i class="fa fa-envelope-o"></i></div>
                                                </li>
                                                <li class="nav-item">
                                                    <p>Lizzy.Halfman@gmail.com</p>
                                                </li>
                                            </ul>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- More contacts omitted for brevity -->
                        </div>

                        <!--end contact contant-->
                    </div>
                    <!-- end container-fluid -->
                </div>
                <!-- end app-main -->
@endsection
