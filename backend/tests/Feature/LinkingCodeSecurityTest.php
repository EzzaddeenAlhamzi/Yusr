<?php

namespace Tests\Feature;

use App\Models\Caregiver;
use App\Models\Elderly;
use App\Models\ElderlyLinkingCode;
use App\Models\LinkingCodeAttempt;
use App\Support\LinkingCodeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * P1.2 security completion — hashed linking codes, direct-ID block, rate limits.
 */
class LinkingCodeSecurityTest extends TestCase
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

    private function issueCode(Elderly $elderly): string
    {
        $result = LinkingCodeService::generateForElderly($elderly);
        $this->assertIsArray($result);

        return $result['code'];
    }

    public function test_elderly_can_generate_linking_code(): void
    {
        $e1 = $this->makeElderly('771100001', 'E1');

        $res = $this->withToken($this->tokenFor($e1))
            ->postJson('/api/elderly/linking-code')
            ->assertStatus(200)
            ->assertJson(['status' => 'success'])
            ->json('data');

        $this->assertMatchesRegularExpression('/^\d{6}$/', $res['linking_code']);
        $this->assertSame(600, $res['expires_in_seconds']);
        $this->assertDatabaseCount('elderly_linking_codes', 1);
        $row = ElderlyLinkingCode::first();
        $this->assertSame(LinkingCodeService::hashCode($res['linking_code']), $row->code_hash);
        $this->assertNull($row->consumed_at);
    }

    public function test_unauthenticated_generate_rejected(): void
    {
        $this->postJson('/api/elderly/linking-code')
            ->assertStatus(401)
            ->assertJson(['error_type' => 'unauthenticated']);
    }

    public function test_caregiver_cannot_generate_linking_code(): void
    {
        $cg = $this->makeCaregiver('772100001');

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/elderly/linking-code')
            ->assertStatus(403);
    }

    public function test_generate_ignores_client_supplied_elderly_id(): void
    {
        $e1 = $this->makeElderly('771100002', 'E1');
        $e2 = $this->makeElderly('771100003', 'E2');

        $this->withToken($this->tokenFor($e1))
            ->postJson('/api/elderly/linking-code', ['Eldery_ID' => $e2->Eldery_ID])
            ->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $this->assertSame(
            $e1->Eldery_ID,
            (int) ElderlyLinkingCode::first()->Eldery_ID
        );
    }

    public function test_new_code_invalidates_prior_active_code(): void
    {
        $e1 = $this->makeElderly('771100004', 'E1');
        $first = $this->issueCode($e1);
        $second = $this->issueCode($e1);

        $this->assertNotSame($first, $second);
        $this->assertDatabaseCount('elderly_linking_codes', 2);
        $this->assertSame(1, ElderlyLinkingCode::whereNull('consumed_at')->count());
        $this->assertSame(
            LinkingCodeService::hashCode($second),
            ElderlyLinkingCode::whereNull('consumed_at')->value('code_hash')
        );
    }

    public function test_valid_code_links_caregiver(): void
    {
        $e1 = $this->makeElderly('771100005', 'E1');
        $cg = $this->makeCaregiver('772100002', null, 'CG1');
        $code = $this->issueCode($e1);

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/elderly/link', ['linking_code' => $code])
            ->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $this->assertSame($e1->Eldery_ID, (int) Caregiver::find($cg->Caregivers_ID)->Eldery_ID);
        $this->assertNotNull(ElderlyLinkingCode::first()->consumed_at);
    }

    public function test_direct_elderly_id_link_bypass_blocked_rest(): void
    {
        $e1 = $this->makeElderly('771100006', 'E1');
        $cg = $this->makeCaregiver('772100003');

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/elderly/link', [
                'Caregivers_ID' => $cg->Caregivers_ID,
                'Eldery_ID' => $e1->Eldery_ID,
            ])
            ->assertStatus(403)
            ->assertJson(['error_type' => 'forbidden']);

        $this->assertNull(Caregiver::find($cg->Caregivers_ID)->Eldery_ID);
    }

    public function test_direct_elderly_id_link_bypass_blocked_legacy(): void
    {
        $e1 = $this->makeElderly('771100007', 'E1');
        $cg = $this->makeCaregiver('772100004');

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/legacy', [
                'action' => 'link_elderly',
                'Caregivers_ID' => $cg->Caregivers_ID,
                'Eldery_ID' => $e1->Eldery_ID,
            ])
            ->assertStatus(403);

        $this->assertNull(Caregiver::find($cg->Caregivers_ID)->Eldery_ID);
    }

    public function test_legacy_generate_and_link_parity(): void
    {
        $e1 = $this->makeElderly('771100008', 'E1');
        $cg = $this->makeCaregiver('772100005');

        $code = $this->withToken($this->tokenFor($e1))
            ->postJson('/api/legacy', ['action' => 'generate_linking_code'])
            ->assertStatus(200)
            ->assertJson(['status' => 'success'])
            ->json('data.linking_code');

        // Flush Sanctum/guard state when switching actors in the same test client.
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/legacy', [
                'action' => 'link_elderly',
                'linking_code' => $code,
            ])
            ->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $this->assertSame($e1->Eldery_ID, (int) Caregiver::find($cg->Caregivers_ID)->Eldery_ID);
    }

    public function test_wrong_code_rejected_without_linking(): void
    {
        $e1 = $this->makeElderly('771100009', 'E1');
        $cg = $this->makeCaregiver('772100006');
        $this->issueCode($e1);

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/elderly/link', ['linking_code' => '000000'])
            ->assertStatus(200)
            ->assertJson([
                'status' => 'error',
                'error_type' => 'validation_error',
            ]);

        $this->assertNull(Caregiver::find($cg->Caregivers_ID)->Eldery_ID);
        $this->assertSame(1, LinkingCodeAttempt::count());
    }

    public function test_expired_code_rejected(): void
    {
        $e1 = $this->makeElderly('771100010', 'E1');
        $cg = $this->makeCaregiver('772100007');
        $code = $this->issueCode($e1);

        ElderlyLinkingCode::query()->update([
            'expires_at' => now()->subMinute(),
        ]);

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/elderly/link', ['linking_code' => $code])
            ->assertJson(['status' => 'error']);

        $this->assertNull(Caregiver::find($cg->Caregivers_ID)->Eldery_ID);
    }

    public function test_consumed_code_cannot_be_reused(): void
    {
        $e1 = $this->makeElderly('771100011', 'E1');
        $cg1 = $this->makeCaregiver('772100008', null, 'CG1');
        $cg2 = $this->makeCaregiver('772100009', null, 'CG2');
        $code = $this->issueCode($e1);

        $this->withToken($this->tokenFor($cg1))
            ->postJson('/api/elderly/link', ['linking_code' => $code])
            ->assertJson(['status' => 'success']);

        $this->withToken($this->tokenFor($cg2))
            ->postJson('/api/elderly/link', ['linking_code' => $code])
            ->assertJson(['status' => 'error']);

        $this->assertNull(Caregiver::find($cg2->Caregivers_ID)->Eldery_ID);
    }

    public function test_concurrent_reuse_only_one_succeeds(): void
    {
        $e1 = $this->makeElderly('771100012', 'E1');
        $cg1 = $this->makeCaregiver('772100010', null, 'CG1');
        $cg2 = $this->makeCaregiver('772100011', null, 'CG2');
        $code = $this->issueCode($e1);
        $hash = LinkingCodeService::hashCode($code);

        $outcomes = [];
        DB::transaction(function () use ($cg1, $hash, &$outcomes) {
            $row = ElderlyLinkingCode::query()
                ->where('code_hash', $hash)
                ->whereNull('consumed_at')
                ->lockForUpdate()
                ->first();
            $this->assertNotNull($row);
            $updated = ElderlyLinkingCode::query()
                ->where('id', $row->id)
                ->whereNull('consumed_at')
                ->update(['consumed_at' => now()]);
            $outcomes[] = $updated;
            if ($updated === 1) {
                $cg1->update(['Eldery_ID' => $row->Eldery_ID]);
            }
        });

        $updated2 = ElderlyLinkingCode::query()
            ->where('code_hash', $hash)
            ->whereNull('consumed_at')
            ->update(['consumed_at' => now()]);
        $outcomes[] = $updated2;

        $this->assertSame([1, 0], $outcomes);
        $this->assertSame($e1->Eldery_ID, (int) Caregiver::find($cg1->Caregivers_ID)->Eldery_ID);
        $this->assertNull(Caregiver::find($cg2->Caregivers_ID)->Eldery_ID);
    }

    public function test_rate_limit_after_five_failed_attempts(): void
    {
        $e1 = $this->makeElderly('771100013', 'E1');
        $cg = $this->makeCaregiver('772100012');
        $this->issueCode($e1);
        $token = $this->tokenFor($cg);

        for ($i = 0; $i < 5; $i++) {
            $this->withToken($token)
                ->postJson('/api/elderly/link', ['linking_code' => '99999' . $i])
                ->assertJson(['status' => 'error']);
        }

        $this->withToken($token)
            ->postJson('/api/elderly/link', ['linking_code' => '123456'])
            ->assertStatus(429)
            ->assertJson(['error_type' => 'rate_limited']);

        $this->assertNull(Caregiver::find($cg->Caregivers_ID)->Eldery_ID);
    }

    public function test_elderly_token_cannot_perform_link(): void
    {
        $e1 = $this->makeElderly('771100014', 'E1');
        $code = $this->issueCode($e1);

        $this->withToken($this->tokenFor($e1))
            ->postJson('/api/elderly/link', ['linking_code' => $code])
            ->assertStatus(403);
    }

    public function test_spoof_other_caregiver_id_rejected(): void
    {
        $e1 = $this->makeElderly('771100015', 'E1');
        $cg1 = $this->makeCaregiver('772100013', null, 'CG1');
        $cg2 = $this->makeCaregiver('772100014', null, 'CG2');
        $code = $this->issueCode($e1);

        $this->withToken($this->tokenFor($cg1))
            ->postJson('/api/elderly/link', [
                'Caregivers_ID' => $cg2->Caregivers_ID,
                'linking_code' => $code,
            ])
            ->assertStatus(403);

        $this->assertNull(Caregiver::find($cg2->Caregivers_ID)->Eldery_ID);
    }

    public function test_caregiver_isolation_after_link(): void
    {
        $e1 = $this->makeElderly('771100016', 'E1');
        $e2 = $this->makeElderly('771100017', 'E2');
        $cg = $this->makeCaregiver('772100015');
        $code = $this->issueCode($e1);

        $this->withToken($this->tokenFor($cg))
            ->postJson('/api/elderly/link', ['linking_code' => $code])
            ->assertJson(['status' => 'success']);

        $this->withToken($this->tokenFor($cg))
            ->getJson('/api/elderly/' . $e1->Eldery_ID)
            ->assertStatus(200);

        $this->withToken($this->tokenFor($cg))
            ->getJson('/api/elderly/' . $e2->Eldery_ID)
            ->assertStatus(403);
    }
}
