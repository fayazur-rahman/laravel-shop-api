<?php

namespace App\Models;

use Database\Factories\ProductFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    /** @use HasFactory<ProductFactory> */
    use HasFactory;

    public const LIST_CACHE_KEY = 'products:all';

    protected $fillable = ['name', 'sku', 'description', 'price_cents', 'stock', 'image_path'];

    protected function casts(): array
    {
        return [
            'price_cents' => 'integer',
            'stock' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        // Any write invalidates the cached product list.
        static::saved(fn () => cache()->forget(self::LIST_CACHE_KEY));
        static::deleted(fn () => cache()->forget(self::LIST_CACHE_KEY));
    }
}
