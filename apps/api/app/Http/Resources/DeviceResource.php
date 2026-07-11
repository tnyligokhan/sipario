<?php

namespace App\Http\Resources;

use App\Models\Device;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Device
 */
class DeviceResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'tenant_id' => $this->tenant_id,
            'user_id' => $this->user_id,
            'platform' => $this->platform,
            'model' => $this->model,
            'os_version' => $this->os_version,
            'app_version' => $this->app_version,
            'last_seen_at' => optional($this->last_seen_at)->toIso8601String(),
            'registered_at' => optional($this->created_at)->toIso8601String(),
        ];
    }
}
