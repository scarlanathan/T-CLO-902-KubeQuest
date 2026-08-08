<?php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies as Middleware;
use Illuminate\Http\Request;

class TrustProxies extends Middleware
{
    /**
     * The trusted proxies for this application.
     *
     * Ne jamais faire confiance à '*' (CWE-348/CWE-770 : usurpation de
     * X-Forwarded-For -> contournement du rate limiter). On ne fait
     * confiance qu'aux plages privées d'où provient l'ingress/reverse-proxy.
     * Surchargeable par env TRUSTED_PROXIES (CSV de CIDR).
     *
     * @var array<int, string>|string|null
     */
    protected $proxies;

    public function __construct()
    {
        $env = env('TRUSTED_PROXIES');

        $this->proxies = $env !== null && $env !== ''
            ? array_filter(explode(',', (string) $env))
            : [
                '10.0.0.0/8',
                '172.16.0.0/12',
                '192.168.0.0/16',
                '127.0.0.1/8',
            ];
    }

    /**
     * The headers that should be used to detect proxies.
     *
     * @var int
     */
    protected $headers =
        Request::HEADER_X_FORWARDED_FOR |
        Request::HEADER_X_FORWARDED_HOST |
        Request::HEADER_X_FORWARDED_PORT |
        Request::HEADER_X_FORWARDED_PROTO |
        Request::HEADER_X_FORWARDED_AWS_ELB;
}
