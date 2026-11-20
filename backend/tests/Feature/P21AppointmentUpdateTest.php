<?php

namespace Tests\Feature;

use App\Models\Appointment;
use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * P2.1 — appointment UPDATE lifecycle (REST + legacy), synthetic sqlite.
 */
class P21AppointmentUpdateTest extends TestCase
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

    private function seedAppointment(int $elderlyId, array $overrides = []): Appointment
    {
        return Appointment::create(array_merge([
            'A_Date' => '2026-12-20',
            'A_Time' => '09:00:00',
            'A_DateType' => 'موعد طبيب',
            'A_Location' => 'عيادة أ',
            'A_Note' => 'ملاحظة قديمة',
            'Elderly_ID' => $elderlyId,
        ], $overrides));
    }

    public function test_owner_elderly_can_update_own_appointment(): void
    {
        $elderly = $this->makeElderly('771021001', 'OwnerEL');
        $appt = $this->seedAppointment((int) $elderly->Eldery_ID);

        $res = $this->withToken($this->tokenFor($elderly))
            ->putJson('/api/appointments/'.$appt->Appointment_ID, [
                'A_Date' => '2026-12-25',
                'A_Time' => '10:30:00',
                'A_DateType' => 'فحص مخبري',
                'A_Location' => 'مختبر ب',
                'A_Note' => 'ملاحظة جديدة',
            ]);

        $res->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.Appointment_ID', $appt->Appointment_ID)
            ->assertJsonPath('data.A_Date', '2026-12-25')
            ->assertJsonPath('data.A_DateType', 'فحص مخبري')
            ->assertJsonPath('data.Elderly_ID', $elderly->Eldery_ID);

        $this->assertDatabaseHas('appointments', [
            'Appointment_ID' => $appt->Appointment_ID,
            'A_Date' => '2026-12-25',
            'A_Location' => 'مختبر ب',
            'Elderly_ID' => $elderly->Eldery_ID,
        ]);
    }

    public function test_linked_caregiver_can_update_appointment(): void
    {
        $elderly = $this->makeElderly('771021002');
        $cg = $this->makeCaregiver('772021002', (int) $elderly->Eldery_ID);
        $appt = $this->seedAppointment((int) $elderly->Eldery_ID);

        $res = $this->withToken($this->tokenFor($cg))
            ->postJson('/api/appointments/'.$appt->Appointment_ID, [
                'A_Date' => '2026-12-22',
                'A_Time' => '11:00:00',
                'A_DateType' => 'زيارة عائلية',
                'A_Location' => 'المنزل',
                'A_Note' => '',
            ]);

        $res->assertOk()->assertJsonPath('status', 'success');
        $this->assertSame($appt->Appointment_ID, (int) $res->json('data.Appointment_ID'));
        $this->assertDatabaseHas('appointments', [
            'Appointment_ID' => $appt->Appointment_ID,
            'A_DateType' => 'زيارة عائلية',
        ]);
    }

    public function test_unrelated_caregiver_denied(): void
    {
        $e1 = $this->makeElderly('771021003', 'E1');
        $e2 = $this->makeElderly('771021004', 'E2');
        $cg2 = $this->makeCaregiver('772021004', (int) $e2->Eldery_ID);
        $appt = $this->seedAppointment((int) $e1->Eldery_ID);

        $this->withToken($this->tokenFor($cg2))
            ->putJson('/api/appointments/'.$appt->Appointment_ID, [
                'A_Date' => '2026-12-28',
                'A_Time' => '09:00:00',
                'A_DateType' => 'محاولة',
                'A_Location' => 'x',
                'A_Note' => '',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error_type', 'forbidden');

        $this->assertDatabaseHas('appointments', [
            'Appointment_ID' => $appt->Appointment_ID,
            'A_DateType' => 'موعد طبيب',
        ]);
    }

    public function test_unrelated_elderly_denied(): void
    {
        $e1 = $this->makeElderly('771021005', 'E1');
        $e2 = $this->makeElderly('771021006', 'E2');
        $appt = $this->seedAppointment((int) $e1->Eldery_ID);

        $this->withToken($this->tokenFor($e2))
            ->putJson('/api/appointments/'.$appt->Appointment_ID, [
                'A_Date' => '2026-12-28',
                'A_Time' => '09:00:00',
                'A_DateType' => 'محاولة',
                'A_Location' => 'x',
                'A_Note' => '',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error_type', 'forbidden');
    }

    public function test_unauthenticated_update_rejected(): void
    {
        $elderly = $this->makeElderly('771021007');
        $appt = $this->seedAppointment((int) $elderly->Eldery_ID);

        $this->putJson('/api/appointments/'.$appt->Appointment_ID, [
            'A_Date' => '2026-12-28',
            'A_Time' => '09:00:00',
            'A_DateType' => 'x',
            'A_Location' => 'x',
            'A_Note' => '',
        ])
            ->assertStatus(401)
            ->assertJsonPath('error_type', 'unauthenticated');
    }

    public function test_invalid_date_rejected(): void
    {
        $elderly = $this->makeElderly('771021008');
        $cg = $this->makeCaregiver('772021008', (int) $elderly->Eldery_ID);
        $appt = $this->seedAppointment((int) $elderly->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->putJson('/api/appointments/'.$appt->Appointment_ID, [
                'A_Date' => '2026-13-40',
                'A_Time' => '09:00:00',
                'A_DateType' => 'موعد طبيب',
                'A_Location' => 'عيادة',
                'A_Note' => '',
            ])
            ->assertStatus(422)
            ->assertJsonPath('status', 'error')
            ->assertJsonPath('error_type', 'invalid_date');

        $this->assertDatabaseHas('appointments', [
            'Appointment_ID' => $appt->Appointment_ID,
            'A_Date' => '2026-12-20',
        ]);
    }

    public function test_invalid_time_rejected(): void
    {
        $elderly = $this->makeElderly('771021009');
        $cg = $this->makeCaregiver('772021009', (int) $elderly->Eldery_ID);
        $appt = $this->seedAppointment((int) $elderly->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->putJson('/api/appointments/'.$appt->Appointment_ID, [
                'A_Date' => '2026-12-20',
                'A_Time' => '25:99',
                'A_DateType' => 'موعد طبيب',
                'A_Location' => 'عيادة',
                'A_Note' => '',
            ])
            ->assertStatus(422)
            ->assertJsonPath('error_type', 'invalid_time');
    }

    public function test_ownership_change_rejected_and_id_preserved(): void
    {
        $e1 = $this->makeElderly('771021010', 'E1');
        $e2 = $this->makeElderly('771021011', 'E2');
        $cg = $this->makeCaregiver('772021010', (int) $e1->Eldery_ID);
        $appt = $this->seedAppointment((int) $e1->Eldery_ID);
        $originalId = $appt->Appointment_ID;

        $this->withToken($this->tokenFor($cg))
            ->putJson('/api/appointments/'.$originalId, [
                'A_Date' => '2026-12-21',
                'A_Time' => '09:00:00',
                'A_DateType' => 'موعد طبيب',
                'A_Location' => 'عيادة',
                'A_Note' => '',
                'Elderly_ID' => $e2->Eldery_ID,
            ])
            ->assertStatus(422)
            ->assertJsonPath('error_type', 'ownership_immutable');

        $reloaded = Appointment::find($originalId);
        $this->assertNotNull($reloaded);
        $this->assertSame((int) $e1->Eldery_ID, (int) $reloaded->Elderly_ID);
        $this->assertSame($originalId, (int) $reloaded->Appointment_ID);
    }

    public function test_missing_appointment_returns_404(): void
    {
        $elderly = $this->makeElderly('771021012');
        $cg = $this->makeCaregiver('772021012', (int) $elderly->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->putJson('/api/appointments/999999', [
                'A_Date' => '2026-12-20',
                'A_Time' => '09:00:00',
                'A_DateType' => 'x',
                'A_Location' => 'x',
                'A_Note' => '',
            ])
            ->assertStatus(404)
            ->assertJsonPath('error_type', 'not_found');
    }

    public function test_legacy_update_appointment_authz_matches_rest(): void
    {
        $e1 = $this->makeElderly('771021013', 'E1');
        $e2 = $this->makeElderly('771021014', 'E2');
        $cg1 = $this->makeCaregiver('772021013', (int) $e1->Eldery_ID, 'CG1');
        $cg2 = $this->makeCaregiver('772021014', (int) $e2->Eldery_ID, 'CG2');
        $appt = $this->seedAppointment((int) $e1->Eldery_ID);

        $this->withToken($this->tokenFor($cg1))
            ->postJson('/api/legacy', [
                'action' => 'update_appointment',
                'Appointment_ID' => $appt->Appointment_ID,
                'A_Date' => '2026-12-30',
                'A_Time' => '14:00:00',
                'A_DateType' => 'تحديث ليجاسي',
                'A_Location' => 'عيادة ليجاسي',
                'A_Note' => 'ok',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.Appointment_ID', $appt->Appointment_ID);

        $this->app['auth']->forgetGuards();

        $this->withToken($this->tokenFor($cg2))
            ->postJson('/api/legacy', [
                'action' => 'update_appointment',
                'Appointment_ID' => $appt->Appointment_ID,
                'A_Date' => '2026-12-31',
                'A_Time' => '14:00:00',
                'A_DateType' => 'محظور',
                'A_Location' => 'x',
                'A_Note' => '',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error_type', 'forbidden');
    }

    public function test_create_list_delete_still_work_after_update(): void
    {
        $elderly = $this->makeElderly('771021015');
        $cg = $this->makeCaregiver('772021015', (int) $elderly->Eldery_ID);
        $token = $this->tokenFor($cg);

        $create = $this->withToken($token)->postJson('/api/appointments', [
            'A_Date' => '2026-11-25',
            'A_Time' => '08:00:00',
            'A_DateType' => 'إنشاء',
            'A_Location' => 'عيادة',
            'A_Note' => '',
            'Elderly_ID' => $elderly->Eldery_ID,
        ]);
        $create->assertCreated()->assertJsonPath('status', 'success');
        $id = (int) $create->json('data.Appointment_ID');

        $this->withToken($token)
            ->putJson('/api/appointments/'.$id, [
                'A_Date' => '2026-11-26',
                'A_Time' => '08:30:00',
                'A_DateType' => 'محدّث',
                'A_Location' => 'عيادة 2',
                'A_Note' => 'n',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'success');

        $list = $this->withToken($token)->getJson('/api/appointments?Elderly_ID='.$elderly->Eldery_ID);
        $list->assertOk()->assertJsonPath('status', 'success');
        $rows = collect($list->json('data'));
        $this->assertTrue($rows->contains(fn ($r) => (int) $r['Appointment_ID'] === $id
            && $r['A_DateType'] === 'محدّث'));

        $this->withToken($token)
            ->postJson('/api/appointments/'.$id.'/delete')
            ->assertOk()
            ->assertJsonPath('status', 'success');

        $this->assertDatabaseMissing('appointments', ['Appointment_ID' => $id]);
    }

    public function test_persist_reload_keeps_updated_fields(): void
    {
        $elderly = $this->makeElderly('771021016');
        $cg = $this->makeCaregiver('772021016', (int) $elderly->Eldery_ID);
        $appt = $this->seedAppointment((int) $elderly->Eldery_ID);
        $id = $appt->Appointment_ID;

        $this->withToken($this->tokenFor($cg))
            ->putJson('/api/appointments/'.$id, [
                'A_Date' => '2027-01-05',
                'A_Time' => '16:45:00',
                'A_DateType' => 'إعادة تحميل',
                'A_Location' => 'مستوصف',
                'A_Note' => 'بعد التحديث',
            ])
            ->assertOk();

        $fresh = Appointment::find($id);
        $this->assertNotNull($fresh);
        $this->assertSame('2027-01-05', $fresh->A_Date instanceof \DateTimeInterface
            ? $fresh->A_Date->format('Y-m-d')
            : (string) $fresh->A_Date);
        $this->assertSame('إعادة تحميل', $fresh->A_DateType);
        $this->assertSame('مستوصف', $fresh->A_Location);
        $this->assertSame('بعد التحديث', $fresh->A_Note);
        $this->assertSame($id, (int) $fresh->Appointment_ID);
    }
}
