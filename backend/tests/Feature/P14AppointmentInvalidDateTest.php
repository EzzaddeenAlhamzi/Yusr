<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * P1.4 gate journey E — invalid appointment date must not 500 / silent-fail.
 */
class P14AppointmentInvalidDateTest extends TestCase
{
    use RefreshDatabase;

    private function linkCaregiverWithElderly(): array
    {
        $elderly = Elderly::create([
            'E_Name' => 'مسن مواعيد',
            'E_PhonNumber' => '770014101',
            'E_Email' => 'elderly-appt-p14@example.invalid',
            'E_Password' => Hash::make('Secret123!'),
            'E_sex' => 'ذكر',
        ]);

        $caregiver = Caregiver::create([
            'C_Name' => 'مقدم مواعيد',
            'C_PhonNumber' => '770014102',
            'C_Email' => 'cg-appt-p14@example.invalid',
            'C_Password' => Hash::make('Secret123!'),
            'C_Relationship' => 'ابن',
            'Eldery_ID' => $elderly->Eldery_ID,
        ]);

        return [$caregiver, $elderly];
    }

    public function test_invalid_calendar_date_returns_error_not_sql_exception(): void
    {
        [$caregiver, $elderly] = $this->linkCaregiverWithElderly();
        $token = $caregiver->createToken('test')->plainTextToken;

        $res = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/appointments', [
                'A_Date' => '2026-13-40',
                'A_Time' => '09:00:00',
                'A_DateType' => 'موعد طبيب',
                'A_Location' => 'عيادة',
                'A_Note' => '',
                'Elderly_ID' => $elderly->Eldery_ID,
            ]);

        $res->assertOk()
            ->assertJsonPath('status', 'error')
            ->assertJsonPath('error_type', 'invalid_date');
        $this->assertStringNotContainsString('SQLSTATE', (string) $res->json('message'));
        $this->assertDatabaseCount('appointments', 0);
    }

    public function test_valid_date_still_creates_appointment(): void
    {
        [$caregiver, $elderly] = $this->linkCaregiverWithElderly();
        $token = $caregiver->createToken('test')->plainTextToken;

        $res = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/appointments', [
                'A_Date' => '2026-12-20',
                'A_Time' => '09:00:00',
                'A_DateType' => 'موعد طبيب',
                'A_Location' => 'عيادة',
                'A_Note' => '',
                'Elderly_ID' => $elderly->Eldery_ID,
            ]);

        $res->assertCreated()
            ->assertJsonPath('status', 'success');
        $this->assertDatabaseCount('appointments', 1);
    }
}
