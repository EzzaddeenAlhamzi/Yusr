<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * P2.4-A — additive: elderly sharing consent + GPS accuracy meters.
 * Safe additive only; no destructive schema changes.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('elderly') && ! Schema::hasColumn('elderly', 'location_sharing_enabled')) {
            Schema::table('elderly', function (Blueprint $table) {
                $table->boolean('location_sharing_enabled')->default(false)->after('E_Password');
            });
        }

        if (Schema::hasTable('location_tracking') && ! Schema::hasColumn('location_tracking', 'L_AccuracyMeters')) {
            Schema::table('location_tracking', function (Blueprint $table) {
                $table->decimal('L_AccuracyMeters', 10, 2)->nullable()->after('L_Scor');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('location_tracking') && Schema::hasColumn('location_tracking', 'L_AccuracyMeters')) {
            Schema::table('location_tracking', function (Blueprint $table) {
                $table->dropColumn('L_AccuracyMeters');
            });
        }

        if (Schema::hasTable('elderly') && Schema::hasColumn('elderly', 'location_sharing_enabled')) {
            Schema::table('elderly', function (Blueprint $table) {
                $table->dropColumn('location_sharing_enabled');
            });
        }
    }
};
