<?php

namespace App\Models\Traits;

trait HasCustomIncrementingId
{
    public function initializeHasCustomIncrementingId()
    {
        $this->incrementing = false;
    }

    protected static function bootHasCustomIncrementingId()
    {
        static::creating(function ($model) {
            $pk = $model->getKeyName();
            if (empty($model->{$pk})) {
                $max = static::withoutGlobalScopes()->max($pk) ?? 0;
                $model->{$pk} = $max + 1;
            }
        });
    }
}
