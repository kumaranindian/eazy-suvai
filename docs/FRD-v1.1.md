# EazySuvai – Functional Requirements Document v1.1

Nov 14, 2026 · @Karthikeyan C

## Document control

Version 1.1 closes 18 gaps in v1.0. It defines the suspension and expiry policies, the publishing model, QR stability, currency precision, media rules and data retention, and makes the roadmap consistent. Requirement IDs from v1.0 are unchanged. New requirements continue from FR-091. Changed or new items are tagged **\[v1.1\]**.

| Field | Value |
| --- | --- |
| Product | EazySuvai – Taste Meets Technology |
| Company | AVAIL404 (OPC) Private Limited |
| Version | 1.1 |
| Supersedes | 1.0 (Initial Product Requirements Baseline) |
| Status | Draft for review |
| Target market | Global; India first, then UAE, Kuwait and other markets |

### v1.1 change log

| # | Gap in v1.0 | Resolution in v1.1 | Affected items |
| --- | --- | --- | --- |
| C-01 | Public menu behaviour for suspended or deactivated accounts was undefined | A fixed behaviour for each account status | FR-010, FR-099 |
| C-02 | Subscription expiry policy was undefined | 14-day grace period, then automatic downgrade to the Free plan. The menu stays live | FR-082, FR-100 |
| C-03 | Plan downgrade with content over the new limits was undefined | Over-limit content is hidden by display order, kept, and restored on upgrade | FR-101, BR-011 |
| C-04 | Deleting a category that contains items was undefined | Owner chooses to move the items or delete them, with a count shown. Deleted content can be restored for 30 days | FR-018, FR-097, FR-098 |
| C-05 | Owner of "other dietary labels" was unclear | Platform-managed label lists; restaurants choose from them | FR-023, FR-033, FR-104 |
| C-06 | One or many menus per restaurant was unclear | One menu per restaurant in the MVP; the Menu entity is kept for Phase 2 | §2.1, §8 |
| C-07 | QR codes would break if the slug changed | QR codes encode a permanent short code that redirects to the current slug | FR-047, FR-048, FR-094, BR-006 |
| C-08 | Draft/published model was not defined | Publishing creates an immutable menu version. Availability changes go live immediately | FR-062, FR-095, FR-096 |
| C-09 | Price precision did not cover 3-decimal currencies such as KWD | Prices stored as integers in minor units, using the ISO 4217 exponent | FR-029, §6.2 |
| C-10 | Email verification was in the workflow but not in the FRs | Verification is required before first login | FR-091, §5.1 |
| C-11 | Whether staff accounts are in the MVP was unclear | Role field exists from day one; no staff UI in the MVP | §3.3, §8 |
| C-12 | Phases in §2 and §14 contradicted each other | One phase list, used in both sections | §2, §14 |
| C-13 | Authentication approach was not specified | Security requirements set; the provider is chosen in the Technical Architecture Document | §7.2 |
| C-14 | Image formats, sizes and storage were not specified | Formats, size limits, renditions and CDN delivery defined | FR-032, FR-102, §7.1 |
| C-15 | Slug format and reserved words were not specified | Slug rules, reserved words and redirects for old slugs | FR-092, FR-093 |
| C-16 | Retention and deletion periods were not specified | Periods defined for each data type | BR-013, §7.7 |
| C-17 | How paid plans are paid for in the MVP was unclear | Paid plans are activated manually after offline payment; online billing in Phase 4 | FR-083 |
| C-18 | "Empty menu" was not defined | At least one active category with at least one item | BR-003 |

The decisions behind C-01 to C-18 are defaults chosen for this draft. The appendix lists them for confirmation.

## 1. Product overview

### 1.1 Introduction

EazySuvai is a multi-tenant SaaS platform for food businesses to create, manage and publish digital menus. Customers scan a QR code and see the menu in their phone's browser, with no app to install.

Restaurant owners manage categories, items, descriptions, prices, availability, images and branding from a web dashboard. The first release covers digital menus and QR access only. Ordering, takeaway and delivery come in later phases (§2).

### 1.2 Product vision

Build a globally accessible restaurant technology platform that simplifies how restaurants present their menus and how customers discover their food.

### 1.3 Business objectives

1. Help restaurants replace printed menus with digital menus.
2. Enable customers to open menus through QR codes.
3. Let owners update menu information instantly.
4. Provide restaurant-specific branding and customization.
5. Serve many restaurants from a single SaaS platform.
6. Generate recurring subscription revenue.
7. Expand from digital menus into ordering and restaurant management.

### 1.4 Target customers

- Restaurants and family restaurants
- Cafés and coffee shops
- Hotels and resorts
- Bakeries and dessert shops
- Juice and beverage shops
- Food trucks and food stalls
- Cloud kitchens
- Multi-branch restaurant businesses
- Food courts and dining outlets

## 2. Scope by phase

The product ships in seven phases, Phase 0 to Phase 6. This list is the single source for phase scope, and §14 summarises the same phases. **\[v1.1\]** v1.0 placed payments, KOT and staff management in different phases in §2 and §14. That conflict is resolved below.

### 2.1 Phase 1 – MVP

- Restaurant registration, email verification and authentication
- Restaurant profile management, logo and branding
- One menu per restaurant **\[v1.1\]**
- Menu category and item management
- Food images
- Dietary classification (veg, non-veg, vegan, contains egg) and item tags
- Item availability management, live without republishing **\[v1.1\]**
- Public digital menu with a unique URL
- Permanent restaurant QR code, with PNG and PDF download
- Mobile-responsive customer menu
- Menu preview, publishing and version rollback **\[v1.1\]**
- WhatsApp and URL sharing
- Basic menu view analytics
- Subscription plans with limits; paid plans activated manually by the platform administrator **\[v1.1\]**
- Platform administration and audit log

One owner account per restaurant. Staff accounts are not part of the MVP (§3.3).

### 2.2 Phase 2 – Advanced menus

