<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Redis;
use RuntimeException;
use Tests\TestCase;

class HealthTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_is_200_when_database_and_redis_answer(): void
    {
        Redis::shouldReceive('connection->ping')->once()->andReturn(true);

        $this->getJson('/health')
            ->assertOk()
            ->assertExactJson(['status' => 'ok', 'checks' => ['database' => 'ok', 'redis' => 'ok']]);
    }

    public function test_health_is_503_when_redis_is_down(): void
    {
        Redis::shouldReceive('connection->ping')->once()->andThrow(new RuntimeException('Connection refused'));

        $this->getJson('/health')
            ->assertStatus(503)
            ->assertJsonPath('status', 'fail')
            ->assertJsonPath('checks.database', 'ok')
            ->assertJsonPath('checks.redis', 'fail');
    }

    public function test_shallow_up_route_exists(): void
    {
        $this->get('/up')->assertOk();
    }
}
