<?php

/**
 * Lab policy for elderly↔caregiver linking codes (P1.2 security completion).
 */
return [
    // Plaintext code never stored; HMAC-SHA256 of 6-digit numeric code.
    'code_length' => 6,
    'ttl_minutes' => 10,

    // Anti-brute-force: max failed attempts per caregiver / window.
    'max_failed_attempts' => 5,
    'attempt_window_minutes' => 10,

    // Soft secondary cap by IP (practical lab control).
    'max_failed_attempts_per_ip' => 20,
];
