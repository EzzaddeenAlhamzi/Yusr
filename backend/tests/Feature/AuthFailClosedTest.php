<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/**
 * P1.1 synthetic auth tests — isolated sqlite; no live lab / no dump.
 */
class AuthFailClosedTest extends TestCase
{
    use RefreshDatabase;

    public function test_caregiver_register_rejects_empty_password(): void
    {
        $response = $this->postJson('/api/auth/caregiver/register', [
            'C_Name' => 'Test Caregiver',
            'C_PhonNumber' => '770000001',
            'C_Password' => '',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'password_required',
            ]);

        $this->assertDatabaseCount('caregivers', 0);
    }

    public function test_elderly_register_rejects_empty_password(): void
    {
        $response = $this->postJson('/api/auth/elderly/register', [
            'E_Name' => 'Test Elderly',
            'E_PhonNumber' => '770000002',
            'E_Password' => '',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'password_required',
            ]);

        $this->assertDatabaseCount('elderly', 0);
    }

    public function test_caregiver_login_rejects_empty_db_password(): void
    {
        Caregiver::create([
            'C_Name' => 'Empty Pass',
            'C_PhonNumber' => '770000003',
            'C_Email' => 'empty@example.invalid',
            'C_Password' => null,
        ]);

        $response = $this->postJson('/api/auth/caregiver/login', [
            'C_PhonNumber' => '770000003',
            'C_Password' => 'anything',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'wrong_password',
            ]);
        $this->assertNull($response->json('token'));
    }

    public function test_caregiver_login_rejects_empty_request_password(): void
    {
        Caregiver::create([
            'C_Name' => 'Hashed',
            'C_PhonNumber' => '770000004',
            'C_Password' => Hash::make('secret123'),
        ]);

        $response = $this->postJson('/api/auth/caregiver/login', [
            'C_PhonNumber' => '770000004',
            'C_Password' => '',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'wrong_password',
            ]);
    }

    public function test_caregiver_login_rejects_plaintext_legacy_password(): void
    {
        Caregiver::create([
            'C_Name' => 'Legacy',
            'C_PhonNumber' => '770000005',
            'C_Password' => 'plaintext-secret',
        ]);

        $response = $this->postJson('/api/auth/caregiver/login', [
            'C_PhonNumber' => '770000005',
            'C_Password' => 'plaintext-secret',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'password_reset_required',
            ]);
        $this->assertNull($response->json('token'));

        // Must not silently upgrade on login.
        $this->assertSame(
            'plaintext-secret',
            Caregiver::where('C_PhonNumber', '770000005')->value('C_Password')
        );
    }

    public function test_elderly_login_rejects_plaintext_legacy_password(): void
    {
        Elderly::create([
            'E_Name' => 'Legacy Elder',
            'E_PhonNumber' => '770000006',
            'E_Password' => 'legacy-pass',
        ]);

        $response = $this->postJson('/api/auth/elderly/login', [
            'E_PhonNumber' => '770000006',
            'E_Password' => 'legacy-pass',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'password_reset_required',
            ]);
    }

    public function test_caregiver_login_bcrypt_ok_persists_sanctum_token(): void
    {
        Caregiver::create([
            'C_Name' => 'Ok Caregiver',
            'C_PhonNumber' => '770000007',
            'C_Email' => 'okc@example.invalid',
            'C_Password' => Hash::make('GoodPass1'),
        ]);

        $response = $this->postJson('/api/auth/caregiver/login', [
            'C_PhonNumber' => '770000007',
            'C_Password' => 'GoodPass1',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'role' => 'caregiver',
            ]);

        $token = $response->json('token');
        $this->assertIsString($token);
        $this->assertNotEmpty($token);
        $this->assertGreaterThan(0, PersonalAccessToken::count());
        $this->assertArrayNotHasKey('C_Password', $response->json('caregiver') ?? []);
    }

    public function test_elderly_register_hashes_and_issues_persisted_token(): void
    {
        $response = $this->postJson('/api/auth/elderly/register', [
            'E_Name' => 'New Elder',
            'E_PhonNumber' => '770000008',
            'E_Email' => 'elder@example.invalid',
            'E_Password' => 'ElderPass1',
            'E_sex' => 'ذكر',
        ]);

        $response->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $stored = Elderly::where('E_PhonNumber', '770000008')->value('E_Password');
        $this->assertNotSame('ElderPass1', $stored);
        $this->assertTrue(Hash::check('ElderPass1', $stored));
        $this->assertGreaterThan(0, PersonalAccessToken::count());
        $this->assertArrayNotHasKey('E_Password', $response->json('elderly') ?? []);
    }

    public function test_sanctum_create_failure_fail_closed_no_orphan_token(): void
    {
        Caregiver::create([
            'C_Name' => 'Token Fail',
            'C_PhonNumber' => '770000009',
            'C_Password' => Hash::make('GoodPass1'),
        ]);

        Schema::drop('personal_access_tokens');

        $response = $this->postJson('/api/auth/caregiver/login', [
            'C_PhonNumber' => '770000009',
            'C_Password' => 'GoodPass1',
        ]);

        $response->assertStatus(503)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'token_issue_failed',
            ]);
        $this->assertNull($response->json('token'));
    }

    public function test_legacy_bridge_login_caregiver_same_contract(): void
    {
        Caregiver::create([
            'C_Name' => 'Bridge',
            'C_PhonNumber' => '770000010',
            'C_Password' => Hash::make('BridgePass1'),
        ]);

        $response = $this->postJson('/api/legacy', [
            'action' => 'login_caregiver',
            'C_PhonNumber' => '770000010',
            'C_Password' => 'BridgePass1',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'role' => 'caregiver',
            ]);
        $this->assertNotEmpty($response->json('token'));
    }

    public function test_legacy_bridge_rejects_plaintext_login(): void
    {
        Elderly::create([
            'E_Name' => 'Bridge Elder',
            'E_PhonNumber' => '770000011',
            'E_Password' => 'not-hashed',
        ]);

        $response = $this->postJson('/api/legacy', [
            'action' => 'login_elderly',
            'E_PhonNumber' => '770000011',
            'E_Password' => 'not-hashed',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'password_reset_required',
            ]);
    }
}
