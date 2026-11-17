<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Disposable yusr_lab domain schema — evidence-based from:
 * - yusr_application_backup.sql CREATE TABLE (structure only; dump never imported)
 * - Eloquent models under app/Models
 * - Flutter ApiService action payloads / legacy column names
 *
 * Preserves legacy typos and non-AUTO_INCREMENT PKs (HasCustomIncrementingId).
 * No invented columns, UNIQUE constraints, or AUTO_INCREMENT.
 */
return new class extends Migration
{
    public function up(): void
    {
        // --- Layer 0: roots (no domain FKs) ---
        Schema::create('admin', function (Blueprint $table) {
            $table->integer('Admin_ID');
            $table->string('A_Name', 100)->nullable();
            $table->string('A_Email', 100)->nullable();
            $table->string('A_Number', 20)->nullable();
            $table->string('A_password', 255)->nullable();
            $table->primary('Admin_ID');
        });

        Schema::create('elderly', function (Blueprint $table) {
            $table->integer('Eldery_ID');
            $table->string('E_Name', 100)->nullable();
            $table->string('E_sex', 10)->nullable();
            $table->string('E_PhonNumber', 20)->nullable();
            $table->string('E_Email', 150)->nullable();
            $table->string('E_Password', 255)->nullable();
            $table->primary('Eldery_ID');
        });

        Schema::create('location_alerts', function (Blueprint $table) {
            $table->integer('Alert_ID');
            $table->string('LA_State', 50)->nullable();
            $table->string('LA_Type', 50)->nullable();
            $table->primary('Alert_ID');
        });

        // --- Layer 1: depend on elderly / admin ---
        Schema::create('caregivers', function (Blueprint $table) {
            $table->integer('Caregivers_ID');
            $table->string('C_Name', 100)->nullable();
            $table->string('C_PhonNumber', 20)->nullable();
            $table->string('C_Relationship', 50)->nullable();
            $table->string('C_Email', 150)->nullable();
            $table->string('C_Password', 255)->nullable();
            $table->integer('Eldery_ID')->nullable();
            $table->primary('Caregivers_ID');
            $table->index('Eldery_ID');
            $table->foreign('Eldery_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('set null');
        });

        Schema::create('devices', function (Blueprint $table) {
            $table->integer('Devices_ID');
            $table->string('D_Type', 50)->nullable();
            $table->string('T_Number', 50)->nullable();
            $table->integer('Elderly_ID')->nullable();
            $table->primary('Devices_ID');
            $table->index('Elderly_ID');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('appointments', function (Blueprint $table) {
            $table->integer('Appointment_ID');
            $table->time('A_Time')->nullable();
            $table->date('A_Date')->nullable();
            $table->string('A_DateType', 50)->nullable();
            $table->string('A_Location', 255)->nullable();
            $table->mediumText('A_Note')->nullable();
            $table->integer('Elderly_ID')->nullable();
            $table->primary('Appointment_ID');
            $table->index('Elderly_ID');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('emergency_contacts', function (Blueprint $table) {
            $table->integer('contact_ID');
            $table->string('contact_Name', 100)->nullable();
            $table->string('Phone_Number', 20)->nullable();
            $table->string('Relationship', 50)->nullable();
            $table->integer('Priority')->nullable();
            $table->integer('Eldery_ID')->nullable();
            $table->primary('contact_ID');
            $table->index('Eldery_ID');
            $table->foreign('Eldery_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('emergency_log', function (Blueprint $table) {
            $table->integer('Emergency_ID');
            $table->string('E_Type', 50)->nullable();
            $table->date('E_Date')->nullable();
            $table->time('E_Time')->nullable();
            $table->string('E_Location', 255)->nullable();
            $table->decimal('latitude', 10, 8)->nullable();
            $table->decimal('Longitude', 11, 8)->nullable();
            $table->string('E_State', 50)->nullable();
            $table->mediumText('Descripion')->nullable();
            $table->integer('Elderly_ID')->nullable();
            $table->primary('Emergency_ID');
            $table->index('Elderly_ID');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('location_tracking', function (Blueprint $table) {
            $table->integer('Location_ID');
            $table->decimal('L_Latitude', 10, 8)->nullable();
            $table->decimal('L_Longitude', 11, 8)->nullable();
            $table->dateTime('L_UpdateTime')->nullable();
            $table->integer('L_Scor')->nullable();
            $table->integer('Elderly_ID')->nullable();
            $table->primary('Location_ID');
            $table->index('Elderly_ID');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('medications', function (Blueprint $table) {
            $table->integer('Medicayion_ID');
            $table->string('M_Name', 100)->nullable();
            $table->string('M_much', 50)->nullable();
            $table->string('M_RepatTime', 50)->nullable();
            $table->integer('Elderly_ID')->nullable();
            $table->primary('Medicayion_ID');
            $table->index('Elderly_ID');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('education_content', function (Blueprint $table) {
            $table->integer('Content_ID');
            $table->string('Content_Title', 200)->nullable();
            $table->string('Content_type', 50)->nullable();
            $table->string('Content_Image', 255)->nullable();
            $table->string('Content_status', 50)->nullable();
            $table->date('Publish_Date')->nullable();
            $table->integer('Admin_ID')->nullable();
            $table->primary('Content_ID');
            $table->index('Admin_ID');
            $table->foreign('Admin_ID')
                ->references('Admin_ID')->on('admin')
                ->onDelete('set null');
        });

        Schema::create('services', function (Blueprint $table) {
            $table->integer('Service_ID');
            $table->string('S_Name', 100)->nullable();
            $table->string('S_Type', 50)->nullable();
            $table->mediumText('S_Description')->nullable();
            $table->string('S_Status', 50)->nullable();
            $table->integer('Admin_ID')->nullable();
            $table->primary('Service_ID');
            $table->index('Admin_ID');
            $table->foreign('Admin_ID')
                ->references('Admin_ID')->on('admin')
                ->onDelete('set null');
        });

        // --- Layer 2: deeper FKs ---
        Schema::create('health_monitoring', function (Blueprint $table) {
            $table->integer('H_Record_ID');
            $table->integer('Heart_Rate')->nullable();
            $table->string('Blood_pressure', 20)->nullable();
            $table->integer('Oxyger')->nullable();
            $table->decimal('Temperature', 4, 2)->nullable();
            $table->integer('steps')->nullable();
            $table->string('H_Type', 50)->nullable();
            $table->date('H_Date')->nullable();
            $table->string('H_Result', 100)->nullable();
            $table->integer('Elderly_ID')->nullable();
            $table->integer('Devices_ID')->nullable();
            $table->integer('Emergency_ID')->nullable();
            $table->primary('H_Record_ID');
            $table->index('Elderly_ID');
            $table->index('Devices_ID');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
            $table->foreign('Devices_ID')
                ->references('Devices_ID')->on('devices')
                ->onDelete('set null');
            // Constraint name matches dump KEY/CONSTRAINT `FK_Health_Emergency`
            $table->foreign('Emergency_ID', 'FK_Health_Emergency')
                ->references('Emergency_ID')->on('emergency_log')
                ->onDelete('set null');
        });

        Schema::create('notifications', function (Blueprint $table) {
            $table->integer('Notifications_ID');
            $table->string('N_Title', 100)->nullable();
            $table->mediumText('N_Message')->nullable();
            $table->string('N_Type', 50)->nullable();
            $table->date('N_Date')->nullable();
            $table->time('N_Time')->nullable();
            $table->string('N_Status', 50)->nullable();
            $table->integer('Caregiver_ID')->nullable();
            $table->integer('Eldery_ID')->nullable();
            $table->primary('Notifications_ID');
            $table->index('Caregiver_ID');
            $table->index('Eldery_ID');
            $table->foreign('Caregiver_ID')
                ->references('Caregivers_ID')->on('caregivers')
                ->onDelete('cascade');
            $table->foreign('Eldery_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('reminders', function (Blueprint $table) {
            $table->integer('Reminder_ID');
            $table->string('R_title', 100)->nullable();
            $table->date('R_date')->nullable();
            $table->time('R_time')->nullable();
            $table->integer('Appointment_ID')->nullable();
            $table->primary('Reminder_ID');
            $table->index('Appointment_ID');
            $table->foreign('Appointment_ID')
                ->references('Appointment_ID')->on('appointments')
                ->onDelete('cascade');
        });

        Schema::create('type_of_care', function (Blueprint $table) {
            $table->integer('Tc_id');
            $table->string('Care_Type', 100)->nullable();
            $table->integer('Caregivers_ID')->nullable();
            $table->integer('Eldery_ID')->nullable();
            $table->primary('Tc_id');
            $table->index('Caregivers_ID');
            $table->index('Eldery_ID');
            $table->foreign('Caregivers_ID')
                ->references('Caregivers_ID')->on('caregivers')
                ->onDelete('cascade');
            $table->foreign('Eldery_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        Schema::create('services_request', function (Blueprint $table) {
            $table->integer('Service_Requst_ID');
            $table->date('Requst_Date')->nullable();
            $table->string('Requst_Status', 50)->nullable();
            $table->mediumText('Requst_Note')->nullable();
            $table->integer('Service_ID')->nullable();
            $table->integer('Caregivers_id')->nullable();
            $table->integer('Elderly_ID')->nullable();
            $table->primary('Service_Requst_ID');
            $table->index('Service_ID');
            $table->index('Caregivers_id');
            $table->index('Elderly_ID');
            $table->foreign('Service_ID')
                ->references('Service_ID')->on('services')
                ->onDelete('cascade');
            $table->foreign('Caregivers_id')
                ->references('Caregivers_ID')->on('caregivers')
                ->onDelete('cascade');
            $table->foreign('Elderly_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });

        // --- Layer 3 ---
        Schema::create('health_alerts', function (Blueprint $table) {
            $table->integer('Alert_ID');
            $table->string('A_Type', 50)->nullable();
            $table->mediumText('A_Description')->nullable();
            $table->string('A_Level', 50)->nullable();
            $table->date('A_Date')->nullable();
            $table->string('A_Status', 50)->nullable();
            $table->integer('H_Record_ID')->nullable();
            $table->primary('Alert_ID');
            $table->index('H_Record_ID');
            $table->foreign('H_Record_ID')
                ->references('H_Record_ID')->on('health_monitoring')
                ->onDelete('cascade');
        });

        Schema::create('safe_zones', function (Blueprint $table) {
            $table->integer('Zone_ID');
            $table->string('Z_Name', 100)->nullable();
            $table->string('Z_state', 50)->nullable();
            $table->integer('Z_Limit')->nullable();
            $table->integer('Alert_ID')->nullable();
            $table->integer('Location_ID')->nullable();
            $table->integer('Zldery_ID')->nullable();
            $table->primary('Zone_ID');
            $table->index('Alert_ID');
            $table->index('Location_ID');
            $table->index('Zldery_ID');
            $table->foreign('Alert_ID')
                ->references('Alert_ID')->on('location_alerts')
                ->onDelete('set null');
            $table->foreign('Location_ID')
                ->references('Location_ID')->on('location_tracking')
                ->onDelete('cascade');
            $table->foreign('Zldery_ID')
                ->references('Eldery_ID')->on('elderly')
                ->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('safe_zones');
        Schema::dropIfExists('health_alerts');
        Schema::dropIfExists('services_request');
        Schema::dropIfExists('type_of_care');
        Schema::dropIfExists('reminders');
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('health_monitoring');
        Schema::dropIfExists('services');
        Schema::dropIfExists('education_content');
        Schema::dropIfExists('medications');
        Schema::dropIfExists('location_tracking');
        Schema::dropIfExists('emergency_log');
        Schema::dropIfExists('emergency_contacts');
        Schema::dropIfExists('appointments');
        Schema::dropIfExists('devices');
        Schema::dropIfExists('caregivers');
        Schema::dropIfExists('location_alerts');
        Schema::dropIfExists('elderly');
        Schema::dropIfExists('admin');
    }
};
