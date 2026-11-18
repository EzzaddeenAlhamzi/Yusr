<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * P1.2 security completion — temporary hashed elderly↔caregiver linking codes.
 * Additive only. EMA runs migrate later; design must be reviewable in PR.
 *
 * Stores HMAC hash only (never plaintext). 10-minute expiry; single-use via consumed_at.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('elderly_linking_codes', function (Blueprint $table) {
            $table->id();
            $table->integer('Eldery_ID');
            $table->string('code_hash', 64);
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index('Eldery_ID');
            $table->index('code_hash');
            $table->index(['consumed_at', 'expires_at']);

            $table->foreign('Eldery_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        // Failed guess log for lab rate-limit / audit (caregiver + optional IP).
        Schema::create('linking_code_attempts', function (Blueprint $table) {
            $table->id();
            $table->integer('Caregivers_ID');
            $table->string('ip_address', 45)->nullable();
            $table->timestamp('attempted_at')->useCurrent();

            $table->index(['Caregivers_ID', 'attempted_at']);
            $table->index(['ip_address', 'attempted_at']);

            $table->foreign('Caregivers_ID')
                ->references('Caregivers_ID')->on('caregivers')
                ->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('linking_code_attempts');
        Schema::dropIfExists('elderly_linking_codes');
    }
};
