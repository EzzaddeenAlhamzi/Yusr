<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * P2.4-B — additive safe-zone center/radius/approval + presence state table.
 * Does not drop existing safe_zones columns; Location_ID remains optional legacy.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('safe_zones')) {
            Schema::table('safe_zones', function (Blueprint $table) {
                if (! Schema::hasColumn('safe_zones', 'center_lat')) {
                    $table->decimal('center_lat', 10, 8)->nullable()->after('Z_Limit');
                }
                if (! Schema::hasColumn('safe_zones', 'center_lng')) {
                    $table->decimal('center_lng', 11, 8)->nullable()->after('center_lat');
                }
                if (! Schema::hasColumn('safe_zones', 'radius_meters')) {
                    $table->integer('radius_meters')->nullable()->after('center_lng');
                }
                if (! Schema::hasColumn('safe_zones', 'approval_status')) {
                    $table->string('approval_status', 32)->nullable()->after('radius_meters');
                }
                if (! Schema::hasColumn('safe_zones', 'created_by_role')) {
                    $table->string('created_by_role', 32)->nullable()->after('approval_status');
                }
                if (! Schema::hasColumn('safe_zones', 'created_by_caregiver_id')) {
                    $table->integer('created_by_caregiver_id')->nullable()->after('created_by_role');
                }
                if (! Schema::hasColumn('safe_zones', 'activated_at')) {
                    $table->dateTime('activated_at')->nullable()->after('created_by_caregiver_id');
                }
                if (! Schema::hasColumn('safe_zones', 'created_at')) {
                    $table->dateTime('created_at')->nullable()->after('activated_at');
                }
                if (! Schema::hasColumn('safe_zones', 'updated_at')) {
                    $table->dateTime('updated_at')->nullable()->after('created_at');
                }
            });
        }

        if (! Schema::hasTable('zone_presence_states')) {
            Schema::create('zone_presence_states', function (Blueprint $table) {
                $table->integer('Presence_ID');
                $table->integer('Elderly_ID');
                $table->integer('Zone_ID');
                $table->string('state', 32)->nullable(); // UNKNOWN|INSIDE|OUTSIDE|BOUNDARY_UNCERTAIN
                $table->string('last_event', 32)->nullable(); // ENTER|EXIT|null
                $table->dateTime('last_transition_at')->nullable();
                $table->dateTime('updated_at')->nullable();
                $table->primary('Presence_ID');
                $table->unique(['Elderly_ID', 'Zone_ID'], 'zone_presence_elderly_zone_unique');
                $table->index('Zone_ID');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('zone_presence_states');

        if (Schema::hasTable('safe_zones')) {
            Schema::table('safe_zones', function (Blueprint $table) {
                $drops = [];
                foreach ([
                    'updated_at',
                    'created_at',
                    'activated_at',
                    'created_by_caregiver_id',
                    'created_by_role',
                    'approval_status',
                    'radius_meters',
                    'center_lng',
                    'center_lat',
                ] as $col) {
                    if (Schema::hasColumn('safe_zones', $col)) {
                        $drops[] = $col;
                    }
                }
                if ($drops !== []) {
                    $table->dropColumn($drops);
                }
            });
        }
    }
};
