<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * P2.3 — additive notification columns for idempotent caregiver overdue alerts.
 * Does not wipe or recreate the notifications table.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('notifications')) {
            return;
        }

        Schema::table('notifications', function (Blueprint $table) {
            if (! Schema::hasColumn('notifications', 'event_type')) {
                $table->string('event_type', 64)->nullable()->after('N_Type');
            }
            if (! Schema::hasColumn('notifications', 'occurrence_key')) {
                $table->string('occurrence_key', 64)->nullable()->after('event_type');
            }
            if (! Schema::hasColumn('notifications', 'DoseOccurrence_ID')) {
                $table->integer('DoseOccurrence_ID')->nullable()->after('occurrence_key');
            }
        });

        // Unique idempotency for Channel B (nullable legacy rows allowed to coexist).
        try {
            Schema::table('notifications', function (Blueprint $table) {
                $table->unique(
                    ['Caregiver_ID', 'event_type', 'occurrence_key'],
                    'notif_cg_event_occ_unique'
                );
            });
        } catch (\Throwable $e) {
            // Index may already exist on re-run.
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('notifications')) {
            return;
        }

        try {
            Schema::table('notifications', function (Blueprint $table) {
                $table->dropUnique('notif_cg_event_occ_unique');
            });
        } catch (\Throwable $e) {
            // ignore
        }

        Schema::table('notifications', function (Blueprint $table) {
            $drops = [];
            foreach (['DoseOccurrence_ID', 'occurrence_key', 'event_type'] as $col) {
                if (Schema::hasColumn('notifications', $col)) {
                    $drops[] = $col;
                }
            }
            if ($drops !== []) {
                $table->dropColumn($drops);
            }
        });
    }
};
