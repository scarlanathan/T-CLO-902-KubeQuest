<?php

use App\Http\Controllers\CounterController;
use App\Http\Controllers\HealthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/


// L'incrémentation mute l'état : réservée à POST (CWE-306/CWE-352).
// Une méthode non idempotente ne doit pas être déclenchable via GET
// (préchargement, balises <img>, caches, CSRF par navigation).
$router->post('counter/add', [CounterController::class, 'add']);
$router->get('counter/count', [CounterController::class, 'get']);

// Sondes Kubernetes (référencées par les probes des charts Helm).
$router->get('health', [HealthController::class, 'live']);
$router->get('ready', [HealthController::class, 'ready']);
