# GreenMart POS Backend API Requirements

Version 1.2 - 12 August 2026
Target backend: EazyERP Laravel application
Target clients: Flutter Web, Windows, Android and iOS

## Purpose

This is the maintainable backend handoff and implementation tracker for GreenMart POS. It separates Connector APIs already available to the OAuth-authenticated Flutter client from capabilities that exist only in the session-based Laravel web application.

Routes marked **Proposed** are requirements, not confirmed production endpoints. Existing Laravel web routes must not be called directly from Flutter because they depend on sessions, CSRF, Blade views or DataTables HTML.

The backend team owns the final field-level request and response payloads. Those contracts should be published through OpenAPI or Postman. This document focuses on required capabilities, routes, business rules, priorities and acceptance criteria.

## Current conclusion

| Area | Backend capability | Connector API | Flutter status |
|---|---|---|---|
| Products | Read and write logic exists | Available | Integrated |
| Customers | Read/create/update exists | Available | Integrated |
| POS sales | Create/list/update/delete/return exists | Mostly available | Basic sale integrated |
| Purchase orders | Full web workflow exists | Missing | Cannot implement safely |
| Purchase bills | Full web workflow exists | Missing | Placeholder |
| Inventory | Adjustment/transfer/opening stock exists | Read-only report only | Read-only |
| Reports | Many web reports exist | Only P&L and stock | Basic |
| Offline sync | No conflict-safe mobile contract | Missing | Not implemented |
| Hardware payment | Vendor-specific | Missing | Manual method recording only |

## Priorities

- **P0:** Operational purchasing and inventory: purchase orders, purchase bills, supplier payments, purchase returns, stock adjustments, transfers, opening stock, stocktake and movement history.
- **P1:** Complete daily operation: cash register, advanced sales returns/refunds, receipts and management reports.
- **P2:** Resilient multi-device rollout: offline synchronization, idempotency, conflicts, terminal integration and device auditability.