- Multiple restaurant branches
- Separate QR codes for individual tables
- Multilingual menu content, including Arabic right-to-left layout
- Multiple menus per restaurant and menu scheduling (breakfast, lunch, dinner)
- Item variants and add-ons
- Allergen information **\[v1.1\]**
- Restaurant-defined dietary labels and tags **\[v1.1\]**
- Staff accounts with owner-controlled permissions **\[v1.1\]**
- Mobile number verification by OTP **\[v1.1\]**
- Advanced menu themes and advanced analytics
- Custom domain support
- Menu import and export

### 2.3 Phase 3 – Ordering

- Customer cart, add to cart and quantity management
- Table, takeaway and delivery ordering
- Order placement and restaurant order dashboard
- Kitchen Order Ticket (KOT)
- Order status tracking and notifications
- Customer accounts and order history, where ordering needs them
- Payment at the counter only. Online payment arrives in Phase 4

### 2.4 Phase 4 – Payments

- Online payment gateway integration for orders
- Transaction tracking and refunds
- Online subscription billing for restaurants
- Regional tax configuration for orders and billing

### 2.5 Phase 5 – Restaurant operations

- Multi-branch operations
- Advanced staff roles and workflows
- POS integrations
- Sales reporting and advanced business analytics
- Customer management, loyalty and promotions
- Third-party delivery integrations

### 2.6 Phase 6 – Global expansion

- Additional interface and menu languages
- Market-specific billing, tax and compliance
- Further third-party integrations

**Scope restriction:** ordering and payment processing are not part of the MVP. The MVP data model must allow them to be added without a redesign.

## 3. User roles and access control

The MVP has three active roles: Platform Administrator, Restaurant Owner and Customer. Restaurant Staff exists in the data model but has no interface until Phase 2.

### 3.1 Platform Administrator

An AVAIL404 employee who runs the SaaS platform. Responsibilities:

- View, create, activate, suspend and deactivate restaurant accounts
- Create and update subscription plans; assign, extend and modify subscriptions
- Activate paid plans after offline payment is received **\[v1.1\]**
- Manage global settings, themes, dietary labels and item tags **\[v1.1\]**
- Monitor platform usage and analytics
- View audit logs
- Manage platform-level announcements
- Process data deletion requests **\[v1.1\]**

### 3.2 Restaurant Owner

Has full access to their own restaurant and nothing else. Responsibilities:

- Manage the restaurant profile, logo, cover image and public visibility settings
- Manage categories, items, images, prices, labels and availability
- Customise the menu theme
- Preview, publish and roll back the menu
- Download and share the QR code and menu URL
- View menu analytics
- View the subscription and request plan changes
- Request account and data deletion **\[v1.1\]**

### 3.3 Restaurant Staff **\[v1.1\]**

Not in the MVP interface. The user–restaurant link carries a role field (`OWNER`, `STAFF`) from day one, so staff can be added in Phase 2 without a schema change.

In Phase 2, staff will be able to view the dashboard and update availability. They can manage items only where the owner has granted permission.

### 3.4 Customer / menu visitor

Customers never register or log in to view a menu. They can scan the QR code, browse categories, view images, descriptions, prices and dietary labels, see unavailable items, and share the menu URL. Customer accounts arrive only if ordering requires them (Phase 3).

### 3.5 Permission summary **\[v1.1\]**

| Capability | Platform Admin | Owner | Staff (Phase 2) | Customer |
| --- | --- | --- | --- | --- |
| View published menu | Yes | Yes | Yes | Yes |
| Edit menu content | No | Yes | If permitted | No |
| Toggle item availability | No | Yes | Yes | No |
| Publish or roll back the menu | No | Yes | If permitted | No |
| Edit profile and theme | No | Yes | No | No |
| View own analytics | All tenants | Own | If permitted | No |
| Change subscription | Yes | Request only | No | No |
| Change account status | Yes | No | No | No |
| View audit log | Yes | No | No | No |

The platform administrator does not edit restaurant menu content. A support-assisted edit, if needed later, must be audit-logged.

## 4. Functional requirements

Requirements use "must" for MVP-mandatory behaviour and "should" for behaviour that may slip to a later release without blocking acceptance.

### 4.1 Registration and account

**FR-001:** Restaurant owners must be able to register with an email address and password.

**FR-002:** Registration must collect restaurant name, owner name, email, mobile number, country, business type and password.

**FR-003:** The system must validate email format and validate mobile numbers against the selected country's format. OTP verification of mobile numbers is Phase 2.

**FR-004 \[v1.1\]:** One email address maps to one user account. In the MVP, one user account owns exactly one restaurant. Mobile numbers do not need to be unique.

**FR-005:** The system must support secure login and logout.

**FR-006:** The system must provide password reset by emailed link. The link expires after 60 minutes and works once.

**FR-007:** Each restaurant must receive a unique, non-sequential tenant identifier (UUID).

**FR-008 \[v1.1\]:** Each restaurant must receive a unique slug, generated from the restaurant name at registration (FR-092).

**FR-009:** The platform administrator must be able to manage restaurant account status (FR-099).

**FR-010 \[v1.1\]:** Suspended or deactivated restaurants must not be able to access the administration features. The public menu follows FR-099.

**FR-091 \[v1.1\]:** The owner must verify their email address before first logging in to the dashboard. The verification link expires after 24 hours. A login attempt before verification offers to resend it. Registrations left unverified for 7 days are deleted, releasing the email address and slug.

**FR-092 \[v1.1\]:** Slugs must follow these rules:

- Lowercase letters a–z, digits 0–9 and single hyphens; 3–60 characters; no leading or trailing hyphen
- Generated from the restaurant name. On a collision, the city is appended, then a number (`spice-garden`, `spice-garden-chennai`, `spice-garden-chennai-2`)
- Must not match a reserved word. The platform administrator maintains the list, starting with: `admin`, `api`, `app`, `assets`, `blog`, `dashboard`, `help`, `login`, `logout`, `m`, `pricing`, `privacy`, `q`, `robots.txt`, `signup`, `sitemap.xml`, `static`, `support`, `terms`, `www`, `eazysuvai`, `avail404`

