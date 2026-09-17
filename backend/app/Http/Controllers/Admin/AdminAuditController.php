<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Phase 16 — Audit des actions sensibles et export de rapports (J142).
 *
 * Consultation du journal d'audit append-only (lecture seule) et export CSV
 * de la recherche courante. La porteuse n'a pas d'accès direct à la base :
 * seul un rôle autorisé (AdminPolicy::manage) peut consulter.
 */
class AdminAuditController extends Controller
{
    public function index(Request $request): View
    {
        $this->authorize('manage', User::class);

        $query = AuditLog::query();

        if ($action = $request->query('action')) {
            $query->where('action', 'like', "%{$action}%");
        }

        if ($entityType = $request->query('entity_type')) {
            $query->where('entity_type', $entityType);
        }

        if ($search = trim((string) $request->query('q'))) {
            $query->where(function ($q) use ($search) {
                $q->whereRaw('LOWER(action) LIKE ?', ['%'.Str::lower($search).'%'])
                    ->orWhereRaw('LOWER(entity_type) LIKE ?', ['%'.Str::lower($search).'%'])
                    ->orWhere('actor_id', 'like', "%{$search}%");
            });
        }

        if ($from = $request->query('from')) {
            $query->whereDate('created_at', '>=', $from);
        }

        if ($to = $request->query('to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        $logs = $query->orderByDesc('created_at')->paginate(25)->withQueryString();

        return view('admin.audit.index', [
            'logs' => $logs,
            'entityTypes' => AuditLog::query()
                ->whereNotNull('entity_type')
                ->distinct()
                ->orderBy('entity_type')
                ->pluck('entity_type'),
            'filters' => [
                'q' => $request->query('q'),
                'action' => $action,
                'entity_type' => $entityType,
                'from' => $request->query('from'),
                'to' => $request->query('to'),
            ],
        ]);
    }

    public function export(Request $request): StreamedResponse
    {
        $this->authorize('manage', User::class);

        $query = AuditLog::query();

        if ($action = $request->query('action')) {
            $query->where('action', 'like', "%{$action}%");
        }

        if ($entityType = $request->query('entity_type')) {
            $query->where('entity_type', $entityType);
        }

        if ($from = $request->query('from')) {
            $query->whereDate('created_at', '>=', $from);
        }

        if ($to = $request->query('to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        $logs = $query->orderByDesc('created_at')->get();

        return response()->streamDownload(function () use ($logs): void {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['Date', 'Acteur', 'Action', 'Entité', 'Entité ID', 'IP', 'Changé']);

            foreach ($logs as $log) {
                fputcsv($handle, [
                    $log->created_at?->format('Y-m-d H:i:s'),
                    ($log->actor_type ?? '').' '.($log->actor_id ?? ''),
                    $log->action,
                    $log->entity_type ?? '',
                    $log->entity_id ?? '',
                    $log->ip ?? '',
                    json_encode($log->changes, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?? '',
                ]);
            }

            fclose($handle);
        }, 'audit-'.now()->format('Y-m-d-Hi').'.csv', ['Content-Type' => 'text/csv']);
    }
}
