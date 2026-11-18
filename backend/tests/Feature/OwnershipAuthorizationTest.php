<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\Medication;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/**
 * P1.2 — object ownership isolation (REST + legacy). Synthetic sqlite only.
 */
class OwnershipAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    private function makeElderly(string $phone, string $name = 'Elder'): Elderly
    {
        return Elderly::create([
            'E_Name' => $name,
            'E_PhonNumber' => $phone,
            'E_Email' => $phone . '@example.invalid',
            'E_Password' => Hash::make('ElderPass1'),
            'E_sex' => 'ذكر',
        ]);
    }

    private function makeCaregiver(string $phone, ?int $elderlyId = null, string $name = 'Caregiver'): Caregiver
    {
        return Caregiver::create([
            'C_Name' => $name,
            'C_PhonNumber' => $phone,
            'C_Email' => $phone . '@example.invalid',
            'C_Password' => Hash::make('CarePass1'),
            'C_Relationship' => 'ابن',
            'Eldery_ID' => $elderlyId,
        ]);
    }

    private function tokenFor($user, string $name = 'test'): string
    {
        return $user->createToken($name)->plainTextToken;
    }

    public function test_unauthenticated_rest_medications_rejected(): void
    {
        $this->getJson('/api/medications')
            ->assertStatus(401)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'unauthenticated',
            ]);
    }

    public function test_unauthenticated_legacy_get_medications_rejected(): void
    {
        $this->postJson('/api/legacy', ['action' => 'get_medications'])
            ->assertStatus(401)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'unauthenticated',
            ]);
    }

    public function test_legacy_ping_remains_public(): void
    {
        $this->postJson('/api/legacy', ['action' => 'ping'])
            ->assertStatus(200)
            ->assertJson(['status' => 'success']);
    }

    public function test_caregiver_cannot_read_unlinked_elderly_profile(): void
    {
        $e1 = $this->makeElderly('771000001', 'E1');
        $e2 = $this->makeElderly('771000002', 'E2');
        $cg = $this->makeCaregiver('772000001', $e1->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->getJson('/api/elderly/' . $e2->Eldery_ID)
            ->assertStatus(403)
            ->assertJson(['error_type' => 'forbidden']);
    }

    public function test_caregiver_can_read_linked_elderly_profile(): void
    {
        $e1 = $this->makeElderly('771000003', 'E1');
        $cg = $this->makeCaregiver('772000002', $e1->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->getJson('/api/elderly/' . $e1->Eldery_ID)
            ->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'data' => ['Eldery_ID' => $e1->Eldery_ID],
            ]);
    }

    public function test_cross_caregiver_medication_idor_rejected(): void
    {
        $e1 = $this->makeElderly('771000004', 'E1');
        $e2 = $this->makeElderly('771000005', 'E2');
        $cg1 = $this->makeCaregiver('772000003', $e1->Eldery_ID, 'CG1');
        $cg2 = $this->makeCaregiver('772000004', $e2->Eldery_ID, 'CG2');

        $med = Medication::create([
            'M_Name' => 'Aspirin',
            'M_much' => '1',
            'M_RepatTime' => 'يومياً',
            'Elderly_ID' => $e1->Eldery_ID,
        ]);

        $this->withToken($this->tokenFor($cg2))
            ->getJson('/api/medications?Elderly_ID=' . $e1->Eldery_ID)
            ->assertStatus(403);

        $this->withToken($this->tokenFor($cg2))
            ->postJson('/api/medications/' . $med->Medicayion_ID . '/delete', [
                'Medicayion_ID' => $med->Medicayion_ID,
            ])
            ->assertStatus(403);

        $this->assertDatabaseHas('medications', ['Medicayion_ID' => $med->Medicayion_ID]);
    }

    public function test_cross_elderly_cannot_read_other_elderly_health(): void
    {
        $e1 = $this->makeElderly('771000006', 'E1');
        $e2 = $this->makeElderly('771000007', 'E2');

        $this->withToken($this->tokenFor($e1))
            ->getJson('/api/health/records?Elderly_ID=' . $e2->Eldery_ID)
            ->assertStatus(403)
            ->assertJson(['error_type' => 'forbidden']);
    }

    public function test_elderly_token_cannot_update_caregiver_profile(): void
    {
        $e1 = $this->makeElderly('771000008', 'E1');
        $cg = $this->makeCaregiver('772000005', $e1->Eldery_ID);

        $this->withToken($this->tokenFor($e1))
            ->postJson('/api/caregiver/' . $cg->Caregivers_ID, [
                'Caregivers_ID' => $cg->Caregivers_ID,
                'C_Name' => 'Hacked',
            ])
            ->assertStatus(403);
    }

    public function test_caregiver_cannot_link_other_caregiver_id(): void
    {
        $e1 = $this->makeElderly('771000009', 'E1');
        $cg1 = $this->makeCaregiver('772000006', null, 'CG1');
        $cg2 = $this->makeCaregiver('772000007', null, 'CG2');

        $this->withToken($this->tokenFor($cg1))
            ->postJson('/api/elderly/link', [
                'Caregivers_ID' => $cg2->Caregivers_ID,
                'Eldery_ID' => $e1->Eldery_ID,
            ])
            ->assertStatus(403);

        $this->assertNull(Caregiver::find($cg2->Caregivers_ID)->Eldery_ID);
    }

    public function test_caregiver_can_link_self_to_elderly(): void
    {
        $e1 = $this->makeElderly('771000010', 'E1');
        $cg1 = $this->makeCaregiver('772000008', null, 'CG1');

        $this->withToken($this->tokenFor($cg1))
            ->postJson('/api/elderly/link', [
                'Caregivers_ID' => $cg1->Caregivers_ID,
                'Eldery_ID' => $e1->Eldery_ID,
            ])
            ->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $this->assertSame($e1->Eldery_ID, (int) Caregiver::find($cg1->Caregivers_ID)->Eldery_ID);
    }

    public function test_elderly_token_cannot_perform_link(): void
    {
        $e1 = $this->makeElderly('771000011', 'E1');
        $cg1 = $this->makeCaregiver('772000009', null);

        $this->withToken($this->tokenFor($e1))
            ->postJson('/api/elderly/link', [
                'Caregivers_ID' => $cg1->Caregivers_ID,
                'Eldery_ID' => $e1->Eldery_ID,
            ])
            ->assertStatus(403);
    }

    public function test_revoked_token_rejected(): void
    {
        $e1 = $this->makeElderly('771000012', 'E1');
        $token = $this->tokenFor($e1);

        $this->withToken($token)
            ->postJson('/api/auth/logout')
            ->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $this->assertSame(0, PersonalAccessToken::count());

        // Flush guard state between requests (Laravel test client can retain auth).
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();

        $this->withToken($token)
            ->getJson('/api/elderly/' . $e1->Eldery_ID)
            ->assertStatus(401)
            ->assertJson(['error_type' => 'unauthenticated']);
    }

    public function test_legacy_bridge_enforces_same_ownership(): void
    {
        $e1 = $this->makeElderly('771000013', 'E1');
        $e2 = $this->makeElderly('771000014', 'E2');
        $cg = $this->makeCaregiver('772000010', $e1->Eldery_ID);

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/legacy', [
                'action' => 'get_elderly',
                'Eldery_ID' => $e2->Eldery_ID,
            ])
            ->assertStatus(403)
            ->assertJson(['error_type' => 'forbidden']);
    }

    public function test_web_legacy_alias_requires_auth_for_private_action(): void
    {
        $this->postJson('/', ['action' => 'get_medications'])
            ->assertStatus(401);
    }

    public function test_list_medications_never_dumps_other_elderly(): void
    {
        $e1 = $this->makeElderly('771000015', 'E1');
        $e2 = $this->makeElderly('771000016', 'E2');
        $cg = $this->makeCaregiver('772000011', $e1->Eldery_ID);

        Medication::create([
            'M_Name' => 'Mine',
            'M_much' => '1',
            'M_RepatTime' => 'x',
            'Elderly_ID' => $e1->Eldery_ID,
        ]);
        Medication::create([
            'M_Name' => 'Theirs',
            'M_much' => '1',
            'M_RepatTime' => 'x',
            'Elderly_ID' => $e2->Eldery_ID,
        ]);

        $res = $this->withToken($this->tokenFor($cg))
            ->getJson('/api/medications')
            ->assertStatus(200)
            ->json('data');

        $names = collect($res)->pluck('M_Name')->all();
        $this->assertContains('Mine', $names);
        $this->assertNotContains('Theirs', $names);
    }

    public function test_responses_do_not_leak_password_fields(): void
    {
        $e1 = $this->makeElderly('771000017', 'E1');
        $cg = $this->makeCaregiver('772000012', $e1->Eldery_ID);

        $payload = $this->withToken($this->tokenFor($cg))
            ->getJson('/api/caregiver/' . $cg->Caregivers_ID)
            ->assertStatus(200)
            ->json('data');

        $this->assertArrayNotHasKey('C_Password', $payload);
    }
}