**FR-093 \[v1.1\]:** The owner may change the slug. Every previous slug must permanently redirect (HTTP 301) to the current one for the life of the account. A released slug cannot be claimed by another restaurant for 12 months after the account is deleted.

### 4.2 Restaurant profile

**FR-011:** Owners must be able to create and update their restaurant profile.

| Field | Required | Notes |
| --- | --- | --- |
| Restaurant name | Yes | Up to 80 characters |
| Logo | No | See FR-102 |
| Cover image | No | See FR-102 |
| Description | No | Up to 500 characters |
| Business type | Yes | Restaurant, café, bakery, etc. |
| Contact number | No | Country format |
| Email | No | Public business email |
| Address, city, postal code | No | Country address format |
| Country | Yes | Set at registration |
| Time zone **\[v1.1\]** | Yes | Defaults from country; used for opening hours and analytics |
| Currency | Yes | ISO 4217 code; defaults from country |
| Website | No | Valid https URL |
| Social links | No | Instagram, Facebook, X, YouTube, Google Maps |
| Opening hours | No | Per weekday, up to 3 time slots, or closed |

**FR-012 \[v1.1\]:** Profile and theme changes are saved to the draft and go live on publish, together with menu changes (FR-062).

**FR-013:** Owners must be able to show or hide contact number, email, address, opening hours and social links on the public menu.

**FR-014:** The public menu must show profile information according to those visibility settings.

**FR-103 \[v1.1\]:** Changing the currency after the first publish must show a warning that prices are not converted. The owner must review prices before the next publish.

### 4.3 Menu categories

**FR-015:** Owners must be able to create menu categories, such as Starters, Main Course, Biryani, Desserts, Beverages or Specials.

**FR-016:** Each category has a name (up to 60 characters, required), description (up to 250 characters), optional image, display sequence and active/inactive status.

**FR-017:** Owners must be able to edit categories.

**FR-018 \[v1.1\]:** Deleting an empty category needs a single confirmation. For a category that still has items, the owner must choose one of two options:

1. Move all items to another category, then delete the category.
2. Delete the category and all its items. The dialog shows the item count, and the owner must type the category name to confirm.

**FR-019:** Owners must be able to reorder categories by drag-and-drop, with up/down controls as a keyboard-accessible alternative.

**FR-020:** Inactive categories, and the items in them, must not appear on the public menu.

**FR-021:** A restaurant may have multiple categories, up to its plan limit.

**FR-097 \[v1.1\]:** Items may be moved between categories individually or in bulk.

**FR-098 \[v1.1\]:** Deleted categories and items are soft-deleted. The owner can restore them from a "Recently deleted" list for 30 days, after which they are permanently removed. Restored content returns to the draft, not the live menu.

### 4.4 Menu items

**FR-022:** Owners must be able to create items within categories.

| Field | Required | Notes |
| --- | --- | --- |
| Name | Yes | Up to 80 characters |
| Category | Yes | Must be an existing category (BR-004) |
| Description | No | Up to 500 characters |
| Image | No | One image in the MVP; see FR-102 |
| Price | Yes | Zero or more; minor units (FR-029) |
| Dietary classification | Yes | One value (FR-023) |
| Tags | No | Zero or more (FR-033) |
| Availability | Yes | Defaults to available |
| Display sequence | Yes | Set automatically; owner can reorder |
| Featured | No | Defaults to off |

**FR-023 \[v1.1\]:** Each item must have exactly one dietary classification. It is chosen from a platform-managed list, initially Vegetarian, Non-vegetarian, Vegan and Contains egg. In India the public menu shows the standard veg/non-veg symbol. In every market it also shows a text label, so the meaning never depends on colour alone.

**FR-024:** Owners must be able to edit and delete items. Deletion follows FR-098.

**FR-025:** Owners must be able to mark items available or unavailable. This takes effect live (FR-095).

**FR-026:** Unavailable items must be visually distinguishable on the public menu.

**FR-027:** Owners must be able to mark items as featured.

**FR-028:** Owners must be able to reorder items within a category.

**FR-029 \[v1.1\]:** Prices must be stored as integers in the currency's minor unit, using the ISO 4217 exponent. Examples: INR 2 decimals, KWD 3 decimals. Price entry must accept exactly as many decimals as the currency allows. Floating-point storage is not permitted.

**FR-030:** Prices must be displayed with locale-aware currency formatting (§6.2).

**FR-031:** The system must support image upload, preview, crop and replacement.

**FR-032 \[v1.1\]:** Image validation follows FR-102.

**FR-033 \[v1.1\]:** Items may carry tags from a platform-managed list, initially Spicy, Bestseller, Chef's special and New. Restaurant-defined tags arrive in Phase 2.

**FR-102 \[v1.1\]:** Image rules:

- Accepted formats: JPEG, PNG and WebP. Other files are rejected with a clear message
- Maximum upload size: 5 MB per file
- Minimum dimensions: logo 256 × 256 px; cover 1200 × 400 px; item and category 400 × 400 px
- Metadata, including location (EXIF), is stripped on upload
- The system generates WebP renditions at 320, 640 and 1280 px width and serves them through a CDN
- Originals are kept for regeneration; renditions are what the public menu loads

**FR-104 \[v1.1\]:** The platform administrator manages the dietary classification and tag lists. Each entry has a name, icon, display colour and sort order. Retiring an entry hides it from new selections but keeps it on existing items.

### 4.5 Public digital menu

The public menu is the primary customer-facing feature. URLs in this section use `menu.eazysuvai.com` as a placeholder; the final domain is to be confirmed.

**FR-034:** Every active, published restaurant must have a publicly accessible menu at `https://menu.eazysuvai.com/{slug}`.

**FR-035:** That URL is the canonical URL of the menu.

**FR-036:** Customers must be able to view the menu without registration or login.

