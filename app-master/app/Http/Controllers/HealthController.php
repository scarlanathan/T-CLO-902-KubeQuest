<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    /**
     * Liveness : le process répond. Ne teste PAS les dépendances externes
     * (sinon un incident DB tuerait le pod au lieu de le laisser vivant).
     */
    public function live()
    {
        return response()->json(['status' => 'ok'], 200)
            ->header('Cache-Control', 'no-store');
    }

    /**
     * Readiness : le pod est prêt à recevoir du trafic, i.e. la base est
     * joignable. Renvoie 503 sinon, pour être retiré du Service le temps que
     * la dépendance revienne.
     */
    public function ready()
    {
        try {
            DB::connection()->getPdo();
            return response()->json(['status' => 'ready'], 200)
                ->header('Cache-Control', 'no-store');
        } catch (\Throwable $e) {
            return response()->json(['status' => 'not-ready'], 503)
                ->header('Cache-Control', 'no-store');
        }
    }
}
