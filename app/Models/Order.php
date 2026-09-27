<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Order extends Model
{
    protected $fillable = ['customer_name', 'customer_email', 'status', 'total_cents', 'confirmation_sent_at'];

    protected function casts(): array
    {
        return [
            'total_cents' => 'integer',
            'confirmation_sent_at' => 'datetime',
        ];
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }
}
