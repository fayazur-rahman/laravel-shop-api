<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The cart lives in the SESSION (SESSION_DRIVER=redis in production),
 * keyed by the session cookie. If Redis loses the session, the cart is gone.
 */
class CartController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json(['data' => self::summary($request->session()->get('cart', []))]);
    }

    public function add(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'quantity' => ['required', 'integer', 'min:1', 'max:100'],
        ]);

        $cart = $request->session()->get('cart', []);
        $cart[$data['product_id']] = ($cart[$data['product_id']] ?? 0) + $data['quantity'];
        $request->session()->put('cart', $cart);

        return response()->json(['data' => self::summary($cart)], 201);
    }

    public function remove(Request $request, Product $product): JsonResponse
    {
        $cart = $request->session()->get('cart', []);
        unset($cart[$product->id]);
        $request->session()->put('cart', $cart);

        return response()->json(['data' => self::summary($cart)]);
    }

    public function clear(Request $request): JsonResponse
    {
        $request->session()->forget('cart');

        return response()->json(['data' => self::summary([])]);
    }

    /** @param array<int,int> $cart product_id => quantity */
    public static function summary(array $cart): array
    {
        $products = Product::whereIn('id', array_keys($cart))->get()->keyBy('id');

        $items = [];
        $total = 0;
        foreach ($cart as $productId => $qty) {
            if (! $product = $products->get($productId)) {
                continue;
            }
            $line = $product->price_cents * $qty;
            $total += $line;
            $items[] = [
                'product_id' => $product->id,
                'name' => $product->name,
                'quantity' => $qty,
                'unit_price_cents' => $product->price_cents,
                'line_total_cents' => $line,
            ];
        }

        return ['items' => $items, 'total_cents' => $total];
    }
}
