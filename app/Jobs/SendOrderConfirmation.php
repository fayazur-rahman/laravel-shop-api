<?php

namespace App\Jobs;

use App\Mail\OrderConfirmation;
use App\Models\Order;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Sends the order-confirmation email off the request path.
 * Runs on the queue connection named by QUEUE_CONNECTION (redis in production)
 * and is executed by `php artisan queue:work`.
 */
class SendOrderConfirmation implements ShouldQueue
{
    use Queueable;

    /** Attempts before the job is moved to the failed_jobs table. */
    public int $tries = 3;

    /** Seconds to wait between attempts. */
    public array $backoff = [10, 30, 60];

    public function __construct(public Order $order) {}

    public function handle(): void
    {
        $order = $this->order->load('items');

        Mail::to($order->customer_email)->send(new OrderConfirmation($order));

        $order->forceFill(['confirmation_sent_at' => now()])->save();

        Log::info('Order confirmation sent', ['order_id' => $order->id]);
    }

    public function failed(?Throwable $e): void
    {
        Log::error('Order confirmation failed permanently', [
            'order_id' => $this->order->id,
            'error' => $e?->getMessage(),
        ]);
    }
}
