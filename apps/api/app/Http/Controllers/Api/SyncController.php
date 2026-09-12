<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SyncPullRequest;
use App\Http\Requests\SyncPushRequest;
use App\Models\User;
use App\Support\Sync\SyncService;
use Illuminate\Http\JsonResponse;

/**
 * Senkron uç noktaları — istemcinin sunucuyla konuştuğu TEK yazma ve TEK okuma yüzeyi.
 * "Müşteri/sipariş CRUD" istemcide yerel Drift işlemidir; sunucuya yalnız push/pull ile yansır.
 *
 * server_time ve api_version yanıta AppendServerMeta middleware'i tarafından eklenir
 * (istemci saat offset'i + istemci-sunucu sürüm çarpıklığının görünürlüğü).
 */
class SyncController extends Controller
{
    /**
     * POST /api/v1/sync/push — outbox olaylarını idempotent uygular, tenant seq'ini ilerletir.
     *
     * İstek yalnız ZARF doğrulamasından geçer (SyncPushRequest); olay içeriği SyncService içinde
     * olay bazında denetlenir. Bu yüzden `validated()['events']` elemanlarının biçimi GARANTİ
     * DEĞİLDİR — bozuk eleman 422 değil, `results[i].status = 'rejected'` üretir.
     */
    public function push(SyncPushRequest $request, SyncService $sync): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var list<mixed> $events */
        $events = $request->validated()['events'];

        return response()->json($sync->push($user, $events));
    }

    /**
     * GET /api/v1/sync/pull?since=&limit=&snapshot_cursor= — since=0 snapshot, since>0 delta.
     *
     * `snapshot_cursor` verilirse snapshot SAYFALANIR (2026-09-12 saha arızası: 9.047 müşterili
     * bir bayide tek parça snapshot 15,3 MB tutuyor ve telefonun 25 sn'lik zaman aşımına
     * sığmıyordu). Parametresiz istek eski davranışı görür — gerekçe SyncPullRequest'te.
     */
    public function pull(SyncPullRequest $request, SyncService $sync): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $validated = $request->validated();
        $since = (int) ($validated['since'] ?? 0);
        $limit = (int) ($validated['limit'] ?? 500);
        $sayfali = (bool) ($validated['sayfali'] ?? false);
        $snapshotImleci = (string) ($validated['snapshot_cursor'] ?? '');

        return response()->json($sync->pull($user, $since, $limit, $sayfali, $snapshotImleci));
    }
}