**FR-037:** The menu must be fully responsive on Android phones, iPhones, tablets and desktop browsers.

**FR-038:** The public menu must display the restaurant logo, name, cover image (if set), description, enabled contact details, categories, and for each item its image, name, description, price, dietary classification, tags and availability.

**FR-039:** A category navigation bar must stay visible while scrolling and highlight the current category.

**FR-040:** Tapping a category must scroll to it.

**FR-041:** Tapping an item image must open it enlarged, with a close control and swipe-to-dismiss.

**FR-042:** Featured items must be visually highlighted.

**FR-043:** Unavailable items must remain listed but be dimmed and labelled "Currently unavailable".

**FR-044:** The public menu must reflect each publish and each availability change within 60 seconds.

**FR-045:** The menu must expose only the published menu version and the profile fields marked public, never draft or administration data.

**FR-046:** The menu must have loading, empty, error, "coming soon" (not yet published) and unavailable (FR-099) states.

### 4.6 QR codes

**FR-047 \[v1.1\]:** At registration the system generates one permanent QR code per restaurant. It encodes `https://menu.eazysuvai.com/q/{code}`, where `{code}` is an 8-character random code without ambiguous characters (no 0/O, 1/I/L). The code never changes and is never reused.

**FR-048 \[v1.1\]:** The QR URL redirects (HTTP 302) to the restaurant's current canonical menu URL and records a QR-originated visit (FR-071).

**FR-049:** Owners must be able to download the QR code before and after the first publish. Before publish, scanning shows the "coming soon" state.

**FR-050 \[v1.1\]:** Downloads must be offered as PNG (at least 1024 × 1024 px) and print-ready PDF in two templates: an A4 poster and an A6 table card, each showing the restaurant name, logo and "Scan to view our menu".

**FR-051:** The QR code must keep working after any content update, profile change or slug change.

**FR-052:** The QR code must never need regenerating for ordinary updates.

**FR-053 \[v1.1\]:** Owners may add their logo to the centre of the QR code. The code then uses error-correction level H, and the logo covers at most 20% of the area. The system must decode the generated image before offering it, and fall back to the plain code if decoding fails.

**FR-054:** Owners must be able to preview the QR code and templates before downloading.

**FR-094 \[v1.1\]:** Phase 2 table QR codes must use the same short-code mechanism, with one code per table.

### 4.7 Menu customization

**FR-055:** Owners must be able to set primary, secondary and background colours, font (from a supported list), menu layout, card layout, logo, cover image, and light or dark mode.

**FR-056:** The system must provide predefined professional themes. How many a restaurant can use depends on its plan.

**FR-057:** Owners must be able to preview theme changes on mobile and desktop views before publishing.

**FR-058:** Theme settings apply only to the owning restaurant.

**FR-059:** The platform administrator configures which themes and fonts are available.

**FR-060 \[v1.1\]:** Text must meet WCAG 2.1 AA contrast (4.5:1 for body text). If a colour choice fails, the editor warns the owner and adjusts the text colour automatically on the public menu.

### 4.8 Preview and publishing

**FR-061:** Owners must be able to preview the full draft menu, on mobile and desktop views, before publishing.

**FR-062 \[v1.1\]:** The menu has two states:

- **Draft** – the working copy. It holds all content, profile and theme edits, saves automatically, and is visible only in the dashboard and preview.
- **Published version** – an immutable, numbered snapshot that the public menu serves. Publishing creates a new version and switches the live menu to it in one step, so customers never see a partial update (§7.4).

**FR-063:** Owners must be able to publish the draft.

**FR-064:** A published version goes live at the same URL and QR code, with no regeneration.

**FR-065 \[v1.1\]:** Before publishing, the system shows a confirmation with a change summary: categories and items added, changed and removed.

**FR-066 \[v1.1\]:** Publish must be blocked, with each problem listed and linked, when: the menu is empty (BR-003), required fields are missing, or plan limits are exceeded.

**FR-095 \[v1.1\]:** Availability changes are live. Marking an item available or unavailable updates the current published version and the draft at once, without a publish. This lets staff mark items sold out during service.

**FR-096 \[v1.1\]:** The system keeps the last 10 published versions. The owner can roll back to any of them; the rollback is published as a new version, and the draft is replaced after confirmation. The owner can also discard all unpublished draft changes.

### 4.9 Menu sharing

**FR-067:** Owners must be able to copy the menu URL.

**FR-068:** Owners must be able to share the menu to WhatsApp with a prefilled message containing the menu URL.

**FR-069:** Owners must be able to share through the device's native share sheet (Web Share API) where supported.

**FR-070:** Shared links must open the public menu directly and show a rich preview: name, description and cover image (Open Graph, §7.6).

### 4.10 Basic analytics

**FR-071 \[v1.1\]:** Owners must see the following metrics, with these definitions:

| Metric | Definition |
| --- | --- |
| Menu view | A public menu page load, counted once per browser session per 30 minutes |
| QR visit | A menu view that arrived through the `/q/{code}` URL |
| Category interest | Taps on a category in the navigation bar |
| Item interest | Opens of an item's enlarged image or details |

Metrics are shown as totals, a daily chart and monthly totals.

**FR-072:** Analytics are isolated by tenant.

**FR-073:** Known bots and crawlers, identified by user agent and known bot lists, must be excluded.

**FR-074:** Owners must be able to filter by date range: last 7 days, last 30 days, or a custom range limited by the plan.

**FR-075 \[v1.1\]:** Analytics must be cookieless. IP addresses and user-agent strings must not be stored once bot filtering is done. The session identifier must be random and kept only in the browser's session storage. Days are bucketed in the restaurant's time zone.

### 4.11 Subscriptions

**FR-076:** The platform must support configurable subscription plans.

**FR-077:** The platform administrator must be able to create and update plans. Changes to a plan apply to existing subscribers only when explicitly applied.

