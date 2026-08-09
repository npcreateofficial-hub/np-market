# NP Market

NP Market is a curated mobile price comparison app. Admins choose products in the back office, connect platform product links, and the mobile app shows users the latest mobile-sourced prices so they can decide where to buy.

## MVP Scope

- Flutter user app
- Admin-curated product catalog
- Product detail page with platform price comparison
- Affiliate/deep-link outbound click flow
- Mock data layer ready to replace with backend APIs

## User Flow

```text
Open app
-> browse/search curated products
-> open product detail
-> compare platform prices
-> tap buy/deal link
-> NP Market records click_id
-> user opens platform app or mobile web checkout
```

## Data Ownership

The app should not auto-list the whole marketplace. The back office is the source of truth for which products appear.

Admins manage:

- product title, category, image, specs, status
- Shopee/Lazada/TikTok Shop/Thai-mart product links
- selected SKU or variant to compare
- featured products and sort order

Backend manages:

- mobile price snapshots
- affiliate URL generation
- click tracking
- commission imports/API sync
- freshness and capture failure status

## Mobile Price Rule

NP Market should display mobile-sourced prices only. Each price row must store its source layer:

- `listing`
- `pdp`
- `selectedVariant`
- `checkout`

Preferred ranking:

```text
checkout > selectedVariant > pdp > listing
```

The UI should always show last updated time because prices can change on the destination platform.

## Suggested Backend Endpoints

```text
GET /app/products
GET /app/products/{id}
POST /app/clicks

GET /admin/products
POST /admin/products
POST /admin/products/{id}/platform-links
POST /admin/platform-links/{id}/refresh-mobile-price
GET /admin/commissions
```

## Next Build Step

Replace `lib/mock_catalog.dart` with an API client once the admin/backend project exists.
