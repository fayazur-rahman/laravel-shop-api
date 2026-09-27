<?php

use App\Http\Controllers\HealthController;
use Illuminate\Support\Facades\Route;

// No middleware: no session, no cookies — health must not depend on Redis sessions.
Route::get('/health', HealthController::class);

Route::get('/', fn () => response()->json([
    'app' => config('app.name'),
    'docs' => 'See README.md — API lives under /api, health at /health (deep) and /up (shallow).',
]));
