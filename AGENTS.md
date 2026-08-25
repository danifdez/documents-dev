# Documents — Monorepo Guide

This is the portable instruction file for agents working on the **Documents** platform. It replaces the former Claude-specific configuration.

## Architecture map

Documents is a development monorepo that orchestrates three services, each with its own Git repository:

| Directory | Stack | Role |
|---|---|---|
| `backend/` | NestJS, TypeORM, PostgreSQL, Socket.io | REST API, execution queue, notifications |
| `frontend/` | Electron, Vue 3, Vite, Electron Forge | Desktop application |
| `models/` | Python | AI/ML polling worker |

### Execution pipeline

A feature commonly spans all three services through Backend's durable execution
control plane:

```text
frontend (Vue service → HTTP)
  → backend creates or processes an execution
  → models worker claims a fenced step over authenticated HTTP
  → result is acknowledged and finalized by backend
  → backend emits Socket.io notifications through its outbox
  → frontend receives the notification and updates the UI
```

- Backend owns finalization through `ExecutionProcessorFactory`.
- Models owns heavy ML types. Each handler is `tasks/<type>/<type>.py`, decorated with `@execution_handler("<type>")` and enabled in `models/config/tasks.json`.
- Only Backend accesses execution tables; Models uses the worker protocol.
- `backend/src/model/model.service.ts` is the backend-to-models bridge.

PostgreSQL holds application data, executions and their append-only evidence,
pgvector embeddings, and the Apache AGE entity graph. The schema is
migration-first: TypeORM `synchronize` is disabled.

## Shared rules

1. Create commits only when explicitly requested. When requested, commit code in the service repository that changed (`backend/`, `frontend/`, or `models/`). Do not commit application code at the monorepo root; it stores only submodule pointers, which change only when the user asks.
2. Use English for code, comments, UI strings, errors, LLM prompts, and database labels.
3. Make PostgreSQL changes migration-first. Every entity change needs a committed TypeORM migration; never rely on auto-sync.
4. Use `./manage` for lifecycle operations. Do not hand-roll Docker lifecycle commands or kill service processes manually.
5. Never run `./manage reset` or `./manage import` without explicit user confirmation. Both are destructive: they drop the schema and wipe `documents/`.
6. Before calling a feature done, trace whether it needs coordinated backend, models, and frontend changes through the execution pipeline.
7. Respect feature flags: `FEATURE_*` on backend, `worker.capabilities.*` on models, and router `meta.feature` plus `featureStore` on frontend.
8. Pin every new or updated dependency version exactly. npm dependencies must have no `^` or `~` and retain the lockfile; Python requirements use `==`; Docker and runtime versions must not use `latest` or floating ranges.
9. Before calling a code change done, inspect the diff in the monorepo root and every affected service, run checks proportional to the changed behavior, and report any relevant checks that were skipped.

## Lifecycle

Run these from the monorepo root:

```bash
./manage install        # initial setup: .env, dependencies, migrations, venv
./manage start          # infrastructure, backend, and models worker
cd frontend && npm start  # frontend is not started by manage start
./manage stop
./manage logs backend|models
./manage profile:list|create|switch|...
```

For infrastructure only, use `docker compose up -d` (PostgreSQL with pgvector and Apache AGE).

## Backend (`backend/`)

NestJS service owning the REST API, execution queue, and Socket.io notifications.

### Rules

1. Register a new module in both `src/app.module.ts` and its relevant `TypeOrmModule.forFeature([...])` declaration.
2. Ship every entity change with a committed migration.
3. For a new execution processor, implement `canProcess(taskType)` and add the class to the right `providers` array in `execution-processor.module.ts`; retain its feature-flag guard when applicable.
4. Keep heavy ML in `models/`. Backend processors orchestrate via `src/model/model.service.ts` and publish results through `NotificationGateway`.
5. Do not run `npm run lint`: it uses `--fix` over the whole tree. Run `npm run build`, targeted tests, and non-fixing ESLint only on files changed deliberately. Unit-test new service logic with a mocked repository using `getRepositoryToken(Entity)`.

### Commands

```bash
npm run start:dev
npm run test
npm run migration:run
npm run migration:revert
npm run typeorm migration:generate ./migrations/<Name>
```

`npm run migration:generate` is hardcoded to `./migrations/Init`; use the last command when naming a migration.

### Layout and conventions

```text
src/<feature>/
  <feature>.entity.ts       @Entity({ name: 'snake_plural' }), snake_case columns
  <feature>.controller.ts   @Controller('kebab'), ParseIntPipe on :id
  <feature>.service.ts      @Injectable; many extend BaseCrudService
  <feature>.module.ts
  dto/<feature>.dto.ts      Create*/Update* DTOs with class-validator
migrations/                 <timestamp>-<Name>.ts (up/down, raw SQL)
test/unit/<feature>/        *.spec.ts mirrors src/
```

