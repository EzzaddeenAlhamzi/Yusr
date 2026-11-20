<?php

namespace App\Providers;

use App\Models\Appointment;
use App\Models\Caregiver;
use App\Models\Elderly;
use App\Policies\AppointmentPolicy;
use App\Policies\CaregiverPolicy;
use App\Policies\ElderlyPolicy;
use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;

class AuthServiceProvider extends ServiceProvider
{
    /**
     * The model to policy mappings for the application.
     *
     * @var array<class-string, class-string>
     */
    protected $policies = [
        Appointment::class => AppointmentPolicy::class,
        Caregiver::class => CaregiverPolicy::class,
        Elderly::class => ElderlyPolicy::class,
    ];

    /**
     * Register any authentication / authorization services.
     */
    public function boot(): void
    {
        $this->registerPolicies();
    }
}
