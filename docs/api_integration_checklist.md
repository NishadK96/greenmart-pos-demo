# EazyERP Flutter API integration checklist

The backend source under `Eazyerp/` is treated as read-only. Actual Connector
routes and controllers are the contract when generated documentation differs.

## Authentication and bootstrap

| Method | Endpoint | Purpose | Flutter status | Screen |
|---|---|---|---|---|
| POST | `/oauth/token` | Password-grant login | Integrated | Login |
| GET | `/connector/api/user/loggedin` | Current user/profile | Integrated | Shell, Settings |
| GET | `/connector/api/business-details` | Business/currency/settings | Integrated | Shell, Settings |
| GET | `/connector/api/business-location` | Permitted stores | Integrated | Shell, POS |
| GET | `/connector/api/payment-methods` | Enabled payment methods | Integrated | POS payment sheet |

## Catalog and inventory

| Method | Endpoint | Purpose | Flutter status | Screen |
|---|---|---|---|---|
| GET | `/connector/api/product` | Product, variation, price and location stock list | Integrated | POS, Products |
| GET | `/connector/api/product/{ids}` | Product details | Available; list payload already supplies current UI fields | — |
| GET | `/connector/api/taxonomy?type=product` | Categories/subcategories | Integrated | POS, Categories |
| GET | `/connector/api/product-stock-report` | Paginated stock report | Integrated, all pages fetched | Inventory |
| GET | `/connector/api/variation/{ids?}` | Variation lookup | Product list supplies required variations | — |
| GET | `/connector/api/unit` | Units | Not required by current read-only product UI | — |
| GET | `/connector/api/brand` | Brands | Not required by current filters | — |
| GET | `/connector/api/tax` | Taxes | Product payload supplies assigned tax | — |
| GET | `/connector/api/selling-price-group` | Price groups | Not required until location/price-group selection is added | POS |

Connector exposes no product/category create, update, or delete routes. Flutter
therefore keeps these screens read-only.

## Contacts

| Method | Endpoint | Purpose | Flutter status | Screen |
|---|---|---|---|---|
| GET | `/connector/api/contactapi?type=customer` | Paginated/searchable customers | Integrated | Customers, POS |
| POST | `/connector/api/contactapi` | Create customer | Integrated with validation errors | Customers |
| PUT | `/connector/api/contactapi/{id}` | Update customer | Integrated with validation errors | Customers |
| GET | `/connector/api/contactapi/{ids}` | Contact details | List payload supplies current UI fields | — |
| POST | `/connector/api/contactapi-payment` | Contact payment | Not represented in current product scope | New payment workflow required |

## Sales and POS

| Method | Endpoint | Purpose | Flutter status | Screen |
|---|---|---|---|---|
| GET | `/connector/api/sell` | Filterable sales history | Integrated | Sales, Dashboard, Reports |
| POST | `/connector/api/sell` | Finalize POS sale | Integrated | POS |
| GET | `/connector/api/sell/{ids}` | Sale detail | List response supplies current receipt fields | Sales |
| PUT | `/connector/api/sell/{id}` | Update draft/final sale | Not exposed by current UI | Edit-sale screen required |
| DELETE | `/connector/api/sell/{id}` | Delete sale | Not exposed; destructive workflow requires permissions/confirmation | Sales |
| POST | `/connector/api/sell-return` | Sale return | Not exposed | Return screen required |
| GET | `/connector/api/list-sell-return` | Return history | Not exposed | Returns screen required |
| POST | `/connector/api/update-shipping-status` | Shipping status | Not applicable to current retail checkout | — |

## Reports

| Method | Endpoint | Purpose | Flutter status | Screen |
|---|---|---|---|---|
| GET | `/connector/api/profit-loss-report` | P&L totals with date/location filters | Integrated (default financial year) | Reports |
| GET | `/connector/api/product-stock-report` | Inventory totals | Integrated | Inventory |

## Unsupported current screens

- **Purchases:** no Connector purchase route exists. `BACKEND CHANGE REQUIRED`.
- **Inventory adjustments:** no Connector stock-adjustment write route exists.
  `BACKEND CHANGE REQUIRED`.
- **Offline sync queue:** no batch/idempotency/conflict API contract exists.
  `BACKEND CHANGE REQUIRED` before offline writes can be safely enabled.

## Available APIs outside the current retail POS navigation

Expenses, cash registers, attendance, CRM follow-ups, field force, restaurant
tables/services, notifications, packages/subscriptions, user registration and
password operations exist in Connector. They require separate product modules,
permissions, routes, and screens and are not silently mapped onto unrelated POS
screens.

## Documentation observations

- Published docs call categories **Taxonomy management**; the implementation is
  `CategoryController` at `/connector/api/taxonomy`.
- `product-stock-report` documents pagination but ignores a requested
  `per_page=-1` in the implementation; Flutter follows `meta.last_page` and
  fetches every page.
- `POST /sell` returns HTTP 200 even when an individual sell fails. The error is
  nested under `[0].original.error.message`; Flutter explicitly unwraps it.
- Final sale creation requires purchase-allocation records, not just a positive
  `variation_location_details.qty_available`. The local seeded catalog lacks
  those purchase records, so final checkout currently returns a quantity
  mismatch. Production data must contain valid purchase/opening-stock mappings.
