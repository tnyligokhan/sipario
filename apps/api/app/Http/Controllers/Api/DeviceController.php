<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\DeviceRegisterRequest;
use App\Http\Resources\DeviceResource;
use App\Models\Device;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class DeviceController extends Controller
{
    /** GET /api/v1/devices — yalnız oturumdaki bayinin cihazları (RLS zorlar). */
    public function index(): AnonymousResourceCollection
    {
        return DeviceResource::collection(
            Device::query()->orderByDesc('last_seen_at')->get()
        );
    }

    /** GET /api/v1/devices/{device} — başka bayinin cihazı RLS ile gizlenir → 404. */
    public function show(Device $device): DeviceResource
    {
        return new DeviceResource($device);
    }

    /**
     * POST /api/v1/devices — istemci üretimli id ile idempotent kayıt.
     * tenant_id gövdeden ALINMAZ; oturumdaki kullanıcının tenant'ıdır (WITH CHECK zorlar).
     * Başka bir bayiye ait device_id gönderilirse: RLS o satırı gizler, INSERT PK çakışmasına
     * düşer → 409 (B'nin kaydı ASLA değiştirilmez/görünmez).
     */
    public function store(DeviceRegisterRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = $request->user();

        try {
            $device = Device::updateOrCreate(
                ['id' => $data['device_id']],
                [
                    'tenant_id' => $user->tenant_id,
                    'user_id' => $user->id,
                    'platform' => $data['platform'],
                    'model' => $data['model'] ?? null,
                    'os_version' => $data['os_version'] ?? null,
                    'app_version' => $data['app_version'] ?? null,
                    'push_token' => $data['push_token'] ?? null,
                    'last_seen_at' => now(),
                ]
            );
        } catch (QueryException $e) {
            // 23505 = unique_violation: device_id başka bir bayide mevcut.
            if ($e->getCode() === '23505') {
                return response()->json(
                    ['message' => 'Bu cihaz kimliği başka bir hesapta kayıtlı.'],
                    409
                );
            }
            throw $e;
        }

        return (new DeviceResource($device))
            ->response()
            ->setStatusCode($device->wasRecentlyCreated ? 201 : 200);
    }
}