**FR-078:** Each plan configures: maximum items, maximum categories, maximum branches, available themes, analytics availability and history range, advanced feature flags, and duration.

**\[v1.1\]** MVP plan limits:

| Limit | Free | Pro |
| --- | --- | --- |
| Menu items | 50 | 500 |
| Categories | 10 | Unlimited |
| Branches | 1 | 1 (more in Phase 2) |
| Themes | 2 | All |
| Analytics history | Last 7 days | Last 12 months |
| Logo in QR code | No | Yes |
| Duration | No expiry | Monthly or annual |
| Price | Free | To be set per currency |

**FR-079 \[v1.1\]:** The platform must support free and paid plans. New restaurants start on the Free plan, and the Free plan never expires.

**FR-080:** The system must track subscription start and expiry dates.

**FR-081:** The platform administrator must be able to extend or modify a subscription manually, with a reason that is audit-logged.

**FR-082 \[v1.1\]:** Expiry of a paid plan triggers FR-100.

**FR-083 \[v1.1\]:** Subscription records must hold payment references and the provider name as data, not as provider-specific logic. A payment gateway can then be added in Phase 4 without restructuring.

**FR-100 \[v1.1\]:** Paid plan expiry:

1. The owner gets email and dashboard reminders 14, 7 and 1 days before expiry.
2. On expiry, a grace period starts: 14 days by default, configurable from 0 to 30. Everything keeps working, and the dashboard shows a renewal banner.
3. When the grace period ends, the restaurant is downgraded to the Free plan automatically, and FR-101 applies. The public menu and QR code stay live.

**FR-101 \[v1.1\]:** When a restaurant's limits drop because of a downgrade:

- Content beyond the new limits is marked "Hidden – over plan limit", taking the last items in display order first. It is kept, not deleted.
- A premium theme reverts to the plan's default theme. The custom settings are kept.
- The system publishes a new version without the hidden content.
- While over the limit, the owner cannot add items or categories. They can swap which items are hidden.
- For a downgrade the owner chooses, the owner picks the content to hide before confirming.
- On upgrade, the hidden flags are cleared, and the owner is prompted to publish.

**FR-106 \[v1.1\]:** In the MVP, paid plans are bought offline. The owner requests an upgrade from the dashboard. The platform administrator records the payment (amount, currency, date, method, reference) and activates the plan with its dates. Invoicing happens outside the system until Phase 4.

### 4.12 Platform administration

**FR-084 \[v1.1\]:** The platform administrator must have a separate dashboard, on a separate login route, with mandatory two-factor authentication.

**FR-085:** The dashboard must show total, active, suspended and deactivated restaurants; free, paid, in-grace and expired subscriptions; pending upgrade requests; total menu items; and menu views.

**FR-086:** Administrators must be able to search restaurants by name, slug, email or mobile, and filter by status, plan, country and registration date.

**FR-087:** Administrators must be able to view a restaurant's subscription and payment history.

**FR-088:** Administrators must be able to activate, suspend, deactivate and reactivate accounts, giving a reason each time.

**FR-089:** Administrators must be able to view a restaurant's account activity: logins, publishes and plan changes.

**FR-090:** All sensitive administration actions must be audit-logged (BR-014).

### 4.13 Account status and data **\[v1.1\]**

**FR-099:** Each account status determines what the owner and the public see:

| Status | Owner access | Public menu and QR | HTTP | Search engines |
| --- | --- | --- | --- | --- |
| Active, published | Full | Live menu | 200 | Indexed |
| Active, never published | Full | "Coming soon" page | 404 | Not indexed |
| Active, in grace period | Full, with renewal banner | Live menu | 200 | Indexed |
| Suspended (temporary, by admin) | Blocked; login shows a notice and support contact | "Menu temporarily unavailable" page, with restaurant name only | 503 | Not indexed |
| Deactivated (closed, pending deletion) | Blocked; can be reactivated within 90 days | "Menu no longer available" page | 410 | Removed from sitemap |
| Deleted | None | "Menu no longer available" page; slug held for 12 months | 410 | Removed |

**FR-105:** An owner can request deletion of their account from the dashboard. The account is deactivated at once and deleted after the retention period (§7.7). The owner can export their menu as a JSON or CSV file before deletion.

## 5. User workflows

### 5.1 Restaurant onboarding **\[v1.1\]**

1. The owner opens the EazySuvai website and selects Sign up.
2. Enters owner and restaurant details. The account is created on the Free plan, with a slug and a permanent QR code.
3. Opens the verification email and confirms the address. The dashboard is available only after this step.
4. Logs in and completes the restaurant profile, including the logo.
5. Creates categories and adds items.
6. Selects a theme.
7. Previews the menu.
8. Publishes the menu after reviewing the change summary.
9. Downloads the QR code as a PNG or a print template.
10. Places the QR code in the restaurant and shares the link on WhatsApp.

### 5.2 Customer menu access

1. The customer scans the QR code at the restaurant.
2. The browser follows the short URL to the menu.
3. The customer sees the restaurant information.
4. The customer browses categories, dishes, descriptions, prices and dietary labels.
5. Unavailable dishes are visible but marked.

No app installation or registration is needed.

### 5.3 Menu update **\[v1.1\]**

1. The owner logs in and opens Menu management.
2. Edits prices, images, descriptions or items. Changes save to the draft automatically.
3. Previews the draft.
4. Publishes and confirms the change summary.
5. Customers see the new version through the same QR code within 60 seconds.

### 5.4 Marking an item sold out **\[v1.1\]**

1. The owner opens the item list on their phone.
2. Switches the item to unavailable.
3. The public menu shows it as unavailable within 60 seconds. No publish is needed.

### 5.5 Paid plan upgrade (MVP) **\[v1.1\]**

1. The owner requests a plan from the dashboard.
2. AVAIL404 sends payment details and receives payment offline.
3. The platform administrator records the payment and activates the plan.
4. The owner receives an email confirmation, and the new limits apply immediately.

## 6. Globalization

