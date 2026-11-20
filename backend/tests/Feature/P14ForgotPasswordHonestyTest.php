<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * P1.4 Unit A: forgot-password stub must not claim email delivery.
 */
class P14ForgotPasswordHonestyTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_known_email_does_not_claim_sent(): void
    {
        Caregiver::create([
            'C_Name' => 'مقدم',
            'C_PhonNumber' => '770000101',
            'C_Relationship' => 'ابن',
            'C_Email' => 'cg-p14@example.invalid',
            'C_Password' => Hash::make('Secret123!'),
        ]);

        $res = $this->postJson('/api/auth/forgot-password', [
            'email' => 'cg-p14@example.invalid',
        ]);

        $res->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('reset_email_sent', false);

        $message = (string) $res->json('message');
        $this->assertStringNotContainsString('تم إرسال رابط', $message);
        $this->assertStringContainsString('غير مفعّل', $message);
    }

    public function test_forgot_password_unknown_email_still_errors(): void
    {
        $res = $this->postJson('/api/auth/forgot-password', [
            'email' => 'missing-p14@example.invalid',
        ]);

        $res->assertOk()
            ->assertJsonPath('status', 'error');
    }

    public function test_legacy_forgot_password_same_honesty(): void
    {
        Caregiver::create([
            'C_Name' => 'مقدم',
            'C_PhonNumber' => '770000102',
            'C_Relationship' => 'ابن',
            'C_Email' => 'cg-p14-legacy@example.invalid',
            'C_Password' => Hash::make('Secret123!'),
        ]);

        $res = $this->postJson('/api/legacy', [
            'action' => 'forgot_password',
            'email' => 'cg-p14-legacy@example.invalid',
        ]);

        $res->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('reset_email_sent', false);
    }
}
