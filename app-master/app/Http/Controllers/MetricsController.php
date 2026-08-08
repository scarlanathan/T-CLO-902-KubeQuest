<?php

namespace App\Http\Controllers;

use App\Models\Counter;
use Illuminate\Support\Facades\DB;

class MetricsController extends Controller
{
    /**
     * Expose des métriques au format d'exposition Prometheus (text/plain 0.0.4),
     * sans dépendance externe. Scrapé par le ServiceMonitor (voir
     * kubequest-cluster/laravel-app/templates/servicemonitor.yaml).
     *
     * Ne doit jamais renvoyer 500 : en cas d'erreur DB, on publie kubequest_db_up 0.
     */
    public function index()
    {
        $dbUp = 0;
        $counterTotal = 0;

        try {
            DB::connection()->getPdo();
            $dbUp = 1;
            $counterTotal = (int) Counter::sum('count');
        } catch (\Throwable $e) {
            // DB indisponible : db_up=0, on publie quand même le reste.
        }

        $lines = [
            '# HELP kubequest_up 1 si l\'application sert des requêtes.',
            '# TYPE kubequest_up gauge',
            'kubequest_up 1',
            '# HELP kubequest_db_up 1 si la base de données est joignable.',
            '# TYPE kubequest_db_up gauge',
            "kubequest_db_up {$dbUp}",
            '# HELP kubequest_counter_total Valeur courante du compteur applicatif.',
            '# TYPE kubequest_counter_total gauge',
            "kubequest_counter_total {$counterTotal}",
        ];

        return response(implode("\n", $lines) . "\n", 200)
            ->header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
            ->header('Cache-Control', 'no-store');
    }
}
