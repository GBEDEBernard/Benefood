<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\DeliveryZone;
use App\Models\Product;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function index(Request $request)
    {
        $vendors = Vendor::count();
        $products = Product::count();
        $users = User::count();
        $zones = DeliveryZone::count();

        return view('admin.dashboard', compact('vendors', 'products', 'users', 'zones'));
    }
}
