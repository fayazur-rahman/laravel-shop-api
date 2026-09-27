<?php

use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProductController;
use Illuminate\Support\Facades\Route;

// All routes here are prefixed with /api and run the "api" middleware group
// (which includes cookies + sessions — see bootstrap/app.php).

Route::get('/products', [ProductController::class, 'index']);
Route::post('/products', [ProductController::class, 'store']);
Route::get('/products/{product}', [ProductController::class, 'show']);
Route::post('/products/{product}/image', [ProductController::class, 'uploadImage']);

Route::get('/cart', [CartController::class, 'show']);
Route::post('/cart/items', [CartController::class, 'add']);
Route::delete('/cart/items/{product}', [CartController::class, 'remove']);
Route::delete('/cart', [CartController::class, 'clear']);

Route::post('/orders', [OrderController::class, 'store']);
Route::get('/orders/{order}', [OrderController::class, 'show']);
