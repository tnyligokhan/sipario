<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class UserResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'tenant_id' => $this->tenant_id,
            'name' => $this->name,
            'email' => $this->email,
            // Giriş kimliği (tasarım `s-giris.jsx`). İstemci bunu "kim girdi" göstermek ve
            // oturumu yeniden kurmak için saklar.
            'username' => $this->username,
            'role' => $this->role->value,
        ];
        // password ASLA döndürülmez.
    }
}
