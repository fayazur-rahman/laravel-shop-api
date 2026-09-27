<?php

namespace Tests\Feature;

use App\Jobs\SendOrderConfirmation;
use App\Mail\OrderConfirmation;
use App\Models\Order;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class CartAndOrderTest extends TestCase
{
    use RefreshDatabase;

    public function test_adds_item_to_session_cart(): void
    {
        $product = Product::factory()->create(['price_cents' => 500]);

        $this->postJson('/api/cart/items', ['product_id' => $product->id, 'quantity' => 2])
            ->assertCreated()
            ->assertJsonPath('data.total_cents', 1000)
            ->assertSessionHas('cart', [$product->id => 2]);
    }

    public function test_checkout_creates_order_decrements_stock_and_queues_email(): void
    {
        Queue::fake();
        $product = Product::factory()->create(['price_cents' => 500, 'stock' => 10]);

        $response = $this->withSession(['cart' => [$product->id => 3]])
            ->postJson('/api/orders', ['customer_name' => 'Kayes', 'customer_email' => 'buyer@example.com']);

        $response->assertCreated()->assertJsonPath('data.total_cents', 1500);
        $this->assertSame(7, $product->fresh()->stock);
        Queue::assertPushed(SendOrderConfirmation::class, fn ($job) => $job->order->id === $response->json('data.id'));
    }

    public function test_checkout_with_empty_cart_is_rejected(): void
    {
        $this->postJson('/api/orders', ['customer_name' => 'K', 'customer_email' => 'k@example.com'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('cart');
    }

    public function test_checkout_with_insufficient_stock_is_rejected_and_nothing_changes(): void
    {
        Queue::fake();
        $product = Product::factory()->create(['stock' => 1]);

        $this->withSession(['cart' => [$product->id => 5]])
            ->postJson('/api/orders', ['customer_name' => 'K', 'customer_email' => 'k@example.com'])
            ->assertStatus(422);

        $this->assertSame(1, $product->fresh()->stock);
        $this->assertSame(0, Order::count());
        Queue::assertNothingPushed();
    }

    public function test_confirmation_job_sends_mail_and_stamps_order(): void
    {
        Mail::fake();
        $order = Order::create(['customer_name' => 'K', 'customer_email' => 'k@example.com', 'total_cents' => 100]);

        (new SendOrderConfirmation($order))->handle();

        Mail::assertSent(OrderConfirmation::class, fn ($mail) => $mail->hasTo('k@example.com'));
        $this->assertNotNull($order->fresh()->confirmation_sent_at);
    }
}
