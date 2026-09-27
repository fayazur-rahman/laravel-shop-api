<?php

namespace Tests\Feature;

use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProductTest extends TestCase
{
    use RefreshDatabase;

    public function test_lists_products(): void
    {
        Product::factory()->count(3)->create();

        $this->getJson('/api/products')->assertOk()->assertJsonCount(3, 'data');
    }

    public function test_product_list_cache_is_invalidated_on_create(): void
    {
        Product::factory()->count(2)->create();
        $this->getJson('/api/products')->assertJsonCount(2, 'data');

        Product::factory()->create();

        $this->getJson('/api/products')->assertJsonCount(3, 'data');
    }

    public function test_creates_a_product(): void
    {
        $this->postJson('/api/products', [
            'name' => 'Test Mug', 'sku' => 'T-1', 'price_cents' => 1000, 'stock' => 5,
        ])->assertCreated()->assertJsonPath('data.sku', 'T-1');
    }

    public function test_rejects_invalid_product(): void
    {
        $this->postJson('/api/products', ['name' => ''])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'sku', 'price_cents', 'stock']);
    }

    public function test_uploads_image_to_the_default_disk(): void
    {
        Storage::fake(config('filesystems.default'));
        $product = Product::factory()->create();

        $response = $this->post("/api/products/{$product->id}/image", [
            'image' => UploadedFile::fake()->image('mug.jpg'),
        ], ['Accept' => 'application/json']);

        $response->assertCreated();
        $path = $response->json('data.image_path');
        $this->assertStringStartsWith("products/{$product->id}/", $path);
        Storage::disk()->assertExists($path);
    }

    public function test_rejects_non_image_upload(): void
    {
        Storage::fake(config('filesystems.default'));
        $product = Product::factory()->create();

        $this->post("/api/products/{$product->id}/image", [
            'image' => UploadedFile::fake()->create('notes.txt', 10, 'text/plain'),
        ], ['Accept' => 'application/json'])->assertStatus(422);
    }
}
