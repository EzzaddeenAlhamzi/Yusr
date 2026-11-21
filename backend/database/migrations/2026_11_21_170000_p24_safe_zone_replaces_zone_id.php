<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * P2.4 map-gate — material CG edit keeps approved geometry active.
 * Additive: pending proposal rows may point at the zone they would replace.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('safe_zones')) {
            return;
        }
        if (! Schema::hasColumn('safe_zones', 'replaces_zone_id')) {
            Schema::table('safe_zones', function (Blueprint $table) {
                $table->integer('replaces_zone_id')->nullable()->after('Zldery_ID');
                $table->index('replaces_zone_id');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('safe_zones') && Schema::hasColumn('safe_zones', 'replaces_zone_id')) {
            Schema::table('safe_zones', function (Blueprint $table) {
                $table->dropIndex(['replaces_zone_id']);
                $table->dropColumn('replaces_zone_id');
            });
        }
    }
};