## Verified existing Connector APIs

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/oauth/token` | Password-grant authentication |
| GET | `/connector/api/user/loggedin` | Current user and permissions |
| GET | `/connector/api/business-details` | Business configuration |
| GET | `/connector/api/business-location` | Permitted stores |
| GET | `/connector/api/product` | Products, variations, prices and stock |
| POST | `/connector/api/products` | Create product |
| PATCH | `/connector/api/products/{id}` | Edit product |
| POST | `/connector/api/products/save_quick_product` | Quick product and opening stock |
| POST | `/connector/api/products/bulk-update` | Bulk product update |
| POST | `/connector/api/import-products/store` | Spreadsheet import |
| GET | `/connector/api/taxonomy?type=product` | Categories and subcategories |
| GET | `/connector/api/unit`, `/brand`, `/tax` | Catalog lookups |
| GET/POST/PUT | `/connector/api/contactapi` | Customer and supplier contacts |
| GET/POST/PUT/DELETE | `/connector/api/sell` | Sales CRUD |
| POST | `/connector/api/sell-return` | Sales return |
| GET | `/connector/api/product-stock-report` | Paginated stock report |
| GET | `/connector/api/profit-loss-report` | Profit and loss totals |
| GET | `/connector/api/payment-methods` | Configured payment methods |

### Existing contract observations

- `POST /sell` may return HTTP 200 even if an individual item fails; errors can be nested in the body.
- Final sale creation requires purchase/opening-stock allocation records, not only `qty_available`.
- The cash-register resource declares update, but the verified controller does not implement it.
- Product SKU generation in the web utility reads session state. Stateless Connector requests must not rely on session state.

## API-wide standards

- Use `auth:api` and timezone middleware.
- Derive the authenticated user, `business_id`, permissions and permitted locations server-side.
- Never trust a client-supplied business ID.
- Return 401 for invalid/expired tokens, 403 for insufficient permission, and field-addressable 422 validation errors.
- Return JSON resources only; never return Blade HTML or DataTables fragments.
- Use ISO 8601 timestamps with timezone.
- Use one consistent monetary representation.
- Paginate list APIs with stable sorting and controlled page sizes.
- Support cursor or `updated_since` synchronization where applicable.
- Accept an idempotency key on every stock or financial mutation.
- Return a record version or `updated_at` for optimistic concurrency.
- Enforce business ownership and permitted-location access for all referenced records.
- Wrap stock and financial mutations in database transactions.

## Purchase orders - Proposed P0

**Backend update (12 August 2026):** CRUD and status endpoints were supplied by the backend developer. Flutter integration is implemented and awaits end-to-end verification against the updated backend deployment.

| Method | Endpoint | Capability |
|---|---|---|
| GET | `/connector/api/purchase-orders` | Filterable, paginated list |
| POST | `/connector/api/purchase-orders` | Create order |
| GET | `/connector/api/purchase-orders/{id}` | Detailed order with lines and totals |
| PATCH | `/connector/api/purchase-orders/{id}` | Edit an unlocked order |
| DELETE | `/connector/api/purchase-orders/{id}` | Delete when permitted and safe |
| PATCH | `/connector/api/purchase-orders/{id}/status` | Update order and shipping status |
| POST | `/connector/api/purchase-orders/{id}/convert-to-purchase` | Convert remaining quantities to a purchase bill |
| GET | `/connector/api/purchase-orders/{id}/pdf` | Printable purchase-order PDF |

Required filters: location, supplier, order status, shipping status, date range, search, creator, remaining-only, sorting and pagination.

Acceptance criteria:

- Totals match existing EazyERP calculation rules.
- Supplier, products, variations and location belong to the authenticated business.
- Remaining quantity is available per line.
- Completed/locked orders follow existing edit restrictions.
- Conversion is atomic and cannot exceed remaining quantities.

## Purchase bills - Proposed P0

**Backend update (12 August 2026):** CRUD endpoints were supplied by the backend developer. Flutter integration is implemented and awaits end-to-end verification against the updated backend deployment.

| Method | Endpoint | Capability |
|---|---|---|
| GET | `/connector/api/purchases` | Filterable, paginated purchase list |
| POST | `/connector/api/purchases` | Create purchase and receive stock |
| GET | `/connector/api/purchases/{id}` | Purchase details |
| PATCH | `/connector/api/purchases/{id}` | Edit and reconcile stock |
| DELETE | `/connector/api/purchases/{id}` | Void/delete under accounting and stock rules |
| POST | `/connector/api/purchases/{id}/payments` | Record supplier payment |
| GET | `/connector/api/purchases/{id}/payments` | List payments |
| POST | `/connector/api/purchases/{id}/attachments` | Upload invoice/document |
| GET | `/connector/api/purchases/{id}/pdf` | Printable purchase bill |

Creation, update and deletion must reuse EazyERP stock utilities so purchase lines, location stock, allocations, ledgers and purchase-order balances remain consistent. Directly editing `qty_available` is not acceptable.

## Purchase returns and suppliers - Proposed

**Backend update (12 August 2026):** List, create and detail endpoints for purchase returns were supplied. Flutter exposes only those supported operations; return edit/delete remains unavailable until corresponding APIs are provided.

| Priority | Method | Endpoint | Capability |
|---|---|---|---|
| P0 | GET | `/connector/api/purchase-returns` | List returns |
| P0 | POST | `/connector/api/purchase-returns` | Create return against purchase |
| P0 | GET | `/connector/api/purchase-returns/{id}` | Return details |
| P0 | PATCH | `/connector/api/purchase-returns/{id}` | Edit when permitted |
| P0 | DELETE | `/connector/api/purchase-returns/{id}` | Cancel/delete safely |
| P0 | POST | `/connector/api/purchase-returns/{id}/refunds` | Record supplier refund |
| P0 | GET | `/connector/api/suppliers` | Searchable supplier lookup with balance and terms |
| P1 | GET | `/connector/api/suppliers/{id}/statement` | Purchases, returns, payments and balance |

Return quantities cannot exceed eligible purchased quantities. Stock, purchase-line return quantities, supplier balance and refund status must update atomically. Lot, serial and expiry references must be preserved where enabled.

## Inventory management - Proposed P0

### Stock adjustments

| Method | Endpoint | Capability |
|---|---|---|
| GET | `/connector/api/stock-adjustments` | List adjustments |
| POST | `/connector/api/stock-adjustments` | Increase/decrease stock with reason |
| GET | `/connector/api/stock-adjustments/{id}` | Adjustment details |
| PATCH | `/connector/api/stock-adjustments/{id}` | Edit when accounting rules permit |
| DELETE | `/connector/api/stock-adjustments/{id}` | Safely reverse adjustment |

### Stock transfers

| Method | Endpoint | Capability |
|---|---|---|
| GET | `/connector/api/stock-transfers` | List transfers |
| POST | `/connector/api/stock-transfers` | Create transfer |
| GET | `/connector/api/stock-transfers/{id}` | Transfer details and status |
| PATCH | `/connector/api/stock-transfers/{id}` | Edit before completion |
| POST | `/connector/api/stock-transfers/{id}/dispatch` | Dispatch from source |
| POST | `/connector/api/stock-transfers/{id}/receive` | Receive at destination |

### Opening stock, stocktake and movement

| Method | Endpoint | Capability |
|---|---|---|
| POST | `/connector/api/opening-stock` | Set initial stock through allocation logic |
| POST | `/connector/api/stocktakes` | Create physical stock count |
| POST | `/connector/api/stocktakes/{id}/finalize` | Create reconciliation adjustment |
| GET | `/connector/api/stock-movements` | Auditable stock movement ledger |

Inventory acceptance criteria:

- Every mutation creates auditable transaction lines.
- Negative stock follows business configuration and permissions.
- Source stock is validated before transfer dispatch.
- Repeated receive/finalize requests cannot duplicate stock.
- Queries are business- and location-scoped.
- Concurrent writes use locking or an equivalent safe strategy.
- Movement history includes time, item, variation, location, movement type, before/change/after quantities, cost, source reference, creator and idempotency reference.

## Catalog administration - Proposed P1

| Method | Endpoint | Capability |
|---|---|---|
| POST | `/connector/api/taxonomy` | Create category/subcategory |
| PATCH | `/connector/api/taxonomy/{id}` | Edit category/subcategory |
| DELETE | `/connector/api/taxonomy/{id}` | Delete safely or apply replacement |
| DELETE | `/connector/api/products/{id}` | Deactivate/delete product safely |
| PATCH | `/connector/api/products/{id}/status` | Activate/deactivate product |
| POST | `/connector/api/products/check-sku` | Validate SKU uniqueness |
| DELETE | `/connector/api/products/{id}/image` | Remove product image |

For live bilingual data, products and taxonomies need English and Arabic names, or a translations object. APIs should return the complete translations and an appropriate localized name.

## Advanced sales - Existing plus Proposed P1

| Endpoint | State | Required work |
|---|---|---|
| `PATCH /connector/api/sell/{id}` | Existing | Verify final/draft update behavior |
| `DELETE /connector/api/sell/{id}` | Existing | Verify permissions and reversal behavior |
| `POST /connector/api/sell-return` | Existing | Normalize errors and document contract |
| `GET /connector/api/list-sell-return` | Existing | Confirm filters and pagination |
| `GET /connector/api/sell/{id}/receipt` | Proposed | Canonical receipt data and optional PDF |
| `POST /connector/api/sell/{id}/payments` | Proposed | Add/settle payment |
| `POST /connector/api/sell/{id}/refund` | Proposed | Atomic return and refund |

## Cash register - Proposed P1

| Method | Endpoint | Capability |
|---|---|---|
| POST | `/connector/api/cash-register/open` | Open with initial cash |
| GET | `/connector/api/cash-register/current` | Current user's open register |
| POST | `/connector/api/cash-register/{id}/cash-in` | Record cash added |
| POST | `/connector/api/cash-register/{id}/cash-out` | Record cash removed |
| POST | `/connector/api/cash-register/{id}/close` | Close and reconcile |
| GET | `/connector/api/cash-register/{id}/summary` | Expected and actual totals by method |

## Reports - Proposed P1

All report APIs need date range, permitted location filters, stable totals and export-friendly JSON.

- `GET /connector/api/reports/sales`
- `GET /connector/api/reports/product-sales`
- `GET /connector/api/reports/purchases`
- `GET /connector/api/reports/taxes`
- `GET /connector/api/reports/payments`
- `GET /connector/api/reports/registers`
- `GET /connector/api/reports/inventory-valuation`
- `GET /connector/api/reports/stock-movements`
- `GET /connector/api/reports/returns`

## Offline synchronization - Proposed P2

| Method | Endpoint | Capability |
|---|---|---|
| GET | `/connector/api/sync/changes?cursor={cursor}` | Incremental change feed |
| POST | `/connector/api/sync/batch` | Upload queued mutations |
| POST | `/connector/api/sync/resolve-conflict` | Explicit conflict resolution |

Required behavior:

- Uniquely identify each client device and client operation.
- Return the original success result when an operation is retried.
- Never duplicate sales, purchases, payments or stock movements.
- Return current server version/state for competing edits.
- Include deletions as tombstones.
- Advance a cursor only after a complete ordered page is consumed.

## Payment terminals and printing - Proposed P2

| Method | Endpoint | Capability |
|---|---|---|
| POST | `/connector/api/terminal/payments` | Initiate payment |
| GET | `/connector/api/terminal/payments/{id}` | Poll authoritative status |
| POST | `/connector/api/terminal/payments/{id}/cancel` | Cancel before capture |
| POST | `/connector/api/terminal/payments/{id}/refund` | Refund captured payment |
| POST | `/connector/api/terminal/webhook` | Verified provider callback |
| GET | `/connector/api/sell/{id}/receipt` | Canonical receipt data |
| GET | `/connector/api/sell/{id}/receipt.pdf` | Server-rendered printable PDF |

The backend must verify provider signatures and store the provider transaction, masked payment details, authorization code and status history. A device-reported success is not authoritative.

Bluetooth, USB, network and A4 printing remain primarily Flutter/platform responsibilities. The backend should supply canonical receipt data and optional printable PDFs.

## Authentication security

A client secret embedded in Flutter Web, Windows, Android or iOS is extractable and cannot be considered confidential. Production should use a backend-for-frontend login proxy or a public-client flow such as Authorization Code with PKCE. Configure explicit CORS origins and avoid wildcard credential policies.

## Definition of done

An API group is complete only when:

- OpenAPI/Postman documentation lists method, URL, authentication, fields, filters and errors.
- Business isolation, permissions and permitted locations are enforced server-side.
- Validation errors are field-addressable and foreign IDs are ownership-validated.
- Financial and stock writes are atomic and roll back completely.
- Retrying the same mutation cannot create duplicates.
- Concurrent stock/version conflicts are deterministic and tested.
- Lists use stable sorting and pagination metadata.
- Creator, updater, timestamps and source references are audited.
- Automated tests cover success, validation, unauthenticated, forbidden, cross-business, concurrency and rollback cases.
- Responses are JSON-only and require no Laravel session, CSRF, Blade or DataTables behavior.

## Required end-to-end tests

1. Create a purchase order, partially convert it, then complete the remainder.
2. Receive a purchase and verify sellable stock and purchase allocation.
3. Return purchased quantity and verify stock and supplier balance.
4. Adjust damaged stock and inspect movement history.
5. Transfer stock, retry receiving, and prove no duplicate stock receipt.
6. Run competing stock mutations and verify a safe deterministic result.
7. Retry a sale, payment and purchase with the same idempotency key.
8. Attempt cross-business and unpermitted-location IDs and receive 403/404.

## Recommended delivery plan

| Sprint | Scope | Outcome |
|---|---|---|
| A - P0 | Purchase orders, purchases, supplier payments and returns | End-to-end purchasing |
| B - P0 | Adjustments, transfers, opening stock, stocktake and movement | Operational inventory |
| C - P1 | Cash register, sales returns/refunds and receipt contract | Complete POS operation |
| D - P1 | Sales, purchases, tax, payment, register and inventory reports | Management reporting |
| E - P2 | Idempotency, change feed, batch sync and conflicts | Safe offline operation |
| F - P2 | Terminal gateway/webhooks and printer-ready outputs | Hardware readiness |

## Backend handoff checklist

- [ ] Confirm final route names.
- [ ] Publish the field-level contracts in OpenAPI or Postman.
- [ ] Provide a QA database with suppliers, locations, products and valid stock allocations.
- [ ] Share test OAuth credentials through a secure channel, not source control.
- [ ] Document the permission required by each endpoint.
- [ ] Notify the Flutter team about migrations and seed changes.
- [ ] Agree on monetary and timezone representation.
- [ ] Run end-to-end QA through Connector APIs, not the Laravel web UI.

## Source references

- `Eazyerp/Modules/Connector/Routes/api.php`
- `Eazyerp/routes/web.php`
- `Eazyerp/app/Http/Controllers/PurchaseOrderController.php`
- `Eazyerp/app/Http/Controllers/PurchaseController.php`
- `StockAdjustmentController`, `StockTransferController`, `OpeningStockController`
- Flutter checklist: `docs/api_integration_checklist.md`

## Final clarification

Purchase orders, purchase bills and inventory management already exist in EazyERP's web application. The missing layer is a stable OAuth-authenticated Connector JSON API for Flutter. The backend implementation should wrap and reuse existing domain logic rather than duplicate it.

## Maintenance notes

- Update this file whenever an endpoint is implemented, renamed or rejected.
- Mark proposed endpoints as **Implemented** only after integration testing from Flutter.
- Keep field-level contracts in OpenAPI/Postman and link them here when available.
- Record backend version/commit and verification date alongside each completed API group.