EazySuvai launches in India with English only. Currency, time zone, number formats and text direction must be data-driven from day one, so that adding UAE, Kuwait and other markets needs no code change.

### 6.1 Country support

No India-specific assumption may be hardcoded. Supported at launch or in early expansion: India, United Arab Emirates, Kuwait, Saudi Arabia, Qatar and other markets. Each country carries its default currency, time zone, phone format and address format as configuration.

### 6.2 Currency **\[v1.1\]**

Currencies are identified by ISO 4217 code. Each has a minor-unit exponent that sets how prices are stored and entered (FR-029).

| Currency | Code | Decimals | Example display |
| --- | --- | --- | --- |
| Indian Rupee | INR | 2 | ₹1,25,000.50 |
| UAE Dirham | AED | 2 | AED 45.00 |
| Kuwaiti Dinar | KWD | 3 | KWD 1.250 |
| Saudi Riyal | SAR | 2 | SAR 30.00 |
| Qatari Riyal | QAR | 2 | QAR 30.00 |
| Bahraini Dinar | BHD | 3 | BHD 2.500 |
| Omani Rial | OMR | 3 | OMR 2.500 |
| US Dollar | USD | 2 | $12.99 |

Formatting (symbol, separators, digit grouping) follows the CLDR rules for the restaurant's locale. A menu has one currency; multi-currency display is out of scope.

### 6.3 Language

The initial language is English for both the dashboard and the public menu. Future languages: Tamil, Hindi, Arabic, Malayalam, Telugu, Kannada, French and others as configured.

- All interface text must come from translation files, never hardcoded strings.
- All text is stored and served as UTF-8. Restaurants may enter names in any script from day one.
- Layouts must use direction-neutral CSS (logical properties) so that Arabic right-to-left layout needs no redesign.
- Translated menu content is stored in a separate Translation entity, keyed by record, field and locale. It must not be stored as duplicate menu items.

### 6.4 Regional configuration

The platform must handle country-specific phone and address formats, restaurant time zones (stored as IANA names such as `Asia/Kolkata`), locale-specific date and time formats, currency formatting, and – from Phase 4 – regional tax configuration. All timestamps are stored in UTC and shown in the restaurant's time zone.

## 7. Non-functional requirements

**\[v1.1\]** v1.0 stated these qualitatively. v1.1 adds measurable targets. Targets marked "indicative" are to be confirmed in the Technical Architecture Document.

### 7.1 Performance

| Requirement | Target |
| --- | --- |
| Public menu Largest Contentful Paint, mobile 4G, 75th percentile | ≤ 2.5 s |
| Public menu initial payload (HTML, CSS, JS, gzipped, excluding images) | ≤ 150 KB |
| Item images | Lazy-loaded WebP renditions sized to the screen (FR-102) |
| Published menu delivery | Cached at the CDN edge; purged within 60 s of a publish or availability change |
| Dashboard API response, 95th percentile | ≤ 500 ms |

Public menu pages must also work acceptably on 3G and low-end Android devices.

### 7.2 Security **\[v1.1\]**

The identity provider or framework is chosen in the Technical Architecture Document. Whatever is chosen must meet these requirements:

- Passwords: minimum 8 characters, checked against a known-breached-password list, and stored only as a slow hash (Argon2id, or bcrypt at cost 12 or higher)
- Login protection: after 5 failed attempts within 15 minutes, the account is locked for 15 minutes or a CAPTCHA is required
- Sessions: short-lived access tokens (15 minutes or less) and refresh tokens (30 days or less), all revoked on logout and password change
- Two-factor authentication is mandatory for platform administrators
- Role-based access control on every API, checked on the server
- Tenant isolation enforced in two layers: application queries scoped by tenant ID, plus a database-level control such as row-level security
- Public menus are served from a separate domain from the dashboard, and no authentication cookies are sent to it
- Uploaded images are type-checked by content, not just by extension, and re-encoded before storage
- HTTPS only, TLS 1.2 or later, with HSTS
- Protection against the OWASP Top 10, with input validation on every endpoint
- Audit logging of sensitive operations (BR-014)

### 7.3 Scalability (indicative)

- Designed for 10,000 restaurants with up to 500 items each
- 200 public menu requests per second at peak, mostly served from the CDN
- Stateless backend services that can scale horizontally
- Data model ready for branches (Phase 2) and orders (Phase 3)

### 7.4 Availability and reliability

| Requirement | Target |
| --- | --- |
| Public menu availability | 99.9% monthly |
| Dashboard availability | 99.5% monthly |
| Recovery point objective (maximum data loss) | 1 hour |
| Recovery time objective (maximum downtime) | 4 hours |
| Backups | Daily full, continuous point-in-time recovery, 35-day retention; restore tested every quarter |

- Dashboard activity, including publishing, must never interrupt the live public menu.
- Publishing switches versions in one step (FR-062).
- Errors are logged centrally, with alerts on public menu error rates and downtime.
- If the backend is unavailable, the CDN keeps serving the last published menu.

### 7.5 Usability

- Mobile-first customer menu
- The owner dashboard must be fully usable on a phone, since many owners manage menus from one
- Target: a new owner publishes a 30-item menu within 20 minutes, with no training
- Public menu meets WCAG 2.1 AA
- Consistent components across all dashboard screens

### 7.6 SEO

- Search-friendly slug URLs (FR-092) with canonical tags
- Unique page title and meta description per restaurant
- Open Graph and Twitter card metadata for link previews
- schema.org `Restaurant` and `Menu` structured data (JSON-LD)
- A sitemap that lists active, published menus only
- `noindex` on preview, "coming soon" and unavailable pages

### 7.7 Data retention **\[v1.1\]**

| Data | Retention |
| --- | --- |
| Soft-deleted categories and items | 30 days, then purged |
| Published menu versions | Last 10 kept |
| Deactivated account (all tenant data, including images) | 90 days, then purged |
| Raw analytics events | 90 days |
| Daily analytics totals | Life of the account |
| Audit logs | 2 years; kept after account deletion with personal data removed |
| Subscription payment records | As required by tax and accounting law (8 years in India) |
| Backups | 35 days rolling; purged data leaves backups within that window |

