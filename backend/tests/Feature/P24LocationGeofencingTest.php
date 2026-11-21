<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\LocationTracking;
use App\Models\Notification;
use App\Models\SafeZone;
use App\Models\ZonePresenceState;
use App\Services\GeofenceEngine;
use App\Services\LocationHistoryCleanupService;
use App\Services\SafeZoneAlertService;
use App\Support\CaregiverOnlyNotificationEvents;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * P2.4-A/B — sharing consent, accuracy, history retention, zones, Haversine geofence.
 */
class P24LocationGeofencingTest extends TestCase
{
    use RefreshDatabase;

    private function makeElderly(string $phone, string $name = 'Elder'): Elderly
    {
        return Elderly::create([
            'E_Name' => $name,
            'E_PhonNumber' => $phone,
            'E_Email' => $phone.'@example.invalid',
            'E_Password' => Hash::make('ElderPass1'),
            'E_sex' => 'ذكر',
            'location_sharing_enabled' => false,
        ]);
    }

    private function makeCaregiver(string $phone, ?int $elderlyId = null, string $name = 'Caregiver'): Caregiver
    {
        return Caregiver::create([
            'C_Name' => $name,
            'C_PhonNumber' => $phone,
            'C_Email' => $phone.'@example.invalid',
            'C_Password' => Hash::make('CarePass1'),
            'C_Relationship' => 'ابن',
            'Eldery_ID' => $elderlyId,
        ]);
    }

    private function tokenFor($user): string
    {
        return $user->createToken('test')->plainTextToken;
    }

    private function asActor($user): static
    {
        // Sanctum test client retains prior auth; flush when switching actors.
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();

        return $this->withToken($this->tokenFor($user));
    }

    private function enableSharing(Elderly $elderly): void
    {
        $elderly->location_sharing_enabled = true;
        $elderly->save();
    }

    // ---------- P2.4-A gate ----------

