<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\Medication;
use App\Models\MedicationDoseOccurrence;
use App\Models\Notification;
use App\Services\CaregiverOverdueAlertService;
use App\Services\MedicationAdherenceService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * P2.3 — Channel B overdue alerts + mark-read AuthZ (focused).
 */
class P23NotificationAlertsTest extends TestCase
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

    private function seedOverdueOccurrence(int $elderlyId, string $civilDate = '2026-11-20'): MedicationDoseOccurrence
    {
        $med = Medication::create([
            'M_Name' => 'ضغط',
            'M_much' => '1 حبة',
            'M_RepatTime' => 'صباحاً',
            'Elderly_ID' => $elderlyId,
        ]);

        $svc = app(MedicationAdherenceService::class);
        Carbon::setTestNow(Carbon::parse($civilDate.' 07:00:00'));
        $occ = $svc->ensureOccurrenceForMedicationDay($med, $civilDate, Carbon::now());
        Carbon::setTestNow();

        return $occ->fresh();
    }

    public function test_overdue_job_creates_one_alert_per_linked_caregiver(): void
    {
        $elderly = $this->makeElderly('771033001');
        $cg = $this->makeCaregiver('771033002', (int) $elderly->Eldery_ID);
        $occ = $this->seedOverdueOccurrence((int) $elderly->Eldery_ID);

        Carbon::setTestNow(Carbon::parse('2026-11-20 09:00:00')); // past morning + 30m grace
        $result = app(CaregiverOverdueAlertService::class)->dispatch(Carbon::now());
        Carbon::setTestNow();

        $this->assertSame(1, $result['created']);
        $this->assertDatabaseHas('notifications', [
            'Caregiver_ID' => $cg->Caregivers_ID,
            'Eldery_ID' => $elderly->Eldery_ID,
            'event_type' => CaregiverOverdueAlertService::EVENT_TYPE,
            'occurrence_key' => $occ->occurrence_key,
            'N_Status' => Notification::STATUS_UNREAD,
        ]);

        $row = Notification::query()->first();
        $this->assertStringContainsString('غير مؤكد', (string) $row->N_Message);
        $this->assertStringNotContainsString('فائت طبي', (string) $row->N_Message);
        $this->assertDoesNotMatchRegularExpression('/\bmissed\b/i', (string) $row->N_Title.$row->N_Message);
    }

    public function test_overdue_job_is_idempotent(): void
    {
        $elderly = $this->makeElderly('771033003');
        $this->makeCaregiver('771033004', (int) $elderly->Eldery_ID);
        $this->seedOverdueOccurrence((int) $elderly->Eldery_ID);

        Carbon::setTestNow(Carbon::parse('2026-11-20 09:00:00'));
        $svc = app(CaregiverOverdueAlertService::class);
        $first = $svc->dispatch(Carbon::now());
        $second = $svc->dispatch(Carbon::now());
        Carbon::setTestNow();

        $this->assertSame(1, $first['created']);
        $this->assertSame(0, $second['created']);
        $this->assertSame(1, Notification::query()->count());
    }

    public function test_artisan_command_dispatches_alerts(): void
    {
        $elderly = $this->makeElderly('771033005');
        $this->makeCaregiver('771033006', (int) $elderly->Eldery_ID);
        $this->seedOverdueOccurrence((int) $elderly->Eldery_ID);

        $exit = Artisan::call('notifications:dispatch-overdue-med-alerts', [
            '--now' => '2026-11-20 09:00:00',
        ]);
        $this->assertSame(0, $exit);
        $this->assertSame(1, Notification::query()->count());
    }

    public function test_unlinked_caregiver_does_not_receive_new_alert(): void
    {
        $elderly = $this->makeElderly('771033007');
        $cg = $this->makeCaregiver('771033008', null); // not linked
        $this->seedOverdueOccurrence((int) $elderly->Eldery_ID);

        Carbon::setTestNow(Carbon::parse('2026-11-20 09:00:00'));
        $result = app(CaregiverOverdueAlertService::class)->dispatch(Carbon::now());
        Carbon::setTestNow();

        $this->assertSame(0, $result['created']);
        $this->assertDatabaseMissing('notifications', [
            'Caregiver_ID' => $cg->Caregivers_ID,
        ]);
    }

    public function test_revoke_linkage_stops_new_alerts_and_isolates_list(): void
    {
        $elderly = $this->makeElderly('771033009');
        $cg = $this->makeCaregiver('771033010', (int) $elderly->Eldery_ID);
        $occ = $this->seedOverdueOccurrence((int) $elderly->Eldery_ID);

        Carbon::setTestNow(Carbon::parse('2026-11-20 09:00:00'));
        app(CaregiverOverdueAlertService::class)->dispatch(Carbon::now());
        $this->assertSame(1, Notification::query()->count());

        // Revoke linkage
        $cg->Eldery_ID = null;
        $cg->save();

        // Second occurrence day — no fan-out
        $med = Medication::query()->where('Elderly_ID', $elderly->Eldery_ID)->first();
        $svc = app(MedicationAdherenceService::class);
        Carbon::setTestNow(Carbon::parse('2026-11-21 07:00:00'));
        $svc->ensureOccurrenceForMedicationDay($med, '2026-11-21', Carbon::now());
        Carbon::setTestNow(Carbon::parse('2026-11-21 09:00:00'));
        $after = app(CaregiverOverdueAlertService::class)->dispatch(Carbon::now());
        Carbon::setTestNow();
        $this->assertSame(0, $after['created']);

        // Other caregiver cannot read this CG's alert
        $other = $this->makeCaregiver('771033011', (int) $elderly->Eldery_ID);
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $otherList = $this->withToken($this->tokenFor($other))->getJson('/api/notifications');
        $otherList->assertOk()->assertJsonPath('status', 'success');
        $this->assertSame(0, count($otherList->json('data')));

        // Owner still sees historical row addressed to them
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $list = $this->withToken($this->tokenFor($cg->fresh()))->getJson('/api/notifications');
        $list->assertOk();
        $this->assertCount(1, $list->json('data'));
        $this->assertSame($occ->occurrence_key, $list->json('data.0.occurrence_key'));
    }

    public function test_mark_read_authz_and_unread_filter(): void
    {
        $elderly = $this->makeElderly('771033012');
        $cg = $this->makeCaregiver('771033013', (int) $elderly->Eldery_ID);
        $other = $this->makeCaregiver('771033014', (int) $elderly->Eldery_ID);
        $this->seedOverdueOccurrence((int) $elderly->Eldery_ID);

        Carbon::setTestNow(Carbon::parse('2026-11-20 09:00:00'));
        app(CaregiverOverdueAlertService::class)->dispatch(Carbon::now());
        Carbon::setTestNow();

        // Job fans out to both linked CGs
        $this->assertSame(2, Notification::query()->count());
        $mine = Notification::query()->where('Caregiver_ID', $cg->Caregivers_ID)->first();

        $otherToken = $this->tokenFor($other);
        $cgToken = $this->tokenFor($cg);

        $this->app['auth']->forgetGuards();
        $this->withToken($otherToken)
            ->postJson('/api/notifications/'.$mine->Notifications_ID.'/read')
            ->assertStatus(403);

        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $this->withToken($cgToken)
            ->postJson('/api/notifications/'.$mine->Notifications_ID.'/read')
            ->assertOk()
            ->assertJsonPath('data.N_Status', Notification::STATUS_READ);

        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $unread = $this->withToken($cgToken)
            ->getJson('/api/notifications?unread_only=1');
        $unread->assertOk();
        $this->assertCount(0, $unread->json('data'));
    }

    public function test_urgent_in_app_create_requires_linkage(): void
    {
        $elderly = $this->makeElderly('771033015');
        $cg = $this->makeCaregiver('771033016', null);

        $res = $this->withToken($this->tokenFor($cg))->postJson('/api/notifications', [
            'N_Title' => 'تذكير عاجل',
            'N_Message' => 'يرجى تناول الدواء',
            'N_Type' => 'urgent_med',
        ]);
        $res->assertOk()->assertJsonPath('status', 'error');
        $this->assertSame('no_linked_elderly', $res->json('error_type'));

        $cg->Eldery_ID = $elderly->Eldery_ID;
        $this->assertTrue($cg->save());
        $cg = $cg->fresh();
        $this->assertSame((int) $elderly->Eldery_ID, (int) $cg->Eldery_ID);

        $this->app['auth']->forgetGuards();
        $ok = $this->withToken($this->tokenFor($cg))->postJson('/api/notifications', [
            'N_Title' => 'تذكير عاجل',
            'N_Message' => 'يرجى تناول الدواء',
            'N_Type' => 'urgent_med',
            'Eldery_ID' => $elderly->Eldery_ID,
        ]);
        if ($ok->status() !== 201) {
            fwrite(STDERR, 'URGENT_FAIL '.$ok->status().' '.$ok->getContent().' cg='.json_encode($cg->toArray())."\n");
        }
        $ok->assertCreated()->assertJsonPath('status', 'success');
    }

    public function test_p22_baselines_still_pass_grace_display(): void
    {
        $svc = app(MedicationAdherenceService::class);
        $elderly = $this->makeElderly('771033017');
        $med = Medication::create([
            'M_Name' => 'أسبرين',
            'M_much' => 'حبة',
            'M_RepatTime' => 'صباحاً',
            'Elderly_ID' => $elderly->Eldery_ID,
        ]);
        Carbon::setTestNow(Carbon::parse('2026-11-20 07:00:00'));
        $occ = $svc->ensureOccurrenceForMedicationDay($med, '2026-11-20', Carbon::now());
        $this->assertSame('upcoming', $svc->displayState($occ, Carbon::parse('2026-11-20 07:00:00')));
        $this->assertSame(
            MedicationAdherenceService::DISPLAY_OVERDUE_NOT_CONFIRMED,
            $svc->displayState($occ, Carbon::parse('2026-11-20 09:00:00'))
        );
        Carbon::setTestNow();
    }
}
