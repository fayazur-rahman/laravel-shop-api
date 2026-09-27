<?php

namespace Database\Seeders;

use App\Models\Product;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    /**
     * Fixed, idempotent catalogue: safe to run on every deploy (updateOrCreate on SKU).
     */
    public function run(): void
    {
        $products = [
            ['sku' => 'TEA-001', 'name' => 'Sylhet Green Tea (250g)', 'price_cents' => 45000, 'stock' => 120],
            ['sku' => 'MUG-001', 'name' => 'Ceramic Mug', 'price_cents' => 35000, 'stock' => 60],
            ['sku' => 'BAG-001', 'name' => 'Jute Tote Bag', 'price_cents' => 55000, 'stock' => 80],
            ['sku' => 'NTB-001', 'name' => 'A5 Notebook', 'price_cents' => 18000, 'stock' => 200],
            ['sku' => 'PEN-001', 'name' => 'Gel Pen (pack of 5)', 'price_cents' => 12000, 'stock' => 300],
            ['sku' => 'LMP-001', 'name' => 'Desk Lamp', 'price_cents' => 250000, 'stock' => 15],
            ['sku' => 'KBD-001', 'name' => 'Mechanical Keyboard', 'price_cents' => 650000, 'stock' => 10],
            ['sku' => 'CBL-001', 'name' => 'USB-C Cable (1m)', 'price_cents' => 30000, 'stock' => 150],
        ];

        foreach ($products as $p) {
            Product::updateOrCreate(
                ['sku' => $p['sku']],
                $p + ['description' => $p['name'].' — demo catalogue item.'],
            );
        }
    }
}