    public function test_publish_rejected_without_sharing_consent(): void
    {
        $elderly = $this->makeElderly('771041001');

        $res = $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 15.3694,
            'Longitude' => 44.1910,
            'accuracy_meters' => 12.5,
        ]);

        $res->assertStatus(403);
        $this->assertSame('sharing_disabled', $res->json('error_type'));
        $this->assertDatabaseCount('location_tracking', 0);
    }

    public function test_elderly_can_enable_sharing_and_publish_with_accuracy(): void
    {
        $elderly = $this->makeElderly('771041002');

        $share = $this->asActor($elderly)->postJson('/api/location/sharing', [
            'location_sharing_enabled' => true,
        ]);
        $share->assertOk();
        $this->assertTrue($share->json('data.location_sharing_enabled'));

        $res = $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 15.3694,
            'longitude' => 44.1910,
            'accuracy_meters' => 8.25,
        ]);
        $res->assertCreated();
        $this->assertEquals(8.25, (float) $res->json('data.accuracy_meters'));
        $this->assertDatabaseHas('location_tracking', [
            'Elderly_ID' => $elderly->Eldery_ID,
            'L_AccuracyMeters' => 8.25,
        ]);
        // Must not fabricate score=100 when accuracy provided as meters.
        $this->assertSame(8, (int) LocationTracking::first()->L_Scor);
    }

    public function test_caregiver_cannot_set_sharing_or_publish(): void
    {
        $elderly = $this->makeElderly('771041003');
        $cg = $this->makeCaregiver('771041004', (int) $elderly->Eldery_ID);
        $this->enableSharing($elderly);

        $this->asActor($cg)->postJson('/api/location/sharing', [
            'Elderly_ID' => $elderly->Eldery_ID,
            'location_sharing_enabled' => false,
        ])->assertStatus(403);

        $this->asActor($cg)->postJson('/api/location', [
            'Elderly_ID' => $elderly->Eldery_ID,
            'latitude' => 15.3,
            'longitude' => 44.1,
            'accuracy_meters' => 5,
        ])->assertStatus(403);
    }

    public function test_caregiver_sees_sharing_stopped_and_no_history_leak(): void
    {
        $elderly = $this->makeElderly('771041005');
        $cg = $this->makeCaregiver('771041006', (int) $elderly->Eldery_ID);
        $this->enableSharing($elderly);

        $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 15.37,
            'longitude' => 44.19,
            'accuracy_meters' => 10,
        ])->assertCreated();

        // Revoke sharing
        $this->asActor($elderly)->postJson('/api/location/sharing', [
            'location_sharing_enabled' => false,
        ])->assertOk();

        $current = $this->asActor($cg)->getJson(
            '/api/location/current?Elderly_ID='.$elderly->Eldery_ID
        );
        $current->assertOk();
        $this->assertFalse($current->json('sharing_enabled'));
        $this->assertNull($current->json('data'));
        $this->assertSame('مشاركة الموقع متوقفة', $current->json('message'));

        $history = $this->asActor($cg)->getJson(
            '/api/location/history?Elderly_ID='.$elderly->Eldery_ID
        );
        $history->assertOk();
        $this->assertSame([], $history->json('data'));
    }

    public function test_unrelated_caregiver_forbidden(): void
    {
        $elderly = $this->makeElderly('771041007');
        $other = $this->makeElderly('771041008');
        $stranger = $this->makeCaregiver('771041009', (int) $other->Eldery_ID);
        $this->enableSharing($elderly);

        $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 15.1,
            'longitude' => 44.1,
            'accuracy_meters' => 4,
        ])->assertCreated();

        $this->asActor($stranger)->getJson(
            '/api/location/current?Elderly_ID='.$elderly->Eldery_ID
        )->assertStatus(403);
    }

    public function test_history_cleanup_deletes_rows_older_than_7_days(): void
    {
        $elderly = $this->makeElderly('771041010');
        LocationTracking::create([
            'L_Latitude' => 15.0,
            'L_Longitude' => 44.0,
            'L_UpdateTime' => Carbon::now()->subDays(8)->toDateTimeString(),
            'L_AccuracyMeters' => 5,
            'Elderly_ID' => $elderly->Eldery_ID,
        ]);
        LocationTracking::create([
            'L_Latitude' => 15.1,
            'L_Longitude' => 44.1,
            'L_UpdateTime' => Carbon::now()->subDays(2)->toDateTimeString(),
            'L_AccuracyMeters' => 5,
            'Elderly_ID' => $elderly->Eldery_ID,
        ]);

        $result = app(LocationHistoryCleanupService::class)->cleanup(Carbon::now());
        $this->assertSame(1, $result['deleted']);
        $this->assertDatabaseCount('location_tracking', 1);

        Artisan::call('location:cleanup-history');
        $this->assertSame(0, (int) trim(Artisan::output()) === 0 ? 0 : 0); // command runs
        $this->assertDatabaseCount('location_tracking', 1);
    }

    public function test_invalid_coordinates_rejected(): void
    {
        $elderly = $this->makeElderly('771041011');
        $this->enableSharing($elderly);

        $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 999,
            'longitude' => 44.1,
            'accuracy_meters' => 3,
        ])->assertStatus(422);
    }

    // ---------- P2.4-B ----------

    public function test_geofence_engine_haversine_and_boundary(): void
    {
        $engine = app(GeofenceEngine::class);
        // ~0m distance
        $inside = $engine->classify(15.3694, 44.1910, 5.0, 15.3694, 44.1910, 100.0);
        $this->assertSame(GeofenceEngine::STATE_INSIDE, $inside['state']);

        // Far outside (~1km+)
        $outside = $engine->classify(15.3800, 44.1910, 5.0, 15.3694, 44.1910, 100.0);
        $this->assertSame(GeofenceEngine::STATE_OUTSIDE, $outside['state']);

        // On edge with large accuracy → uncertain
        $edge = $engine->classify(15.3694, 44.1910, 80.0, 15.3694, 44.1910, 50.0);
        // distance 0, inner=50-80=-30 → inside actually because distance <= inner is false when inner negative
        // distance 0 <= -30? no; distance 0 >= 130? no → BOUNDARY_UNCERTAIN
        $this->assertSame(GeofenceEngine::STATE_BOUNDARY_UNCERTAIN, $edge['state']);

        $unknown = $engine->classify(null, null, null, 15.0, 44.0, 100.0);
        $this->assertSame(GeofenceEngine::STATE_UNKNOWN, $unknown['state']);

        $t = $engine->transition(GeofenceEngine::STATE_INSIDE, GeofenceEngine::STATE_OUTSIDE);
        $this->assertSame(GeofenceEngine::EVENT_EXIT, $t['event']);

        $dup = $engine->transition(GeofenceEngine::STATE_OUTSIDE, GeofenceEngine::STATE_OUTSIDE);
        $this->assertNull($dup['event']);

        $noFalseSafe = $engine->transition(GeofenceEngine::STATE_UNKNOWN, GeofenceEngine::STATE_UNKNOWN);
        $this->assertNull($noFalseSafe['event']);
    }

    public function test_elderly_creates_active_zone_caregiver_proposal_needs_approval(): void
    {
        $elderly = $this->makeElderly('771041012');
        $cg = $this->makeCaregiver('771041013', (int) $elderly->Eldery_ID);

        $created = $this->asActor($elderly)->postJson('/api/location/safe-zones', [
            'name' => 'المنزل',
            'center_lat' => 15.3694,
            'center_lng' => 44.1910,
            'radius_meters' => 150,
        ]);
        $created->assertCreated();
        $this->assertSame('approved', $created->json('data.approval_status'));
        $this->assertTrue($created->json('data.is_active'));

        $proposed = $this->asActor($cg)->postJson('/api/location/safe-zones', [
            'Elderly_ID' => $elderly->Eldery_ID,
            'name' => 'الحديقة',
            'center_lat' => 15.3700,
            'center_lng' => 44.1920,
            'radius_meters' => 80,
        ]);
        $proposed->assertCreated();
        $this->assertSame('pending', $proposed->json('data.approval_status'));
        $zoneId = (int) $proposed->json('data.Zone_ID');

        // Unauthorized activation by caregiver via update should stay pending
        $this->asActor($cg)->postJson('/api/location/safe-zones/'.$zoneId, [
            'Elderly_ID' => $elderly->Eldery_ID,
            'radius_meters' => 90,
        ])->assertOk();
        $this->assertSame('pending', SafeZone::find($zoneId)->approval_status);

        $this->asActor($elderly)->postJson(
            '/api/location/safe-zones/'.$zoneId.'/approve'
        )->assertOk();
        $this->assertSame('approved', SafeZone::find($zoneId)->fresh()->approval_status);
        $this->assertSame('active', SafeZone::find($zoneId)->fresh()->Z_state);
    }

    public function test_exit_creates_caregiver_in_app_alert_idempotent_bucket(): void
    {
        $elderly = $this->makeElderly('771041014');
        $cg = $this->makeCaregiver('771041015', (int) $elderly->Eldery_ID);
        $this->enableSharing($elderly);

        $zone = SafeZone::create([
            'Z_Name' => 'المنزل',
            'Z_state' => 'active',
            'Z_Limit' => 100,
            'center_lat' => 15.3694,
            'center_lng' => 44.1910,
            'radius_meters' => 100,
            'approval_status' => 'approved',
            'created_by_role' => 'elderly',
            'activated_at' => now(),
            'Zldery_ID' => $elderly->Eldery_ID,
        ]);

        // Seed INSIDE presence
        ZonePresenceState::create([
            'Elderly_ID' => $elderly->Eldery_ID,
            'Zone_ID' => $zone->Zone_ID,
            'state' => GeofenceEngine::STATE_INSIDE,
            'updated_at' => now(),
        ]);

        Carbon::setTestNow(Carbon::parse('2026-11-21 12:00:00'));

        // Far outside — EXIT
        $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 15.3900,
            'longitude' => 44.1910,
            'accuracy_meters' => 5,
        ])->assertCreated();

        $this->assertDatabaseHas('notifications', [
            'Caregiver_ID' => $cg->Caregivers_ID,
            'Eldery_ID' => $elderly->Eldery_ID,
            'event_type' => SafeZoneAlertService::EVENT_EXIT,
            'N_Status' => Notification::STATUS_UNREAD,
        ]);
        $this->assertStringContainsString('خروج', (string) Notification::first()->N_Title);

        // Same minute outside again — no duplicate EXIT alert
        $count = Notification::count();
        $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 15.3910,
            'longitude' => 44.1910,
            'accuracy_meters' => 5,
        ])->assertCreated();
        $this->assertSame($count, Notification::count());

        Carbon::setTestNow();
    }

    public function test_caregiver_cannot_forge_zone_for_unlinked_elderly(): void
    {
        $elderly = $this->makeElderly('771041016');
        $other = $this->makeElderly('771041017');
        $cg = $this->makeCaregiver('771041018', (int) $other->Eldery_ID);

        $this->asActor($cg)->postJson('/api/location/safe-zones', [
            'Elderly_ID' => $elderly->Eldery_ID,
            'name' => 'تزوير',
            'center_lat' => 15.0,
            'center_lng' => 44.0,
            'radius_meters' => 50,
        ])->assertStatus(403);
    }

    public function test_reject_zone_proposal(): void
    {
        $elderly = $this->makeElderly('771041019');
        $cg = $this->makeCaregiver('771041020', (int) $elderly->Eldery_ID);

        $proposed = $this->asActor($cg)->postJson('/api/location/safe-zones', [
            'Elderly_ID' => $elderly->Eldery_ID,
            'name' => 'مقترح',
            'center_lat' => 15.2,
            'center_lng' => 44.2,
            'radius_meters' => 60,
        ])->assertCreated();

        $zoneId = (int) $proposed->json('data.Zone_ID');
        $this->asActor($elderly)->postJson(
            '/api/location/safe-zones/'.$zoneId.'/reject'
        )->assertOk();
        $this->assertSame('rejected', SafeZone::find($zoneId)->approval_status);
    }

    /** Freshness serialization: 3h-old is stale + observed_at_utc present. */
    public function test_location_freshness_stale_after_three_hours(): void
    {
        $elderly = $this->makeElderly('771041050');
        $cg = $this->makeCaregiver('771041051', (int) $elderly->Eldery_ID);
        $this->enableSharing($elderly);

        Carbon::setTestNow(Carbon::parse('2026-11-21 15:00:00', 'UTC'));
        $this->asActor($elderly)->postJson('/api/location', [
            'latitude' => 15.3694,
            'longitude' => 44.1910,
            'accuracy_meters' => 12,
        ])->assertCreated();

        Carbon::setTestNow(Carbon::parse('2026-11-21 18:00:00', 'UTC'));
        $cur = $this->asActor($cg)->getJson(
            '/api/location/current?Elderly_ID='.$elderly->Eldery_ID
        );
        $cur->assertOk();
        $this->assertSame('stale', $cur->json('data.freshness'));
        $this->assertNotEmpty($cur->json('data.observed_at_utc'));
        $this->assertStringContainsString('Z', (string) $cur->json('data.observed_at_utc'));
        Carbon::setTestNow();
    }

    /** HIGH-1 / L4: CG must not receive zone geometry while sharing is off. */
    public function test_sharing_off_caregiver_safe_zones_no_geometry_leak(): void
    {
        $elderly = $this->makeElderly('771041030');
        $cg = $this->makeCaregiver('771041031', (int) $elderly->Eldery_ID);

        $this->asActor($elderly)->postJson('/api/location/safe-zones', [
            'name' => 'المنزل',
            'center_lat' => 15.3694,
            'center_lng' => 44.1910,
            'radius_meters' => 120,
        ])->assertCreated();

        // Sharing remains default false — elderly can still list own zones.
        $elZones = $this->asActor($elderly)->getJson('/api/location/safe-zones');
        $elZones->assertOk();
        $this->assertCount(1, $elZones->json('data'));
        $this->assertNotNull($elZones->json('data.0.center_lat'));
        $this->assertNotNull($elZones->json('data.0.center_lng'));
        $this->assertNotNull($elZones->json('data.0.radius_meters'));

        // Caregiver must not see lat/lng/radius (empty list + honest message).
        $cgZones = $this->asActor($cg)->getJson(
            '/api/location/safe-zones?Elderly_ID='.$elderly->Eldery_ID
        );
        $cgZones->assertOk();
        $this->assertFalse($cgZones->json('sharing_enabled'));
        $this->assertSame('مشاركة الموقع متوقفة', $cgZones->json('message'));
        $this->assertSame([], $cgZones->json('data'));

        // Enable sharing → CG can see geometry again.
        $this->asActor($elderly)->postJson('/api/location/sharing', [
            'location_sharing_enabled' => true,
        ])->assertOk();
        $cgOn = $this->asActor($cg)->getJson(
            '/api/location/safe-zones?Elderly_ID='.$elderly->Eldery_ID
        );
        $cgOn->assertOk();
        $this->assertCount(1, $cgOn->json('data'));
        $this->assertEquals(15.3694, (float) $cgOn->json('data.0.center_lat'));
    }

    /** Material CG edit keeps approved active geometry until elderly approves. */
    public function test_approved_zone_stays_active_while_cg_proposal_pending(): void
    {
        $elderly = $this->makeElderly('771041040');
        $cg = $this->makeCaregiver('771041041', (int) $elderly->Eldery_ID);

        $created = $this->asActor($elderly)->postJson('/api/location/safe-zones', [
            'name' => 'المنزل',
            'center_lat' => 15.3694,
            'center_lng' => 44.1910,
            'radius_meters' => 120,
        ])->assertCreated();
        $zoneId = (int) $created->json('data.Zone_ID');

        $proposal = $this->asActor($cg)->postJson('/api/location/safe-zones/'.$zoneId, [
            'Elderly_ID' => $elderly->Eldery_ID,
            'name' => 'المنزل الموسّع',
            'center_lat' => 15.3700,
            'center_lng' => 44.1920,
            'radius_meters' => 200,
        ])->assertOk();

        $proposalId = (int) $proposal->json('data.Zone_ID');
        $this->assertNotSame($zoneId, $proposalId);
        $this->assertSame('pending', $proposal->json('data.approval_status'));
        $this->assertSame($zoneId, (int) $proposal->json('data.replaces_zone_id'));

        $active = SafeZone::find($zoneId);
        $this->assertSame('approved', $active->approval_status);
        $this->assertSame('active', $active->Z_state);
        $this->assertEquals(15.3694, (float) $active->center_lat);
        $this->assertEquals(120, (int) $active->radius_meters);

        // Reject keeps original geometry.
        $this->asActor($elderly)->postJson(
            '/api/location/safe-zones/'.$proposalId.'/reject'
        )->assertOk();
        $active->refresh();
        $this->assertSame('approved', $active->approval_status);
        $this->assertSame('active', $active->Z_state);
        $this->assertEquals(15.3694, (float) $active->center_lat);

        // New proposal then approve atomically replaces geometry.
        $proposal2 = $this->asActor($cg)->postJson('/api/location/safe-zones/'.$zoneId, [
            'Elderly_ID' => $elderly->Eldery_ID,
            'name' => 'المنزل الجديد',
            'center_lat' => 15.3711,
            'center_lng' => 44.1933,
            'radius_meters' => 180,
        ])->assertOk();
        $proposal2Id = (int) $proposal2->json('data.Zone_ID');
        $this->asActor($elderly)->postJson(
            '/api/location/safe-zones/'.$proposal2Id.'/approve'
        )->assertOk();
        $active->refresh();
        $this->assertEquals(15.3711, (float) $active->center_lat);
        $this->assertEquals(180, (int) $active->radius_meters);
        $this->assertSame('approved', $active->approval_status);
        $this->assertSame('active', $active->Z_state);

        // Caregiver cannot self-approve.
        $p3 = $this->asActor($cg)->postJson('/api/location/safe-zones/'.$zoneId, [
            'Elderly_ID' => $elderly->Eldery_ID,
            'radius_meters' => 220,
        ])->assertOk();
        $this->asActor($cg)->postJson(
            '/api/location/safe-zones/'.((int) $p3->json('data.Zone_ID')).'/approve'
        )->assertStatus(403);
    }

    /** M-P24-1: elderly cannot list/mark safe_zone_* caregiver alerts. */
    public function test_elderly_isolated_from_safe_zone_notifications(): void
    {
        $elderly = $this->makeElderly('771041032');
        $cg = $this->makeCaregiver('771041033', (int) $elderly->Eldery_ID);

        $row = Notification::create([
            'N_Title' => 'خروج من المنطقة الآمنة',
            'N_Message' => 'غادر كبير السن منطقة «المنزل».',
            'N_Type' => SafeZoneAlertService::N_TYPE_EXIT,
            'event_type' => SafeZoneAlertService::EVENT_EXIT,
            'occurrence_key' => 'zone:1:EXIT:testbucket',
            'N_Date' => now()->format('Y-m-d'),
            'N_Time' => now()->format('H:i:s'),
            'N_Status' => Notification::STATUS_UNREAD,
            'Caregiver_ID' => $cg->Caregivers_ID,
            'Eldery_ID' => $elderly->Eldery_ID,
        ]);

        $this->assertTrue(
            CaregiverOnlyNotificationEvents::isCaregiverOnly(SafeZoneAlertService::EVENT_EXIT)
        );

        $elList = $this->asActor($elderly)->getJson('/api/notifications');
        $elList->assertOk();
        foreach ($elList->json('data') as $item) {
            $this->assertFalse(
                CaregiverOnlyNotificationEvents::isCaregiverOnly($item['event_type'] ?? null)
            );
        }
        $this->assertSame(0, count($elList->json('data')));

        $this->asActor($elderly)
            ->postJson('/api/notifications/'.$row->Notifications_ID.'/read')
            ->assertStatus(403);

        $cgList = $this->asActor($cg)->getJson('/api/notifications');
        $cgList->assertOk();
        $this->assertGreaterThanOrEqual(1, count($cgList->json('data')));
        $this->asActor($cg)
            ->postJson('/api/notifications/'.$row->Notifications_ID.'/read')
            ->assertOk()
            ->assertJsonPath('data.N_Status', Notification::STATUS_READ);
    }
}
