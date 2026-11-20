<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\Medication;
use App\Models\MedicationDoseOccurrence;
use App\Services\MedicationAdherenceService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * P2.2 — medication adherence (A1 30m grace, B1 online server SoT).
 */
class P22MedicationAdherenceTest extends TestCase
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

    private function seedMed(int $elderlyId, array $overrides = []): Medication
    {
        return Medication::create(array_merge([
            'M_Name' => 'ضغط',
            'M_much' => '1 حبة',
            'M_RepatTime' => 'صباحاً',
            'Elderly_ID' => $elderlyId,
        ], $overrides));
    }

    public function test_crud_regression_list_create_update_delete(): void
    {
        $elderly = $this->makeElderly('771022001');
        $token = $this->tokenFor($elderly);

        $create = $this->withToken($token)->postJson('/api/medications', [
            'M_Name' => 'أسبرين',
            'M_much' => 'حبة',
            'M_RepatTime' => 'مساءً',
            'Elderly_ID' => $elderly->Eldery_ID,
        ]);
        $create->assertCreated()->assertJsonPath('status', 'success');
        $id = (int) $create->json('data.Medicayion_ID');

        $this->withToken($token)->getJson('/api/medications')
            ->assertOk()
            ->assertJsonPath('status', 'success');

        $this->withToken($token)->putJson('/api/medications/'.$id, [
            'M_Name' => 'أسبرين 100',
            'M_much' => 'حبة',
            'M_RepatTime' => 'صباحاً',
        ])->assertOk()->assertJsonPath('data.M_Name', 'أسبرين 100');

        $this->withToken($token)->postJson('/api/medications/'.$id.'/delete')
            ->assertOk()
            ->assertJsonPath('status', 'success');

        $this->assertDatabaseMissing('medications', ['Medicayion_ID' => $id]);
    }

    public function test_today_materializes_occurrence_with_stable_key(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-11-20 07:00:00'));
        $elderly = $this->makeElderly('771022002');
        $med = $this->seedMed((int) $elderly->Eldery_ID, ['M_RepatTime' => 'صباحاً']);

        $res = $this->withToken($this->tokenFor($elderly))
            ->withHeader('X-Test-Now', '2026-11-20 07:00:00')
            ->getJson('/api/medications/doses/today?civil_date=2026-11-20');

        $res->assertOk()->assertJsonPath('status', 'success');
        $this->assertCount(1, $res->json('data'));
        $this->assertSame('2026-11-20:morning', $res->json('data.0.occurrence_key'));
        $this->assertSame('upcoming', $res->json('data.0.display_state'));
        $this->assertSame($med->Medicayion_ID, $res->json('data.0.Medicayion_ID'));

        $this->assertDatabaseHas('medication_dose_occurrences', [
            'Medicayion_ID' => $med->Medicayion_ID,
            'occurrence_key' => '2026-11-20:morning',
            'adherence_state' => 'unconfirmed',
        ]);
        Carbon::setTestNow();
    }

    public function test_display_transitions_due_then_overdue_not_confirmed(): void
    {
        $svc = app(MedicationAdherenceService::class);
        $elderly = $this->makeElderly('771022003');
        $med = $this->seedMed((int) $elderly->Eldery_ID, ['M_RepatTime' => 'صباحاً']);

        $occ = $svc->ensureOccurrenceForMedicationDay(
            $med,
            '2026-11-20',
            Carbon::parse('2026-11-20 07:00:00')
        );

        $this->assertSame(
            MedicationAdherenceService::DISPLAY_UPCOMING,
            $svc->displayState($occ, Carbon::parse('2026-11-20 07:59:00'))
        );
        $this->assertSame(
            MedicationAdherenceService::DISPLAY_DUE,
            $svc->displayState($occ, Carbon::parse('2026-11-20 08:10:00'))
        );
        $this->assertSame(
            MedicationAdherenceService::DISPLAY_OVERDUE_NOT_CONFIRMED,
            $svc->displayState($occ, Carbon::parse('2026-11-20 08:31:00'))
        );
        // Honesty: never claim medical "missed" as persisted state.
        $this->assertSame('unconfirmed', $occ->fresh()->adherence_state);
    }

    public function test_elderly_confirm_within_grace_is_taken(): void
    {
        $elderly = $this->makeElderly('771022004');
        $med = $this->seedMed((int) $elderly->Eldery_ID, ['M_RepatTime' => 'صباحاً']);

        $res = $this->withToken($this->tokenFor($elderly))
            ->withHeader('X-Test-Now', '2026-11-20 08:15:00')
            ->postJson('/api/medications/doses/confirm', [
                'Medicayion_ID' => $med->Medicayion_ID,
                'civil_date' => '2026-11-20',
                'client_confirm_id' => 'cid-taken-1',
            ]);

        $res->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.display_state', 'taken')
            ->assertJsonPath('data.adherence_state', 'taken');

        $this->assertNotNull($res->json('data.confirmed_at'));
        $this->assertDatabaseHas('medication_dose_occurrences', [
            'Medicayion_ID' => $med->Medicayion_ID,
            'adherence_state' => 'taken',
            'client_confirm_id' => 'cid-taken-1',
        ]);
        $this->assertDatabaseHas('medication_dose_events', [
            'Medicayion_ID' => $med->Medicayion_ID,
            'event_type' => 'confirmed',
        ]);
    }

    public function test_late_confirm_preserves_timestamp_and_late_state(): void
    {
        $elderly = $this->makeElderly('771022005');
        $med = $this->seedMed((int) $elderly->Eldery_ID, ['M_RepatTime' => 'صباحاً']);

        $res = $this->withToken($this->tokenFor($elderly))
            ->withHeader('X-Test-Now', '2026-11-20 10:45:00')
            ->postJson('/api/medications/doses/confirm', [
                'Medicayion_ID' => $med->Medicayion_ID,
                'civil_date' => '2026-11-20',
                'client_confirm_id' => 'cid-late-1',
            ]);

        $res->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.display_state', 'late_confirmed')
            ->assertJsonPath('data.adherence_state', 'late_confirmed')
            ->assertJsonPath('data.confirmed_at', '2026-11-20 10:45:00');
    }

    public function test_duplicate_confirm_is_idempotent(): void
    {
        $elderly = $this->makeElderly('771022006');
        $med = $this->seedMed((int) $elderly->Eldery_ID, ['M_RepatTime' => 'ظهراً']);

        $payload = [
            'Medicayion_ID' => $med->Medicayion_ID,
            'civil_date' => '2026-11-20',
            'client_confirm_id' => 'cid-dup-1',
        ];

        $first = $this->withToken($this->tokenFor($elderly))
            ->withHeader('X-Test-Now', '2026-11-20 13:40:00')
            ->postJson('/api/medications/doses/confirm', $payload);
        $first->assertOk()->assertJsonPath('status', 'success');
        $confirmedAt = $first->json('data.confirmed_at');

        $second = $this->withToken($this->tokenFor($elderly))
            ->withHeader('X-Test-Now', '2026-11-20 14:00:00')
            ->postJson('/api/medications/doses/confirm', $payload);
        $second->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('meta.idempotent', true)
            ->assertJsonPath('data.confirmed_at', $confirmedAt);

        $this->assertSame(
            1,
            MedicationDoseOccurrence::query()
                ->where('Medicayion_ID', $med->Medicayion_ID)
                ->whereDate('scheduled_date', '2026-11-20')
                ->count()
        );
    }

    public function test_caregiver_can_read_linked_but_cannot_confirm(): void
    {
        $elderly = $this->makeElderly('771022007');
        $cg = $this->makeCaregiver('772022007', (int) $elderly->Eldery_ID);
        $med = $this->seedMed((int) $elderly->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->withHeader('X-Test-Now', '2026-11-20 09:00:00')
            ->getJson('/api/medications/doses/today?Elderly_ID='.$elderly->Eldery_ID.'&civil_date=2026-11-20')
            ->assertOk()
            ->assertJsonPath('status', 'success');

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/medications/doses/confirm', [
                'Medicayion_ID' => $med->Medicayion_ID,
                'civil_date' => '2026-11-20',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error_type', 'forbidden');
    }

    public function test_unrelated_caregiver_denied_today_and_history(): void
    {
        $e1 = $this->makeElderly('771022008', 'E1');
        $e2 = $this->makeElderly('771022009', 'E2');
        $cg2 = $this->makeCaregiver('772022009', (int) $e2->Eldery_ID);
        $this->seedMed((int) $e1->Eldery_ID);

        $this->withToken($this->tokenFor($cg2))
            ->getJson('/api/medications/doses/today?Elderly_ID='.$e1->Eldery_ID)
            ->assertStatus(403);

        $this->withToken($this->tokenFor($cg2))
            ->getJson('/api/medications/doses/history?Elderly_ID='.$e1->Eldery_ID)
            ->assertStatus(403);
    }

    public function test_elderly_cannot_confirm_other_elderly_med(): void
    {
        $e1 = $this->makeElderly('771022010', 'E1');
        $e2 = $this->makeElderly('771022011', 'E2');
        $med = $this->seedMed((int) $e1->Eldery_ID);

        $this->withToken($this->tokenFor($e2))
            ->postJson('/api/medications/doses/confirm', [
                'Medicayion_ID' => $med->Medicayion_ID,
                'civil_date' => '2026-11-20',
            ])
            ->assertStatus(403);
    }

    public function test_schedule_change_does_not_rewrite_past_confirmed_occurrence(): void
    {
        $svc = app(MedicationAdherenceService::class);
        $elderly = $this->makeElderly('771022012');
        $med = $this->seedMed((int) $elderly->Eldery_ID, ['M_RepatTime' => 'صباحاً']);

        $occ = $svc->ensureOccurrenceForMedicationDay(
            $med,
            '2026-11-19',
            Carbon::parse('2026-11-19 08:00:00')
        );
        $result = $svc->confirmDose(
            $med,
            $elderly,
            '2026-11-19',
            $occ->occurrence_key,
            'cid-hist-1',
            Carbon::parse('2026-11-19 08:20:00')
        );
        $this->assertTrue($result['ok']);
        $confirmedTime = $occ->fresh()->scheduled_time;
        $confirmedAt = $occ->fresh()->confirmed_at;

        $med->update(['M_RepatTime' => 'مساءً']);
        $again = $svc->ensureOccurrenceForMedicationDay(
            $med->fresh(),
            '2026-11-19',
            Carbon::parse('2026-11-20 12:00:00')
        );

        $this->assertSame($occ->DoseOccurrence_ID, $again->DoseOccurrence_ID);
        $this->assertSame('morning', $again->slot);
        // Schedule edit must not rewrite frozen past occurrence timing/confirm.
        $this->assertSame(
            substr((string) $confirmedTime, 0, 5),
            substr((string) $again->scheduled_time, 0, 5)
        );
        $this->assertEquals(
            $confirmedAt?->format('Y-m-d H:i:s'),
            $again->confirmed_at?->format('Y-m-d H:i:s')
        );
        $this->assertContains($again->adherence_state, ['taken', 'late_confirmed']);
    }

    public function test_invalid_civil_date_rejected(): void
    {
        $elderly = $this->makeElderly('771022013');
        $this->seedMed((int) $elderly->Eldery_ID);

        $this->withToken($this->tokenFor($elderly))
            ->getJson('/api/medications/doses/today?civil_date=20-11-2026')
            ->assertOk()
            ->assertJsonPath('status', 'error')
            ->assertJsonPath('error_type', 'validation_error');

        $this->withToken($this->tokenFor($elderly))
            ->postJson('/api/medications/doses/confirm', [
                'Medicayion_ID' => 1,
                'civil_date' => 'not-a-date',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'error');
    }

    public function test_history_horizon_clamped_and_legacy_parity(): void
    {
        $elderly = $this->makeElderly('771022014');
        $this->seedMed((int) $elderly->Eldery_ID, ['M_RepatTime' => 'مساءً']);
        $token = $this->tokenFor($elderly);

        $rest = $this->withToken($token)
            ->withHeader('X-Test-Now', '2026-11-20 12:00:00')
            ->getJson('/api/medications/doses/history?from=2026-01-01&to=2026-11-20');
        $rest->assertOk()->assertJsonPath('status', 'success');
        $this->assertSame('2026-11-07', $rest->json('meta.from'));
        $this->assertSame('2026-11-20', $rest->json('meta.to'));

        $legacy = $this->withToken($token)
            ->withHeader('X-Test-Now', '2026-11-20 12:00:00')
            ->postJson('/api/legacy', [
                'action' => 'get_medication_adherence_history',
                'Elderly_ID' => $elderly->Eldery_ID,
                'from' => '2026-11-19',
                'to' => '2026-11-20',
            ]);
        $legacy->assertOk()->assertJsonPath('status', 'success');
        $this->assertNotEmpty($legacy->json('data'));
    }

    public function test_malformed_confirm_missing_med_id(): void
    {
        $elderly = $this->makeElderly('771022015');
        $this->withToken($this->tokenFor($elderly))
            ->postJson('/api/medications/doses/confirm', [
                'civil_date' => '2026-11-20',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'error')
            ->assertJsonPath('error_type', 'validation_error');
    }

    public function test_unauthenticated_dose_endpoints_rejected(): void
    {
        $this->getJson('/api/medications/doses/today')->assertStatus(401);
        $this->getJson('/api/medications/doses/history')->assertStatus(401);
        $this->postJson('/api/medications/doses/confirm', [])->assertStatus(401);
        $this->postJson('/api/legacy', ['action' => 'confirm_medication_dose'])
            ->assertStatus(401);
    }
}
