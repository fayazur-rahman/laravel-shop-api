<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\SendOrderConfirmation;
use App\Models\Order;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    /** Checkout: turn the session cart into an order, then queue the confirmation email. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_email' => ['required', 'email', 'max:255'],
        ]);

        $cart = $request->session()->get('cart', []);
        if (empty($cart)) {
            throw ValidationException::withMessages(['cart' => 'Cart is empty.']);
        }

        $order = DB::transaction(function () use ($cart, $data) {
            $products = Product::whereIn('id', array_keys($cart))->lockForUpdate()->get()->keyBy('id');

            $total = 0;
            $lines = [];
            foreach ($cart as $productId => $qty) {
                $product = $products->get($productId);
                if (! $product || $product->stock < $qty) {
                    throw ValidationException::withMessages([
                        'cart' => "Insufficient stock for product {$productId}.",
                    ]);
                }
                $product->decrement('stock', $qty);
                $total += $product->price_cents * $qty;
                $lines[] = [
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'quantity' => $qty,
                    'unit_price_cents' => $product->price_cents,
                ];
            }

            $order = Order::create($data + ['total_cents' => $total, 'status' => 'placed']);
            $order->items()->createMany($lines);

            return $order;
        });

        // Pushed onto the queue (Redis in production); the HTTP request does not wait for SMTP.
        SendOrderConfirmation::dispatch($order);

        $request->session()->forget('cart');

        return response()->json(['data' => $order->load('items')], 201);
    }

    public function show(Order $order): JsonResponse
    {
        return response()->json(['data' => $order->load('items')]);
    }
}
