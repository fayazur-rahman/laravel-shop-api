<?php

namespace Tests\Feature;

use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

/**
 * Redis serializes cached values; phpunit.xml's array store does not, which
 * hid a bug where every cache hit on GET /api/products returned an
 * __PHP_Incomplete_Class instead of the list. Turning on serialization for
 * the array store makes the test take the same path as production.
 */
class ProductListCacheSerializationTest extends TestCase
{
    use RefreshDatabase;

    public function test_cached_product_list_survives_serialization(): void
    {
        config(['cache.stores.array.serialize' => true]);
        Cache::forgetDriver('array'); // rebuild the store with the new setting

        Product::factory()->count(3)->create();

        $miss = $this->getJson('/api/products')->assertOk();
        $hit = $this->getJson('/api/products')->assertOk();

        $missData = $miss->json('data');
        $hitData = $hit->json('data');

        $this->assertIsArray($missData);
        $this->assertTrue(array_is_list($missData), 'cache-miss data is not a list');
        $this->assertIsArray($hitData);
        $this->assertTrue(array_is_list($hitData), 'cache-hit data is not a list');
        $this->assertCount(3, $missData);
        $this->assertCount(count($missData), $hitData);
    }
}