These periods need legal review against India's Digital Personal Data Protection Act, 2023 and the data protection laws of each GCC launch market.

## 8. Data entities and isolation

**\[v1.1\]** v1.1 adds seven entities, needed for versioned publishing, permanent QR codes, slug redirects, managed labels and offline payments.

| Entity | Purpose | Status |
| --- | --- | --- |
| PlatformUser | Platform administrator accounts | MVP |
| Restaurant | Tenant: profile, status, slug, currency, time zone | MVP |
| RestaurantUser | Links a user to a restaurant with a role (`OWNER`, `STAFF`) | MVP; owner only |
| SubscriptionPlan | Plans and their limits | MVP |
| RestaurantSubscription | A restaurant's plan, dates, grace period and status | MVP |
| PaymentRecord **\[v1.1\]** | Offline (later gateway) payments: amount, currency, method, reference | MVP |
| UpgradeRequest **\[v1.1\]** | Owner requests for plan changes | MVP |
| Menu | Menu container. One per restaurant in the MVP; several in Phase 2 | MVP |
| MenuCategory | Category, sequence, status, soft-delete date | MVP |
| MenuItem | Item, price in minor units, availability, sequence, over-limit flag, soft-delete date | MVP |
| MenuItemImage | Image original and renditions | MVP |
| DietaryLabel **\[v1.1\]** | Platform-managed dietary classifications | MVP |
| ItemTag **\[v1.1\]** | Platform-managed tags; restaurant-defined in Phase 2 | MVP |
| MenuTheme | Theme definitions and each restaurant's settings | MVP |
| MenuVersion **\[v1.1\]** | Immutable published snapshot of menu, profile and theme | MVP |
| QRCode | Permanent short code mapped to a restaurant (later, a table) | MVP |
| SlugHistory **\[v1.1\]** | Previous slugs, kept for redirects and reservation | MVP |
| MenuAnalytics | Raw events (90 days) and daily totals | MVP |
| AuditLog | Administrative and sensitive activity | MVP |
| RestaurantBranch | Branches | Phase 2 |
| Translation | Localized content by record, field and locale | Phase 2 |

### Data isolation

- Every restaurant-owned record carries the tenant ID.
- Isolation is enforced in the backend and at the database layer (§7.2).
- A restaurant can never read or change another restaurant's private data.
- The public menu reads only from the current MenuVersion and public profile fields, never from draft tables.

## 9. Business rules

| ID | Rule |
| --- | --- |
| BR-001 | Every restaurant has a unique tenant identifier. |
| BR-002 | Every restaurant has a unique public menu URL (slug). |
| BR-003 **\[v1.1\]** | A menu cannot be published unless it has at least one active category containing at least one item. |
| BR-004 | Every item belongs to an existing, non-deleted category. |
| BR-005 | A restaurant owner can manage only their own restaurant's data. |
| BR-006 **\[v1.1\]** | A restaurant's QR short code never changes, even if the content or slug changes, and is never reused. |
| BR-007 **\[v1.1\]** | Only restaurants with status Active and at least one published version serve a live menu. All other states follow FR-099. |
| BR-008 | Inactive categories, hidden over-limit content and draft content never appear publicly. |
| BR-009 | Unavailable items are distinguishable from available items. |
| BR-010 | Prices are shown in the restaurant's configured currency. |
| BR-011 **\[v1.1\]** | Plan limits are enforced by backend services, on create and on publish. Over-limit handling follows FR-101. |
| BR-012 | One restaurant's theme never affects another tenant. |
| BR-013 **\[v1.1\]** | Deletion and retention follow §7.7. |
| BR-014 | Administrative changes are recorded in the audit log. |
| BR-015 | Public menu access never requires customer authentication. |
| BR-016 **\[v1.1\]** | A menu has exactly one currency. |
| BR-017 **\[v1.1\]** | In the MVP, one user account owns exactly one restaurant. |
| BR-018 **\[v1.1\]** | Availability changes go live without a publish. All other content changes need a publish. |
| BR-019 **\[v1.1\]** | Prices are stored as integers in minor units, never as floating-point numbers. |

## 10. MVP acceptance criteria

The MVP is functionally complete when all 30 scenarios below pass. AC-021 to AC-030 are new in v1.1.

| ID | Acceptance criterion |
| --- | --- |
| AC-001 | An owner can register, verify their email, log in, log out and reset their password. |
| AC-002 | An owner can create and update a restaurant profile, and show or hide public fields. |
| AC-003 | An owner can create, update, reorder and delete categories. |
| AC-004 | An owner can create, update, reorder and delete items. |
| AC-005 | Images in JPEG, PNG and WebP up to 5 MB upload and display; other files are rejected. |
| AC-006 | Vegetarian, Non-vegetarian, Vegan and Contains egg classifications display with icon and text. |
| AC-007 | An availability change appears on the public menu within 60 s, without a publish. |
| AC-008 | The public menu opens without login. |
| AC-009 | The menu works on Android, iPhone, tablet and desktop browsers. |
| AC-010 | The QR code downloads as PNG and as both PDF templates, and scans correctly. |
| AC-011 | The QR code keeps working after content updates and after a slug change. |
| AC-012 | Restaurant branding and theme show on the public menu. |
| AC-013 | An owner can preview, publish with a change summary, and roll back to a previous version. |
| AC-014 | The menu can be shared to WhatsApp and through the native share sheet. |
| AC-015 | Menu views, QR visits and item interest are shown, with a date filter. |
| AC-016 | The platform administrator can activate, suspend, deactivate and reactivate accounts. |
| AC-017 | Automated tests confirm no API returns or changes another tenant's data. |
| AC-018 | Plan limits are enforced on create and on publish. |
| AC-019 | Public menus have a title, meta description, Open Graph tags, JSON-LD and a sitemap entry. |
| AC-020 | No ordering functionality is required for MVP acceptance. |
| AC-021 | An unverified owner cannot log in. Publishing is blocked, with clear reasons, for an empty menu or exceeded plan limits. |
| AC-022 | Customers never see a partially published menu during a publish. |
| AC-023 | An old slug redirects to the current slug with HTTP 301. |
| AC-024 | Suspended, deactivated and unpublished restaurants show the pages and HTTP codes in FR-099. |
| AC-025 | A paid plan in grace keeps working; after grace, it downgrades to Free and hides over-limit content without deleting it. |
| AC-026 | Upgrading restores hidden content to the draft. |
| AC-027 | Deleting a category that has items requires moving them or confirming their deletion. |
| AC-028 | Deleted items can be restored within 30 days. |
| AC-029 | A KWD restaurant can enter and display prices with 3 decimals. |
| AC-030 | A platform administrator can record an offline payment and activate a paid plan, and the action is audit-logged. |

