Hi {{ $order->customer_name }},

Thanks for your order #{{ $order->id }}.

@foreach ($order->items as $item)
- {{ $item->product_name }} x {{ $item->quantity }} @ {{ number_format($item->unit_price_cents / 100, 2) }}
@endforeach

Total: {{ number_format($order->total_cents / 100, 2) }}

— {{ config('app.name') }}
