<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * ŞİRKET masrafı (bizim giderimiz). `tenant_id` YOKtur — bkz. migration 005004.
 * Para İMZASIZ int KURUŞ. Yalnız created_at (append).
 *
 * @property string $id
 * @property Carbon $spent_on
 * @property string $category
 * @property int $amount_kurus
 * @property string|null $note
 * @property string|null $admin_user_id
 * @property Carbon|null $created_at
 */
class Expense extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'id',
        'spent_on',
        'category',
        'amount_kurus',
        'note',
        'admin_user_id',
    ];

    protected function casts(): array
    {
        return [
            'spent_on' => 'date',
            'amount_kurus' => 'integer',
            'created_at' => 'datetime',
        ];
    }
}
