<?php

namespace Tests\Feature;

use App\Models\Elderly;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * P1.4 gate Task 2D — elderly register → login round-trip on Laravel.
 */
class P14ElderlyRegisterLoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_elderly_register_then_login_returns_token(): void
    {
        $register = $this->postJson('/api/auth/elderly/register', [
            'E_Name' => 'كبير تجريبي',
            'E_PhonNumber' => '770014001',
            'E_Email' => 'elderly-p14-gate@example.invalid',
            'E_Password' => 'Secret123!',
            'E_sex' => 'ذكر',
        ]);

        $register->assertOk()
            ->assertJsonPath('status', 'success');

        $this->assertNotEmpty($register->json('token'));
        $this->assertDatabaseHas('elderly', [
            'E_PhonNumber' => '770014001',
            'E_Email' => 'elderly-p14-gate@example.invalid',
        ]);

        $login = $this->postJson('/api/auth/elderly/login', [
            'E_PhonNumber' => '770014001',
            'E_Password' => 'Secret123!',
        ]);

        $login->assertOk()
            ->assertJsonPath('status', 'success');
        $this->assertNotEmpty($login->json('token'));
        $this->assertSame(
            (int) $register->json('elderly.Eldery_ID'),
            (int) $login->json('elderly.Eldery_ID')
        );
    }

    public function test_elderly_login_rejects_wrong_password(): void
    {
        $this->postJson('/api/auth/elderly/register', [
            'E_Name' => 'كبير تجريبي',
            'E_PhonNumber' => '770014002',
            'E_Email' => 'elderly-p14-bad@example.invalid',
            'E_Password' => 'Secret123!',
            'E_sex' => 'أنثى',
        ])->assertJsonPath('status', 'success');

        $login = $this->postJson('/api/auth/elderly/login', [
            'E_PhonNumber' => '770014002',
            'E_Password' => 'WrongPass!',
        ]);

        $login->assertOk()
            ->assertJsonPath('status', 'error');
        $this->assertNull($login->json('token'));
        $this->assertSame(1, Elderly::count());
    }
}
