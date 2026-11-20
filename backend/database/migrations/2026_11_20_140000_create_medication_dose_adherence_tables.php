<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * P2.2 — additive dose occurrence + event history (Rule D).
 * Does not alter medications catalog rows or wipe local prefs.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('medication_dose_occurrences', function (Blueprint $table) {
            $table->integer('DoseOccurrence_ID');
            $table->string('occurrence_key', 64);
            $table->integer('Medicayion_ID');
            $table->integer('Elderly_ID');
            $table->date('scheduled_date');
            $table->time('scheduled_time');
            $table->string('slot', 32)->default('default');
            $table->string('schedule_text_snapshot', 100)->nullable();
            // Persisted adherence only: unconfirmed | taken | late_confirmed
            $table->string('adherence_state', 32)->default('unconfirmed');
            $table->dateTime('confirmed_at')->nullable();
            $table->string('confirmed_by_type', 32)->nullable();
            $table->integer('confirmed_by_id')->nullable();
            $table->string('client_confirm_id', 64)->nullable();
            $table->timestamps();

            $table->primary('DoseOccurrence_ID');
            $table->unique(
                ['Medicayion_ID', 'occurrence_key'],
                'med_dose_occ_med_key_unique'
            );
            $table->unique('client_confirm_id', 'med_dose_occ_client_confirm_unique');
            $table->index(['Elderly_ID', 'scheduled_date'], 'med_dose_occ_elderly_date_idx');
            $table->index('Medicayion_ID', 'med_dose_occ_med_idx');

            $table->foreign('Medicayion_ID')
                ->references('Medicayion_ID')->on('medications')
                ->onDelete('cascade');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('medication_dose_events', function (Blueprint $table) {
            $table->integer('DoseEvent_ID');
            $table->integer('DoseOccurrence_ID');
            $table->integer('Medicayion_ID');
            $table->integer('Elderly_ID');
            $table->string('event_type', 32);
            $table->string('actor_type', 32)->nullable();
            $table->integer('actor_id')->nullable();
            $table->dateTime('event_at');
            $table->text('meta_json')->nullable();
            $table->timestamps();

            $table->primary('DoseEvent_ID');
            $table->index('DoseOccurrence_ID', 'med_dose_evt_occ_idx');
            $table->index(['Elderly_ID', 'event_at'], 'med_dose_evt_elderly_at_idx');

            $table->foreign('DoseOccurrence_ID')
                ->references('DoseOccurrence_ID')->on('medication_dose_occurrences')
                ->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('medication_dose_events');
        Schema::dropIfExists('medication_dose_occurrences');
    }
};