`ExecutionProcessorFactory` discovers processor providers at boot by scanning
`execution-processor/processors/`, mapping a filename to its PascalCase DI
class, then matching `canProcess`. Processors with unavailable dependencies are
silently skipped. Create work through `ExecutionService` with `taskType`,
priority, JSONB payload and optional tree identity.

Configuration comes from `@nestjs/config` and `backend/.env`. Relevant settings include `POSTGRES_*`, `PORT` (3000), `CORS_ORIGIN`, `AUTH_ENABLED`/`JWT_*`, `DOCUMENTS_STORAGE_DIR`, and `FEATURE_*`. TypeScript strict-null checks and `no-explicit-any` are disabled.

## Frontend (`frontend/`)

Electron desktop application built with Electron Forge, Vue 3, and Vite.

### Rules

1. The renderer has no Node access. Any OS or main-process capability crosses `preload.ts` through `contextBridge`; do not import Node modules in a component.
2. Storage is workspace-scoped. Token and state keys use `${key}_${workspaceId}`, and the API base URL is per workspace. Use `useWorkspaceStore()` rather than assuming one global server.
3. A new IPC channel requires all three edits: `ipcMain.handle` in `main.ts`, bridge exposure in `preload.ts`, and a guarded `window.<ns>.action()` call using `useElectronApi()`.
4. Verify UI flows with Playwright E2E tests; they are the meaningful coverage layer.
5. `getUserMedia` requires a main-process permission handler. A new Socket.io namespace on a live host needs `forceNew`, `autoConnect: false`, and an explicit `connect()`.

### Commands

```bash
npm start
npm run lint
npm run test:e2e
npm run test:e2e:skip-reset
npm run make
```

### Process split and layout

- `src/main.ts`: main process; windows, tray, IPC handlers, standalone server orchestration, workspace and offline handlers.
- `src/preload.ts`: typed `contextBridge` APIs such as `window.electronAPI` and `window.voice`.
- `src/renderer.ts`: Vue bootstrapping, router, Pinia, plugins, and offline interceptor.

```text
src/pages/                    PascalCase.vue, one per route
src/components/<domain>/      PascalCase.vue; base UI in components/ui/
src/store/                     <name>Store.ts, Pinia Composition style
src/services/<domain>/         use<Thing>.ts, Axios API calls
src/composables/               use<Thing>.ts, reusable logic
src/router/index.ts            createWebHashHistory; meta: { feature } and auth guards
```

A screen change includes its page, route (with `meta.feature` when gated), store, and service. The offline interceptor in `src/services/offline/` can resolve GET requests from IndexedDB while the server is unreachable. `VITE_API_URL` defaults to `http://localhost:3000` and is set per workspace through `setApiBaseUrl`.

## Models (`models/`)

Python worker that executes self-contained assignments granted by Backend.

### Rules

1. An execution type `foo-bar` requires `tasks/foo_bar/foo_bar.py`, a handler decorated as `@execution_handler("foo-bar")`, and an enabled entry in `config/tasks.json`. Missing any one makes the worker silently skip it.
2. Return a dictionary: it becomes the typed `StepResult` value consumed by Backend, so keep its shape stable.
3. For iteration without loading large models, disable capabilities in `config/config.json` with `worker.disable_llm` or `worker.disable_embeddings`.
4. The standard-library tests live in `tests/`.
5. Never open PostgreSQL, pgvector or AGE from Models. Backend supplies domain snapshots through payloads/artifacts and persists validated effects.

### Commands

```bash
python executions.py
```

`executions.py` registers the worker, claims compatible steps over HTTP,
downloads attempt-scoped artifacts, renews leases and retries result delivery
until Backend returns a terminal ACK. Backend owns terminal finalization and
all domain effects. Configuration is `config/config.json` merged over
`common/config.default.json`.

### Task pattern and connections

```python
from common.execution_registry import execution_handler

@execution_handler("foo-bar")
def foo_bar(payload, state=None, ctx=None):
    text = payload.get("content", "")
    return {"result": ...}
```

`utils/task_dispatch.py` imports `tasks/foo_bar/foo_bar.py` for a `foo-bar`
type and registers it in `TASK_HANDLERS`. LLM task prompts belong in
`tasks/foo_bar/prompt.md`. Backend owns fan-out/fan-in and passes ordered
partials to reduce steps. Vector searches receive a bounded
`vector_candidates` artifact and rank it locally. `utils/device.py` detects CPU
versus GPU; GPU dependencies are in `requirements-gpu.txt`.
