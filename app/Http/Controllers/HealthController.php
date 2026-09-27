<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Redis;
use Throwable;

/**
 * Deep health check: 200 only when BOTH MySQL and Redis answer, otherwise 503.
 * Error details go to the log, never to the response body.
 */
class HealthController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $checks = [
            'database' => $this->check('database', fn () => DB::select('select 1')),
            'redis' => $this->check('redis', fn () => Redis::connection()->ping()),
        ];

        $healthy = ! in_array('fail', $checks, true);

        return response()->json([
            'status' => $healthy ? 'ok' : 'fail',
            'checks' => $checks,
        ], $healthy ? 200 : 503);
    }

    private function check(string $name, callable $probe): string
    {
        try {
            $probe();

            return 'ok';
        } catch (Throwable $e) {
            Log::error("Health check failed: {$name}", ['error' => $e->getMessage()]);

            return 'fail';
        }
    }
}
