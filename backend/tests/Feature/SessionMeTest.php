<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/**
 * P1.3 — /auth/me session validation + logout honesty.
 */
class SessionMeTest extends TestCase
{
    use RefreshDatabase;

    private function makeElderly(string $phone = '771999001'): Elderly
    {
        return Elderly::create([
            'E_Name' => 'Elder Me',
            'E_PhonNumber' => $phone,
            'E_Email' => $phone . '@example.invalid',
            'E_Password' => Hash::make('ElderPass1'),
            'E_sex' => 'ذكر',
        ]);
    }

    private function makeCaregiver(string $phone = '772999001', ?int $elderlyId = null): Caregiver
    {
        return Caregiver::create([
            'C_Name' => 'Care Me',
            'C_PhonNumber' => $phone,
            'C_Email' => $phone . '@example.invalid',
            'C_Password' => Hash::make('CarePass1'),
            'C_Relationship' => 'ابن',
            'Eldery_ID' => $elderlyId,
        ]);
    }

    private function tokenFor($user): string
    {
        return $user->createToken('test')->plainTextToken;
    }

    public function test_me_requires_authentication(): void
    {
        $this->getJson('/api/auth/me')
            ->assertStatus(401)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'unauthenticated',
            ]);
    }

    public function test_me_returns_caregiver_profile(): void
    {
        $e = $this->makeElderly();
        $cg = $this->makeCaregiver('772999002', $e->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->getJson('/api/auth/me')
            ->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'role' => 'caregiver',
                'caregiver' => [
                    'Caregivers_ID' => $cg->Caregivers_ID,
                    'C_PhonNumber' => $cg->C_PhonNumber,
                    'Eldery_ID' => $e->Eldery_ID,
                ],
            ])
            ->assertJsonMissingPath('caregiver.C_Password');
    }

    public function test_me_returns_elderly_profile(): void
    {
        $e = $this->makeElderly('771999003');

        $this->withToken($this->tokenFor($e))
            ->postJson('/api/auth/me')
            ->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'role' => 'elderly',
                'elderly' => [
                    'Eldery_ID' => $e->Eldery_ID,
                    'E_PhonNumber' => $e->E_PhonNumber,
                ],
            ])
            ->assertJsonMissingPath('elderly.E_Password');
    }

    public function test_legacy_me_action_works(): void
    {
        $e = $this->makeElderly('771999004');

        $this->withToken($this->tokenFor($e))
            ->postJson('/api/legacy', ['action' => 'me'])
            ->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'role' => 'elderly',
            ]);
    }

    public function test_me_rejects_revoked_token(): void
    {
        $e = $this->makeElderly('771999005');
        $token = $this->tokenFor($e);

        $this->withToken($token)
            ->postJson('/api/auth/logout')
            ->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $this->assertSame(0, PersonalAccessToken::count());

        $this->app['auth']->forgetGuards();
        $this->flushHeaders();

        $this->withToken($token)
            ->getJson('/api/auth/me')
            ->assertStatus(401)
            ->assertJson(['error_type' => 'unauthenticated']);
    }

    public function test_register_responses_include_role(): void
    {
        $this->postJson('/api/auth/caregiver/register', [
            'C_Name' => 'Reg Care',
            'C_PhonNumber' => '772999090',
            'C_Password' => 'CarePass1',
            'C_Email' => 'regcare@example.invalid',
        ])
            ->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'role' => 'caregiver',
            ]);

        $this->postJson('/api/auth/elderly/register', [
            'E_Name' => 'Reg Elder',
            'E_PhonNumber' => '771999090',
            'E_Password' => 'ElderPass1',
            'E_Email' => 'regelder@example.invalid',
            'E_sex' => 'أنثى',
        ])
            ->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'role' => 'elderly',
            ]);
    }
}
