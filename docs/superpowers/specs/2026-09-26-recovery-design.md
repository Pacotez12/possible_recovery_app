# POSsible Recovery — design

Date: 2026-09-26. Client: CONMEBOL. Status: approved by Marco, start development; will be polished with real test tags.

## Problem

On 2026-02-18 `ConmebolSeeder` truncated master tables; PostgreSQL `TRUNCATE ... CASCADE` also wiped `physical_items`. About 33,000 RFID labels printed in 2025 are physically attached to assets but their EPCs no longer exist in the DB. The EPCs were random (`'30' + 22 hex`), so they cannot be regenerated and no backup before 2026-02-18 exists. Every label must be re-associated in the field: read the EPC by RFID, identify the asset by the SKU printed on the label.

Each label shows the SKU as text (`AF-012918`) and as a QR whose content is always `https://possible.conmebol.com/api/search?type=product&term=AF-012918`.

## Scope

1. Backend endpoints + audit table + panel progress page in the CONMEBOL backend (`/home/mbsegel/Proyectos/possible`, Laravel 10 / Filament 3, branch `test`).
2. A new, separate, lightweight Flutter app for Chainway C72 (`/home/mbsegel/StudioProjects/possible_recovery_app`). Not a module of `possible_rfid_app`.

Out of scope now: cleaning the 5–6 never-printed "phantom" tags per product that already exist in `physical_items` (decide after a test inventory). Removing the destructive `truncate()` import hooks / protecting `ConmebolSeeder` is a separate task (must be done before the full field campaign).

## Backend

### Table `tag_matches` (audit, append-only)
`id, epc (string 24, index), product_id (nullable FK products), sku (string), result (enum-like string: created | verified | conflict | rejected), previous_product_id (nullable), physical_item_id (nullable), user_id (FK users), device_id (string nullable), client_uuid (string, unique), message (text nullable), created_at, updated_at`.

### Endpoints (under existing `auth:api` group, prefix `recovery`)
- `GET /api/recovery/catalog` → `[{id, sku, description, location}]` for all products. `location` = "Warehouse › Location" (use `full_name` if available). Must be light and stream-safe for ~33k rows (select only needed columns, no Resource N+1).
- `POST /api/recovery/lookup` `{epc}` → `{status: "new"}` or `{status: "assigned", sku, description, product_id, assigned_by, assigned_at}` (last `tag_matches` row if any, else physical_item data).
- `POST /api/recovery/assign` `{epc, sku, device_id, client_uuid}`:
  - Normalize EPC (uppercase, trim, must match `^[0-9A-F]{24}$`) and SKU (uppercase, trim).
  - Idempotent: if `client_uuid` already exists, return the stored result unchanged.
  - SKU not found → 422 `{result:"rejected", message}` (audited).
  - EPC not in `physical_items` → create `physical_item` (product_id from SKU, location_id from the product's first `product_locations` row, `status='en_stock'`, `lot_number='RECOVERY'`, `printed_count=1`) → 201 `{result:"created"}`.
  - EPC exists with same product → 200 `{result:"verified"}` (no change).
  - EPC exists with other product → 409 `{result:"conflict", current_sku, current_description}`; nothing changes.
  - Everything inside a DB transaction with `lockForUpdate` on the EPC to be safe with concurrent operators.
- `GET /api/recovery/progress` → totals `{created, verified, conflicts, by_user:[...]}` (optional for the app, used by panel).

### Panel
Filament page "Recuperación de etiquetas" (Spanish labels, all strings in `lang/es.json`): stats (created / verified / conflicts), table of `tag_matches` filterable by result/user/date, and for conflicts an action "Reasignar al SKU escaneado" (moves the physical_item to the new product, audits it). Only admin/super_admin.

### Tests
Feature tests for `assign`: created, verified, conflict, rejected (bad SKU / bad EPC), idempotent retry, and `lookup` both states.

## App (`possible_recovery_app`)

Flutter (same toolchain as `possible_rfid_app`, `/home/mbsegel/Proyectos/flutter/bin/flutter`), package `com.segel.possible_recovery`, app name "POSsible Recovery", Spanish UI only, minSdk = flutter default.

Reuse from `possible_rfid_app` (copy, don't depend): the Kotlin `MethodChannel` RFID bridge (`RFIDWithUHFUART`, `DeviceAPI_ver20250209_release.aar`, trigger `keyCode 293`), and the Dio/JWT API host pattern.

Screens:
1. **Login**: API host (e.g. `http://host:8000/api/`), email, password → `/api/login` JWT. Stored in shared_preferences.
2. **Sync**: downloads `/api/recovery/catalog` into SQLite (`products` table indexed by sku). Shows count and last sync time. Manual re-sync button.
3. **Scan (main)**:
   - Trigger (or on-screen button) starts a ~1 s single-tag read at configurable low power (default 10 dBm). Pick the EPC with best RSSI; if the second-best is within 3 dB, show "Hay más de una etiqueta cerca, acercate más" and don't proceed.
   - Show EPC, call `lookup` (if offline: treat as unknown and warn).
   - `new` → prompt "Escaneá el QR o escribí el SKU". QR/barcode via C72 2D scanner if present (keyboard wedge / scan broadcast), camera fallback (`mobile_scanner`). Manual input accepts `AF-012918`, `012918` (auto-prefix `AF-`), or the full URL. Parser: take `term` query param if URL, uppercase, trim, validate `^AF-\d{6}$`, look up in local catalog, show description + location, big "Confirmar".
   - `assigned` → show "AF-xxxx · descripción · asignada por X el dd/mm". Scanning the QR: same SKU → `verified`; different → conflict screen (red), nothing overwritten.
   - Distinct sound + vibration for created / verified / conflict / error.
   - Session counters: creadas, verificadas, conflictos, pendientes.
4. **Pendientes**: offline queue (SQLite) of assigns with `client_uuid` (uuid v4) and `device_id` (Android ID); auto-retry when connectivity returns; shows server results (conflicts flagged).
5. **Ajustes**: RFID power slider, host, logout.

## Error handling
Network errors → queue; 401 → re-login; 409 → conflict screen; 422 → show message, keep the EPC on screen to retry with a correct SKU; ambiguous read → ask to get closer; unknown SKU in catalog → warn but allow sending (server validates).

## Rollout
Backend on `test` (local conmebol env on :8001, then CONMEBOL test server `pan`) → pilot ~50 test tags → test inventory with `possible_rfid_app` → prod. Nobody commits except Marco.
