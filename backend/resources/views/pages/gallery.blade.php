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
                                        <h1>Gallery</h1>
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
                                                <li class="breadcrumb-item active text-primary" aria-current="page">Gallery</li>
                                            </ol>
                                        </nav>
                                    </div>
                                </div>
                                <!-- end page title -->
                            </div>
                        </div>
                        <!-- end row -->


                        <!--start gallery -->
                        <div class="row magnific-wrapper">
                            <div class="col-xl-3 col-md-4 col-sm-6">
                                <div class="card card-statistics text-center">
                                    <div class="card-body p-0">
                                        <div class="portfolio-item">
                                            <img src="{{ asset('assets/img/widget/02.jpg') }}" alt="gallery-img">
                                            <div class="portfolio-overlay">
                                                <h4 class="text-white"><a href="javascript:void(0)">Your title here</a></h4>
                                            </div>
                                            <a class="popup portfolio-img view" href="{{ asset('assets/img/widget/02.jpg') }}"><i class="fa fa-arrows-alt"></i></a>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- More gallery items omitted for brevity -->
                        </div>
                        <!--end gallery-->
                    </div>
                    <!-- end container-fluid -->
                </div>
                <!-- end app-main -->
@endsection