## 11. Out of scope for the MVP

None of the following may delay the first release:

- Shopping cart, online ordering and kitchen order management
- Online payments, including online subscription billing **\[v1.1\]**
- POS and delivery-partner integrations
- Customer accounts, reviews, loyalty programs and reservations
- Inventory management, advanced CRM and automated marketing
- Staff accounts **\[v1.1\]**
- Multiple menus per restaurant, branches and table-level QR codes **\[v1.1\]**
- Allergen information and restaurant-defined labels **\[v1.1\]**
- Mobile OTP verification **\[v1.1\]**
- Languages other than English

Each of these belongs to a later phase (§2).

## 12. Application modules

1. Authentication and Authorization
2. Restaurant Onboarding
3. Restaurant Profile
4. Menu Management
5. Category Management
6. Food Item Management
7. Media Management
8. QR Code Management
9. Public Digital Menu
10. Menu Customization
11. Menu Publishing and Versioning **\[v1.1\]**
12. Analytics
13. Subscription Management
14. Platform Administration
15. Audit and Monitoring
16. Account and Data Lifecycle **\[v1.1\]** – status changes, deletion, retention and export

## 13. Success metrics

- Registered, activated (first publish) and monthly active restaurants
- Published menus and downloaded QR codes
- Median time from sign-up to first publish **\[v1.1\]**
- Monthly public menu views and QR visits
- Free-to-paid conversion and subscription renewal rates
- Restaurant churn rate
- Average items per restaurant
- Support requests per restaurant

## 14. Roadmap

**\[v1.1\]** This table matches §2 exactly.

| Phase | Release | Major capabilities |
| --- | --- | --- |
| 0 | Foundation | Requirements, design, technical architecture |
| 1 | MVP | Digital menu, QR code, publishing, basic analytics, subscription plans with manual activation |
| 2 | Advanced menus | Branches, table QR codes, multilingual and RTL, multiple menus and scheduling, variants and add-ons, allergens, staff accounts, custom domain |
| 3 | Ordering | Cart, table, takeaway and delivery orders, KOT, order dashboard, notifications; payment at the counter |
| 4 | Payments | Online payment for orders, transactions and refunds, online subscription billing, tax configuration |
| 5 | Restaurant operations | POS integration, advanced staff roles, sales reporting, CRM, loyalty, delivery integrations |
| 6 | Global expansion | More languages, market-specific billing and compliance, further integrations |

## 15. Product definition

EazySuvai is a global-ready, multi-tenant restaurant SaaS platform. It starts with digital menu management and QR-based customer access, then expands into online ordering and restaurant operations.

|  |  |
| --- | --- |
| Brand | EazySuvai |
| Meaning | From the Tamil word Suvai (சுவை), meaning taste or flavour |
| Tagline | Taste Meets Technology. |
| Descriptor | Digital Menu & Food Ordering Platform |
| Company | AVAIL404 (OPC) Private Limited |

**Value proposition:** EazySuvai helps restaurants create beautiful digital menus, connect with customers through QR codes and simplify food ordering through a single platform.

## Appendix A – Decisions to confirm

These 16 defaults were chosen to close the v1.0 gaps. Set each row to Accepted or Changed. Pro plan prices are still to be set.

| # | Decision | v1.1 default | Ref | Status |
| --- | --- | --- | --- | --- |
| 1 | Public menu domain | `menu.eazysuvai.com` (placeholder) | FR-034 | Accepted |
| 2 | Paid plan expiry | 14-day grace, then automatic downgrade to Free; menu stays live | FR-100 | Accepted |
| 3 | Over-limit content after downgrade | Hidden, last in display order first; restored on upgrade | FR-101 | Accepted |
| 4 | Public menu when suspended | "Temporarily unavailable" page, HTTP 503 | FR-099 | Accepted |
| 5 | Email verification | Required before first login | FR-091 | Changed |
| 6 | Availability changes | Live immediately, no publish | FR-095 | Accepted |
| 7 | Version history | Last 10 versions, with rollback | FR-096 | Accepted |
| 8 | Category deletion | Move items, or delete with typed confirmation; 30-day restore | FR-018, FR-098 | Accepted |
| 9 | Dietary classifications | Vegetarian, Non-vegetarian, Vegan, Contains egg | FR-023 | Accepted |
| 10 | Staff accounts | Phase 2; role field exists in the MVP | §3.3 | Accepted |
| 11 | Paid plans in the MVP | Offline payment, manual activation by admin | FR-106 | Accepted |
| 12 | Default plan | New restaurants start on Free; Free never expires | FR-079 | Accepted |
| 13 | Admin login | Two-factor authentication mandatory | FR-084 | Accepted |
| 14 | Retention periods | 90 days after deactivation; audit logs 2 years; pending legal review | §7.7 | Accepted |
| 15 | Performance and availability targets | Indicative values in §7 | §7 | Accepted |
| 16 | Free and paid plan limits | Free and Pro limits in FR-078; prices to be set | FR-078 | Accepted |
