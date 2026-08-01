<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Controllers\ActivityController;
use App\Controllers\AuthController;
use App\Controllers\BoardController;
use App\Mudbase\MudbaseApiError;
use App\Router;
use App\View;

$router = new Router();

$board = new BoardController();
$activity = new ActivityController();
$auth = new AuthController();

$router->get('/', [$board, 'index']);
$router->post('/lists', [$board, 'createList']);
$router->post('/lists/{id}/rename', [$board, 'renameList']);
$router->post('/lists/{id}/delete', [$board, 'deleteList']);
$router->post('/lists/{id}/move', [$board, 'moveList']);
$router->post('/cards', [$board, 'createCard']);
$router->post('/cards/{id}/edit', [$board, 'editCard']);
$router->post('/cards/{id}/delete', [$board, 'deleteCard']);
$router->post('/cards/{id}/move', [$board, 'moveCard']);

$router->get('/activity', [$activity, 'index']);

$router->get('/login', [$auth, 'loginForm']);
$router->post('/login', [$auth, 'login']);
$router->post('/logout', [$auth, 'logout']);

try {
    $router->dispatch((string) $_SERVER['REQUEST_METHOD'], (string) $_SERVER['REQUEST_URI'], function (): void {
        View::render('errors/not_found', [], 404);
    });
} catch (MudbaseApiError $e) {
    if ($e->isUnauthorized()) {
        // Token expired/was revoked mid-session - clear it and send the visitor back to /login.
        // Unlike the social/ecommerce PHP ports (which re-bootstrap as a fresh anonymous guest),
        // this app has no guest mode at all, so there is nowhere degraded to fall back to.
        $requestedPath = (string) $_SERVER['REQUEST_URI'];
        unset($_SESSION['mudbase_token'], $_SESSION['mudbase_refresh_token'], $_SESSION['mudbase_user']);
        header('Location: /login?redirect=' . urlencode($requestedPath));
        exit;
    }

    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
} catch (\Throwable $e) {
    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
}
