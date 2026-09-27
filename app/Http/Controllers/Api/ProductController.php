<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    /** Product list is cached in the cache store named by CACHE_STORE (redis in production). */
    public function index(): JsonResponse
    {
        $products = Cache::remember(Product::LIST_CACHE_KEY, now()->addMinutes(10), fn () => Product::orderBy('id')->get());

        return response()->json(['data' => $products]);
    }

    public function show(Product $product): JsonResponse
    {
        return response()->json(['data' => $product]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'sku' => ['required', 'string', 'max:64', 'unique:products,sku'],
            'description' => ['nullable', 'string'],
            'price_cents' => ['required', 'integer', 'min:0'],
            'stock' => ['required', 'integer', 'min:0'],
        ]);

        return response()->json(['data' => Product::create($data)], 201);
    }

    /**
     * Upload a product image to the default disk (FILESYSTEM_DISK).
     * local now; set FILESYSTEM_DISK=s3 (+ AWS_* env) and nothing in code changes.
     */
    public function uploadImage(Request $request, Product $product): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'image', 'max:2048'], // KB
        ]);

        $disk = Storage::disk();

        if ($product->image_path) {
            $disk->delete($product->image_path);
        }

        $path = $request->file('image')->store("products/{$product->id}");

        $product->update(['image_path' => $path]);

        return response()->json([
            'data' => $product->fresh(),
            'disk' => config('filesystems.default'),
        ], 201);
    }
}
