# Music Festival Manager — Architecture & Developer Guide

This document walks through the architecture and implementation of a Music Festival Manager app built on SAP BTP ABAP Environment using the ABAP RESTful Application Programming Model (RAP).

> Replace `ZPRA_G_MF` and `ZPRA_GIAP_MF` with your own namespace/prefix throughout this guide.

---

## What the App Does

- Create and publish music festivals with capacity and pricing
- Manage visitors independently
- Add visitors to festivals as visits
- Track booking status and available seats automatically
- Artists are flagged separately and don't consume seats
- Cancel visits and retrieve seats back

## Tech Stack

- **SAP BTP ABAP Environment** — cloud ABAP runtime
- **ABAP RAP (managed, draft-enabled)** — transactional framework
- **CDS Views** — data modeling and UI annotations
- **SAP Fiori Elements** — auto-generated UI from annotations
- **Eclipse ADT** — development environment
- **abapGit** — version control to GitHub

---

## Architecture Overview

The app follows the standard RAP layered architecture:

```
[Database Tables]
       ↓
[Base CDS Views]         ← data model, associations, semantics
       ↓
[Projection CDS Views]   ← UI-facing layer, value helps, redirections
       ↓
[Behavior Definition]    ← declares operations (CRUD, actions, determinations, validations)
       ↓
[Behavior Implementation]← ABAP class with actual business logic
       ↓
[Service Definition]     ← exposes entities as OData service
       ↓
[Service Binding]        ← binds to OData V4 protocol
       ↓
[Metadata Extensions]    ← UI annotations (labels, layout, facets)
       ↓
[SAP Fiori Elements UI]  ← auto-generated from annotations
```

There are two independent business objects in this app:

- **MusicFestival** — root entity, parent of Visit
- **Visitor** — standalone root entity

They are connected through the **Visit** entity, which is a child of MusicFestival and holds a reference to Visitor via UUID.

---

## Step 1: Data Layer

The data layer is the foundation of the app. Before creating any CDS views or behavior, you need to define your data types and persistent storage.

### Domains

A domain defines the technical type and allowed value range of a field. In this app we have two status domains.

**Festival Status** (`ZPRA_GIAP_MF_STATUS_CODE`) — `CHAR(1)`:

| Fixed Value | Description |
|---|---|
| `I` | In-Preparation |
| `P` | Published |
| `C` | Canceled |
| `F` | Fully Booked |

**Visit Status** (`ZPRA_GIAP_MF_VISIT_STATUS_CODE`) — `CHAR(1)`:

| Fixed Value | Description |
|---|---|
| `B` | Booked |
| `C` | Canceled |

> One common gotcha — you cannot assign a domain directly to a database table field. You need a **Data Element** in between. The data element references the domain, and the table field references the data element.

### Data Elements

A data element is a semantic layer on top of a domain (or a direct type). It provides meaningful field labels for the UI and connects the domain to the table field.

To create a data element in Eclipse ADT:

1. Right-click on your package → **New > Other ABAP Repository Object > Data Element**
2. Enter name and description
3. Set the category, data type, and field labels
4. Assign to a transport request and finish

Here are all the data elements used in this app:

| Data Element | Type | Length | Label |
|---|---|---|---|
| `ZPRA_GIAP_MF_CURRENCY_CODE` | CUKY | 5 | Currency |
| `ZPRA_GIAP_MF_DESCRIPTION` | String | 512 | Description |
| `ZPRA_GIAP_MF_EMAIL` | CHAR | 255 | Email |
| `ZPRA_GIAP_MF_FREE_SEATS` | INT4 | 10 | Available Seats |
| `ZPRA_GIAP_MF_MAX_VISITORS_NUM` | INT4 | 10 | Max Number of Visitors |
| `ZPRA_GIAP_MF_NAME` | CHAR | 255 | Name |
| `ZPRA_GIAP_MF_DATE_TIME` | UTCLONG | 27 | Event Date |
| `ZPRA_GIAP_MF_PRICE` | DEC | 6,2 | Price |
| `ZPRA_GIAP_MF_PROJ_NAME` | CHAR | 30 | Project Name |
| `ZPRA_GIAP_MF_TITLE` | CHAR | 255 | Title |
| `ZPRA_GIAP_MF_ARTIST_INDICATOR` | ABAP_BOOLEAN | 1 | Artist |
| `ZPRA_GIAP_MF_STATUS_CODE_DE` | Domain ref | - | Event Status |
| `ZPRA_GIAP_MF_VISIT_STATUS_DE` | Domain ref | - | Visit Status |

> `ZPRA_GIAP_MF_STATUS_CODE_DE` and `ZPRA_GIAP_MF_VISIT_STATUS_DE` reference domains rather than predefined types — this is what enables the fixed value descriptions (In-Preparation, Published, etc.) to resolve automatically in the UI.

### Database Tables

There are three persistent tables in this app.

**`zpra_g_mf_a_mf`** — stores music festival data:

```abap
@EndUserText.label : 'Music festivals data'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zpra_g_mf_a_mf {
  key client            : abap.clnt not null;
  key uuid              : sysuuid_x16 not null;
  title                 : zpra_giap_mf_title;
  description           : zpra_giap_mf_description;
  event_date_time       : zpra_giap_mf_date_time;
  max_visitors_number   : zpra_giap_mf_max_visitors_num;
  free_visitor_seats    : zpra_giap_mf_free_seats;
  visitors_fee_amount   : zpra_giap_mf_price;
  visitors_fee_currency : zpra_giap_mf_currency_code;
  status                : zpra_giap_mf_status_code_de;
  created_by            : abp_creation_user;
  created_at            : abp_creation_utcl;
  last_changed_at       : abp_lastchange_utcl;
  local_last_changed_at : abp_lastchange_utcl;
  last_changed_by       : abp_lastchange_user;
  project_id            : abap.char(24);
}
```

**`zpra_g_mf_a_vstr`** — stores visitor data:

```abap
@EndUserText.label : 'Visitors data'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zpra_g_mf_a_vstr {
  key client            : abap.clnt not null;
  key uuid              : sysuuid_x16 not null;
  name                  : zpra_giap_mf_name;
  email                 : zpra_giap_mf_email;
  created_by            : abp_creation_user;
  created_at            : abp_creation_utcl;
  last_changed_at       : abp_lastchange_utcl;
  last_changed_by       : abp_lastchange_user;
  local_last_changed_at : abp_lastchange_utcl;
}
```

**`zpra_g_mf_a_vst`** — the link between festivals and visitors:

```abap
@EndUserText.label : 'Visits data'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zpra_g_mf_a_vst {
  key client            : abap.clnt not null;
  key uuid              : sysuuid_x16 not null;
  parent_uuid           : sysuuid_x16;
  visitor_uuid          : sysuuid_x16;
  artist_indicator      : zpra_giap_mf_artist_indicator;
  status                : zpra_giap_mf_visit_status_de;
  local_last_changed_at : abp_lastchange_utcl;
}
```

`parent_uuid` in the Visit table points to the festival UUID, and `visitor_uuid` points to the visitor UUID. The three entities are connected at the database level through UUID references — no foreign key constraints. These references are resolved later at the CDS layer through associations.

The system fields (`abp_creation_user`, `abp_creation_utcl`, `abp_lastchange_utcl`) are standard RAP administrative fields that get auto-populated by the framework when annotated with the correct `@Semantics` annotations in the CDS view.

---

## Step 2: Generate RAP Objects Using ADT Wizard

After creating the database tables, use the **ADT generator wizard** to automatically generate all the boilerplate RAP artifacts — CDS views, behavior definition, service definition, and service binding — in one shot.

> 💡 Generate for **MusicFestival** and **Visitor** tables only. We will manually create and customize the Visit artifacts since it has a more complex structure (child node, associations to both parents).

> ⚠️ The object names below use `ZPRA_G_MF` as the sample prefix. Replace `G_MF` with your own identifier throughout — for example `ZPRA_*_R_MUSICFESTIVAL` where `*` is your identifier.

### How to Generate

1. In Eclipse ADT, right-click on your database table (e.g. `zpra_g_mf_a_mf`)
2. Choose **Generate ABAP Repository Objects**
3. Select **OData UI Service** and choose **Next**
4. Review the list of objects that will be generated
5. Adjust the names to match your naming convention
6. Choose **Next**, assign a transport request, and **Finish**

Repeat the same for the Visitor table.

### What Gets Generated

After generation you should have these objects for each entity:

| Object | Type | Description |
|---|---|---|
| `ZPRA_*_R_MUSICFESTIVAL` | Data Definition | Base CDS view |
| `ZPRA_*_C_MUSICFESTIVALTP` | Data Definition | Projection CDS view |
| `ZPRA_*_C_MUSICFESTIVALTP` | Metadata Extension | UI annotations |
| `ZPRA_*_R_MUSICFESTIVAL` | Behavior Definition | Root behavior |
| `ZPRA_*_C_MUSICFESTIVALTP` | Behavior Definition | Projection behavior |
| `ZBP_*_R_MUSICFESTIVAL` | Class | Behavior implementation |
| `ZPRA_*_MUSICFESTIVAL` | Service Definition | OData service scope |
| `ZPRA_*_UI_MUSICFESTIVAL_O4` | Service Binding | OData V4 binding |

And similarly for Visitor:

| Object | Type | Description |
|---|---|---|
| `ZPRA_*_R_VISITOR` | Data Definition | Base CDS view |
| `ZPRA_*_C_VISITORTP` | Data Definition | Projection CDS view |
| `ZPRA_*_C_VISITORTP` | Metadata Extension | UI annotations |
| `ZPRA_*_R_VISITOR` | Behavior Definition | Root behavior |
| `ZPRA_*_C_VISITORTP` | Behavior Definition | Projection behavior |
| `ZBP_*_R_VISITOR` | Class | Behavior implementation |
| `ZPRA_*_VISITOR` | Service Definition | OData service scope |
| `ZPRA_*_UI_VISITOR_O4` | Service Binding | OData V4 binding |

### Visit — Manual Creation

The Visit entity is **not generated** — it is created manually and added as a child node of MusicFestival. Here is what needs to be created:

| Object | Type | Description |
|---|---|---|
| `ZPRA_*_R_VISIT` | Data Definition | Base CDS view |
| `ZPRA_*_C_VISITTP` | Data Definition | Projection CDS view |
| `ZPRA_*_C_VISITTP` | Metadata Extension | UI annotations |

The behavior definition and implementation class for Visit are **not separate** — they live inside the MusicFestival behavior definition and implementation class since Visit is a child node of MusicFestival.

> ⚠️ The generated code is a starting point — most of it will need to be customized. The sections below explain what was changed and why.

---

## Step 3: CDS Layer — Base Views

Once the tables are ready, the next step is to build the CDS base views. These are the **interface views** — they sit directly on top of the database tables and define the data model, associations, and semantic annotations.

In RAP, base views are typically prefixed with `R` (for "root" or "read"). They are not exposed directly to the UI — that's the projection layer's job.

### The Three Base Views

**`ZPRA_G_MF_R_MUSICFESTIVAL`** — root view for Music Festival:

```abap
define root view entity ZPRA_G_MF_R_MUSICFESTIVAL
  as select from zpra_g_mf_a_mf as MusicFestivals
  composition [0..*] of ZPRA_G_MF_R_VISIT as _Visit
  association [1..1] to ZPRA_G_MF_I_MF_STATUS_VH as _Status
    on $projection.Status = _Status.Value
{
  key uuid                  as UUID,
  title                     as Title,
  ...
  status                    as Status,
  @Semantics.user.createdBy: true
  created_by                as CreatedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at           as LastChangedAt,
  ...
  _Visit,
  _Status
}
```

**`ZPRA_G_MF_R_VISIT`** — child view, links festival to visitor:

```abap
define view entity ZPRA_G_MF_R_VISIT
  as select from zpra_g_mf_a_vst
  association to parent ZPRA_G_MF_R_MUSICFESTIVAL as _MusicFestival
    on $projection.ParentUuid = _MusicFestival.UUID
  association [1..1] to ZPRA_G_MF_R_VISITOR as _Visitor
    on $projection.VisitorUuid = _Visitor.UUID
  association [1..1] to ZPRA_G_MF_I_VISIT_STATUS_VH as _VisitStatus
    on $projection.Status = _VisitStatus.Value
{
  key uuid              as Uuid,
  parent_uuid           as ParentUuid,
  visitor_uuid          as VisitorUuid,
  artist_indicator      as ArtistIndicator,
  status                as Status,
  local_last_changed_at as LocalLastChangedAt,
  _MusicFestival,
  _Visitor,
  _VisitStatus
}
```

**`ZPRA_G_MF_R_VISITOR`** — root view for Visitor:

```abap
define root view entity ZPRA_G_MF_R_VISITOR
  as select from zpra_g_mf_a_vstr as Visitors
  association [0..*] to ZPRA_G_MF_R_VISIT as _Visits
    on $projection.UUID = _Visits.VisitorUuid
{
  @ObjectModel.text.element: ['Name']
  key uuid  as UUID,
  @Semantics.text: true
  name      as Name,
  email     as Email,
  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  ...
  _Visits
}
```

### Key Concepts in This Layer

**Composition vs Association**

The relationship between MusicFestival and Visit is a `composition` — Visit is a child node of MusicFestival and cannot exist without it. This is what makes MusicFestival the **root** of the business object tree.

The relationship between Visit and Visitor is a regular `association` — Visitor is an independent entity that exists on its own.

```
MusicFestival (root)
    └── Visit (child via composition)
            └──> Visitor (independent, via association)
```

**Semantic Annotations**

Fields like `created_by`, `created_at`, and `last_changed_at` are annotated with `@Semantics` tags. These tell the RAP framework to auto-populate them — you don't need to write any code for this.

```abap
@Semantics.user.createdBy: true
created_by as CreatedBy,

@Semantics.systemDateTime.createdAt: true
created_at as CreatedAt,
```

**Status Value Help Views**

Both `_Status` and `_VisitStatus` associations point to value help views (`ZPRA_G_MF_I_MF_STATUS_VH` and `ZPRA_G_MF_I_VISIT_STATUS_VH`). These views read from `DDCDS_CUSTOMER_DOMAIN_VALUE` — a standard SAP view that resolves domain fixed values into human-readable descriptions at runtime. This is how `I` becomes `In-Preparation` in the UI without any hardcoding.

```abap
association [1..1] to ZPRA_G_MF_I_MF_STATUS_VH as _Status
    on $projection.Status = _Status.Value
```
---

### Value Help Views

Value help views are helper CDS views that power dropdowns and search helps in the UI. There are three in this app.

**Status Value Help Views**

Both `ZPRA_G_MF_I_MF_STATUS_VH` and `ZPRA_G_MF_I_VISIT_STATUS_VH` follow the same pattern — they read directly from `DDCDS_CUSTOMER_DOMAIN_VALUE`, a standard SAP view that resolves domain fixed values into descriptions at runtime. This means you don't need to hardcode any status texts anywhere.

```abap
define view entity ZPRA_G_MF_I_MF_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE( p_domain_name : 'ZPRA_GIAP_MF_STATUS_CODE' ) as Value
  association [0..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _text
    on  Value.domain_name    = _text.domain_name
    and Value.value_position = _text.value_position
    and _text.language       = $session.system_language
{
      @UI.hidden: true
  key Value.domain_name     as Name,
      @UI.hidden: true
  key Value.value_position  as ValuePosition,
      Value.value_low       as Value,
      _text( p_domain_name : 'ZPRA_GIAP_MF_STATUS_CODE' ).text as Description
}
```

When the base view joins to this via `_Status` association, the description (`In-Preparation`, `Published`, etc.) becomes available in the projection layer through `_Status.Description as StatusText`.

> 💡 The same pattern is reused for visit status — just change the `p_domain_name` parameter to point to the visit status domain.

**Visitor Value Help**

`ZPRA_G_MF_I_VISITOR` is a simple view on top of the visitor table. It is used as the search help when adding a visitor to a festival — the user can search by name.

```abap
define view entity ZPRA_G_MF_I_VISITOR
  as select from zpra_g_mf_a_vstr
{
  @ObjectModel.text.element: ['Name']
  key uuid  as Uuid,
  @Search.defaultSearchElement: true
  @Semantics.text: true
  name      as Name,
  email     as Email
}
```

`@Search.searchable: true` on the view and `@Search.defaultSearchElement: true` on the `name` field enable full-text search in the value help popup. `@Semantics.text: true` tells the framework that `Name` is the display text for the `Uuid` key.

It is referenced in the Metadata Extension of the Visit projection:

```abap
@Consumption.valueHelpDefinition: [ {
  entity.name: 'ZPRA_G_MF_I_VISITOR',
  entity.element: 'Uuid'
} ]
VisitorUuid;
```
---

## Step 4: Projection CDS Views

Projection views are the **UI-facing layer** of the data model. They sit on top of the base views and expose only what the Fiori Elements app needs — redirected associations, value helps, text elements, and virtual elements.

In RAP, projection views are prefixed with `C` (for "consumption"). They use `provider contract transactional_query` which tells the framework this view is meant for transactional UI consumption.

### MusicFestival Projection

```abap
define root view entity ZPRA_G_MF_C_MUSICFESTIVALTP
  provider contract transactional_query
  as projection on ZPRA_G_MF_R_MUSICFESTIVAL
{
  key UUID,
  Title,
  Description,
  EventDateTime,
  MaxVisitorsNumber,
  FreeVisitorSeats,
  @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_G_MF_CALC_MF_ELEMENTS'
  virtual CapacityText : abap.char(20),
  VisitorsFeeAmount,
  @Consumption.valueHelpDefinition: [ {
    entity.element: 'Currency',
    entity.name: 'I_CurrencyStdVH',
    useForValidation: true
  } ]
  VisitorsFeeCurrency,
  @ObjectModel.text.element: ['StatusText']
  Status,
  _Status.Description as StatusText,
  ...
  _Visit : redirected to composition child ZPRA_G_MF_C_VISITTP,
  _Status
}
```

### Visitor Projection

```abap
define root view entity ZPRA_G_MF_C_VISITORTP
  provider contract transactional_query
  as projection on ZPRA_G_MF_R_VISITOR
{
  key UUID,
  Name,
  Email,
  ...
  _Visits : redirected to ZPRA_G_MF_C_VISITTP
}
```

### Visit Projection

```abap
define view entity ZPRA_G_MF_C_VISITTP
  as projection on ZPRA_G_MF_R_VISIT
{
  key Uuid,
  ParentUuid,
  @ObjectModel.text.element: ['VisitorName']
  VisitorUuid,
  _Visitor.Name  as VisitorName,
  _Visitor.Email as VisitorEmail,
  ArtistIndicator,
  @ObjectModel.text.element: ['StatusText']
  Status,
  _VisitStatus.Description as StatusText,
  _MusicFestival.Title         as FestivalTitle,
  _MusicFestival.EventDateTime as FestivalEventDateTime,
  LocalLastChangedAt,
  _MusicFestival : redirected to parent ZPRA_G_MF_C_MUSICFESTIVALTP,
  _Visitor       : redirected to ZPRA_G_MF_C_VISITORTP,
  _VisitStatus
}
```

### Key Concepts in This Layer

**Redirected Associations**

In projection views, associations must be redirected to point to other projection views instead of the base views. This keeps the entire consumption layer consistent.

```abap
_Visit : redirected to composition child ZPRA_G_MF_C_VISITTP,
_Visitor : redirected to ZPRA_G_MF_C_VISITORTP
```

**Text Elements**

To show a human-readable text instead of a raw key (like a UUID or a status code), use `@ObjectModel.text.element` pointing to a field that holds the description.

```abap
@ObjectModel.text.element: ['VisitorName']
VisitorUuid,
_Visitor.Name as VisitorName,
```

This tells the UI to display `VisitorName` wherever `VisitorUuid` is shown — so instead of a UUID, the visitor's name appears.

The same pattern is used for status:

```abap
@ObjectModel.text.element: ['StatusText']
Status,
_Status.Description as StatusText,
```

> ⚠️ `@ObjectModel.text.element` must be placed in the **Data Definition**, not the Metadata Extension. Putting it in the MDE will cause an activation error.

**Virtual Elements**

`CapacityText` is a virtual element — it has no column in the database. It is calculated at runtime by an ABAP class (`ZCL_G_MF_CALC_MF_ELEMENTS`) that implements `IF_SADL_EXIT_CALC_ELEMENT_READ`. It returns a string like `98 / 100` showing available seats out of max capacity.

```abap
@ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_G_MF_CALC_MF_ELEMENTS'
virtual CapacityText : abap.char(20),
```

**Fetching Fields Across Associations**

The Visit projection fetches `Name`, `Email`, `Title`, and `EventDateTime` directly from related entities through associations — no join needed:

```abap
_Visitor.Name            as VisitorName,
_Visitor.Email           as VisitorEmail,
_MusicFestival.Title     as FestivalTitle,
```

This keeps the Visit entity lean while still making all necessary data available to the UI.

---

## Step 5: Behavior Layer

The behavior layer is where you define **what operations are allowed** on your entities and **implement the business logic**. It consists of two parts — the Behavior Definition (BDEF) which declares the operations, and the Behavior Implementation Class which contains the actual ABAP code.

### Root Behavior Definition

The root behavior definition (`ZPRA_G_MF_R_MUSICFESTIVAL`) covers both MusicFestival and Visit in a single file since Visit is a child node of MusicFestival.

```abap
managed implementation in class ZBP_G_MF_R_MUSICFESTIVAL unique;
strict ( 2 );
with draft;

define behavior for ZPRA_G_MF_R_MUSICFESTIVAL alias MusicFestivals
persistent table ZPRA_G_MF_A_MF
draft table ZPRA_G_MF_D_MF
etag master LocalLastChangedAt
lock master total etag LocalLastChangedAt
authorization master( global )
{
  field ( readonly )
    UUID, CreatedBy, CreatedAt, LastChangedAt,
    LocalLastChangedAt, LastChangedBy;

  field ( numbering : managed ) UUID;

  create;
  update;
  delete;

  draft action Activate optimized;
  draft action Discard;
  draft action Edit;
  draft action Resume;
  draft determine action Prepare;

  validation validateFestival on save { create; update; }
  determination determineStatus on modify { create; }
  determination determineInitialSeats on modify { create; field MaxVisitorsNumber; }

  action publish result [1] $self;

  association _Visit { create; with draft; }

  mapping for ZPRA_G_MF_A_MF corresponding
  {
    UUID = UUID; Title = TITLE; Status = STATUS;
    ...
  }
}

define behavior for ZPRA_G_MF_R_VISIT alias Visit
persistent table zpra_g_mf_a_vst
draft table zpra_g_mf_d_vst
lock dependent by _MusicFestival
authorization dependent by _MusicFestival
etag master LocalLastChangedAt
{
  update;
  delete;

  field ( readonly ) Uuid, ParentUuid;
  field ( numbering : managed ) Uuid;
  field ( mandatory ) VisitorUuid;

  validation validateVisitCreation on save { create; }
  determination determineVisitStatus on modify { create; }
  determination determineAvailableSeats on save { create; update; }

  action cancel result [1] $self;

  association _MusicFestival { with draft; }

  mapping for zpra_g_mf_a_vst corresponding { ... }
}
```

### Projection Behavior Definition

The projection behavior definition (`ZPRA_G_MF_C_MUSICFESTIVALTP`) exposes only the operations that the UI is allowed to use. It also enforces readonly fields at the UI level.

```abap
projection implementation in class ZBP_G_MF_C_MUSICFESTTP unique;
strict ( 2 );
extensible;
use draft;

define behavior for ZPRA_G_MF_C_MUSICFESTIVALTP alias MusicFestivals
extensible
use etag
{
  use create;
  use update;
  use delete;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
  use action publish;

  field ( readonly ) FreeVisitorSeats, Status;

  use association _Visit { create; with draft; }
}

define behavior for ZPRA_G_MF_C_VISITTP alias Visit
use etag
{
  use update;
  use delete;
  use action cancel;

  field ( readonly ) Uuid, ParentUuid, Status;

  use association _MusicFestival { with draft; }
}
```

### Key Concepts in This Layer

**Managed vs Unmanaged**

This app uses `managed` implementation — the RAP framework handles all CRUD operations automatically. You only need to write code for custom logic like validations, determinations, and actions.

**Draft**

`with draft` enables the draft mechanism — changes are saved to a separate draft table first and only committed to the persistent table when the user clicks Save. This is what enables the Edit/Activate/Discard buttons in the UI.

Each entity needs its own draft table alongside the persistent table:

```abap
persistent table ZPRA_G_MF_A_MF
draft table ZPRA_G_MF_D_MF
```

**Field Control**

`field ( readonly )` prevents a field from being edited. There is an important distinction between where you put this:

- In the **root** behavior — blocks everyone including internal determinations
- In the **projection** behavior — blocks only UI users, internal logic can still update the field

In this app, `FreeVisitorSeats` and `Status` are readonly only in the projection — so users cannot edit them directly, but determinations can still update them in the background.

**Determinations**

Determinations are pieces of logic that run automatically when certain conditions are met. They are declared in the BDEF and implemented in the behavior class.

| Determination | Trigger | Purpose |
|---|---|---|
| `determineStatus` | `on modify { create; }` | Auto-set festival status to `I` on creation |
| `determineInitialSeats` | `on modify { create; field MaxVisitorsNumber; }` | Set available seats equal to max on creation or when max changes |
| `determineVisitStatus` | `on modify { create; }` | Auto-set visit status to `B` (Booked) on creation |
| `determineAvailableSeats` | `on save { create; update; }` | Recalculate available seats after a visit is added or cancelled |

> 💡 Notice that `determineAvailableSeats` triggers `on save` while others trigger `on modify`. This is intentional — seat calculation reads from the entity buffer which is only fully populated at save time.

**Validations**

Validations run on save and report errors back to the UI if conditions are not met.

| Validation | Trigger | Purpose |
|---|---|---|
| `validateFestival` | `on save { create; update; }` | Title and Event Date are mandatory, price cannot be negative |
| `validateVisitCreation` | `on save { create; }` | Visitor can only be added to a Published festival |

**Actions**

Actions are custom operations triggered by the user via buttons in the UI.

| Action | Entity | Purpose |
|---|---|---|
| `publish` | MusicFestival | Sets festival status to `P` (Published) |
| `cancel` | Visit | Sets visit status to `C` (Cancelled) and triggers seat recalculation |

**Mapping**

The `mapping` block maps CDS field names (camelCase) to database column names (snake_case). This is required for the managed runtime to know how to persist data.

```abap
mapping for ZPRA_G_MF_A_MF corresponding
{
  UUID          = UUID;
  Title         = TITLE;
  FreeVisitorSeats = FREE_VISITOR_SEATS;
  ...
}
```

### Visitor Behavior Definition

The Visitor behavior definition is simpler — it has no custom determinations, validations, or actions. It is a straightforward managed CRUD entity with draft support.

```abap
managed implementation in class ZBP_G_MF_R_VISITOR unique;
strict ( 2 );
with draft;
extensible;

define behavior for ZPRA_G_MF_R_VISITOR alias Visitors
persistent table ZPRA_G_MF_A_VSTR
extensible
draft table ZPRA_G_MF_D_VSTR
etag master LocalLastChangedAt
lock master total etag LocalLastChangedAt
authorization master( global )
{
  field ( readonly )
    UUID, CreatedBy, CreatedAt,
    LastChangedAt, LastChangedBy, LocalLastChangedAt;

  field ( numbering : managed ) UUID;

  create;
  update;
  delete;

  draft action Activate optimized;
  draft action Discard;
  draft action Edit;
  draft action Resume;
  draft determine action Prepare;

  mapping for ZPRA_G_MF_A_VSTR corresponding extensible
  {
    UUID = UUID; Name = NAME; Email = EMAIL;
    CreatedBy = CREATED_BY; CreatedAt = CREATED_AT;
    LastChangedAt = LAST_CHANGED_AT;
    LastChangedBy = LAST_CHANGED_BY;
    LocalLastChangedAt = LOCAL_LAST_CHANGED_AT;
  }
}
```

And its projection:

```abap
projection implementation in class ZBP_G_MF_C_VISITORTP unique;
strict ( 2 );
extensible;
use draft;
use side effects;

define behavior for ZPRA_G_MF_C_VISITORTP alias Visitors
extensible
use etag
{
  use create;
  use update;
  use delete;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
}
```

Notice a few differences compared to MusicFestival:

- **No custom determinations or validations** — Visitor is a simple entity, the framework handles everything
- **`extensible` keyword** — this marks the behavior as extensible, allowing it to be enhanced later without modifying the original object
- **No `field ( readonly )` in the projection** — all fields follow the root behavior's readonly rules

---

## Step 6: Behavior Implementation Class

The behavior implementation class is where all the actual ABAP business logic lives. For MusicFestival, this is `ZBP_G_MF_R_MUSICFESTIVAL` — a single class that handles both MusicFestival and Visit logic since Visit is a child node.

The class inherits from `CL_ABAP_BEHAVIOR_HANDLER` and each method corresponds to a validation, determination, or action declared in the behavior definition.

### Class Structure

```abap
CLASS LHC_ZPRA_G_MF_R_MUSICFESTIVAL DEFINITION
  INHERITING FROM CL_ABAP_BEHAVIOR_HANDLER.

  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION ...
      get_global_auth_visit FOR GLOBAL AUTHORIZATION ...
      validateFestival FOR VALIDATE ON SAVE ...
      validateVisitCreation FOR VALIDATE ON SAVE ...
      determineStatus FOR DETERMINE ON MODIFY ...
      determineVisitStatus FOR DETERMINE ON MODIFY ...
      determineAvailableSeats FOR DETERMINE ON SAVE ...
      determineInitialSeats FOR DETERMINE ON MODIFY ...
      cancel FOR MODIFY ...
      publish FOR MODIFY ...
ENDCLASS.
```

> 💡 Both MusicFestival and Visit handlers live in the same class. Visit methods are declared with `FOR Visit~methodName` while MusicFestival methods use `FOR MusicFestivals~methodName`.

### Validations

**`validateFestival`** — runs on save for MusicFestival, checks three rules:

```abap
METHOD validateFestival.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    FIELDS ( Title EventDateTime VisitorsFeeAmount FreeVisitorSeats MaxVisitorsNumber )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_data).

  LOOP AT lt_data INTO DATA(ls_data).

    " Rule 1: Title and Event Date are mandatory
    IF ls_data-Title IS INITIAL OR ls_data-EventDateTime IS INITIAL.
      APPEND VALUE #( %tky = ls_data-%tky ) TO failed-MusicFestivals.
      APPEND VALUE #(
        %tky = ls_data-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Title and Event Date are required'
        )
      ) TO reported-MusicFestivals.
    ENDIF.

    " Rule 2: Price cannot be negative
    IF ls_data-VisitorsFeeAmount < 0.
      ...
      %element-VisitorsFeeAmount = if_abap_behv=>mk-on  " highlights the field in the UI
      ...
    ENDIF.

    " Rule 3: Available seats cannot exceed max number
    IF ls_data-FreeVisitorSeats > ls_data-MaxVisitorsNumber.
      ...
    ENDIF.

  ENDLOOP.
ENDMETHOD.
```

**`validateVisitCreation`** — prevents adding a visitor to an unpublished festival:

```abap
METHOD validateVisitCreation.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    FIELDS ( ParentUuid )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_visits).

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    FIELDS ( Status )
    WITH VALUE #(
      FOR visit IN lt_visits
        ( %tky-UUID = visit-ParentUuid )
    )
    RESULT DATA(lt_festivals).

  LOOP AT lt_visits INTO DATA(ls_visit).
    READ TABLE lt_festivals INTO DATA(ls_festival)
      WITH KEY UUID = ls_visit-ParentUuid.
    IF ls_festival-Status <> 'P'.
      APPEND VALUE #( %tky = ls_visit-%tky ) TO failed-Visit.
      APPEND VALUE #(
        %tky = ls_visit-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Visitor can only be added to a Published festival'
        )
      ) TO reported-Visit.
    ENDIF.
  ENDLOOP.

ENDMETHOD.
```

> 💡 Notice the pattern — always use `READ ENTITIES ... IN LOCAL MODE` to read data within the RAP transaction buffer. Never use a direct `SELECT` in validations.

### Determinations

**`determineStatus`** — auto-sets festival status to `I` on creation:

```abap
METHOD determineStatus.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_data).

  MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    UPDATE FIELDS ( Status )
    WITH VALUE #(
      FOR ls IN lt_data
        WHERE ( Status IS INITIAL )
        ( %tky  = ls-%tky
          Status = 'I' )
    ).

ENDMETHOD.
```

**`determineVisitStatus`** — auto-sets visit status to `B` (Booked) on creation:

```abap
METHOD determineVisitStatus.
  MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    UPDATE FIELDS ( Status )
    WITH VALUE #(
      FOR key IN keys
        ( %tky  = key-%tky
          Status = 'B' )
    ).
ENDMETHOD.
```

**`determineInitialSeats`** — sets available seats when a festival is created or max capacity changes. Uses a direct `SELECT` here because at this point the visits are already persisted:

```abap
METHOD determineInitialSeats.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    FIELDS ( MaxVisitorsNumber )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_data).

  LOOP AT lt_data INTO DATA(ls_data).

    SELECT COUNT(*) FROM zpra_g_mf_a_vst
      WHERE parent_uuid = @ls_data-UUID
        AND status = 'B'
        AND artist_indicator = ''
      INTO @DATA(lv_booked).

    MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
      UPDATE FIELDS ( FreeVisitorSeats )
      WITH VALUE #( (
        %tky             = ls_data-%tky
        FreeVisitorSeats = ls_data-MaxVisitorsNumber - lv_booked
      ) ).

  ENDLOOP.
ENDMETHOD.
```

**`determineAvailableSeats`** — recalculates available seats after a visit is added or cancelled. Uses `READ ENTITIES` instead of `SELECT` because it needs to read from the transaction buffer to count visits that haven't been persisted yet:

```abap
METHOD determineAvailableSeats.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    FIELDS ( ParentUuid )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_visits).

  LOOP AT lt_visits INTO DATA(ls_visit).

    READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
        FIELDS ( UUID MaxVisitorsNumber )
        WITH VALUE #( ( %tky-UUID = ls_visit-ParentUuid ) )
        RESULT DATA(lt_festivals)
      ENTITY MusicFestivals BY \_Visit
        FIELDS ( Status ArtistIndicator )
        WITH VALUE #( ( %tky-UUID = ls_visit-ParentUuid ) )
        RESULT DATA(lt_all_visits).

    READ TABLE lt_festivals INTO DATA(ls_festival) INDEX 1.
    CHECK ls_festival IS NOT INITIAL.

    DATA lv_booked TYPE i.
    lv_booked = REDUCE i(
      INIT count = 0
      FOR visit IN lt_all_visits
      WHERE ( Status = 'B' AND ArtistIndicator = '' )
      NEXT count = count + 1
    ).

    MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
      UPDATE FIELDS ( FreeVisitorSeats )
      WITH VALUE #( (
        UUID             = ls_festival-UUID
        FreeVisitorSeats = ls_festival-MaxVisitorsNumber - lv_booked
      ) ).

  ENDLOOP.
ENDMETHOD.
```

> 💡 Two `ENTITY` blocks can be merged into a single `READ ENTITIES` statement — this is more efficient than making two separate calls.

> ⚠️ Artists (`ArtistIndicator = ''` means not an artist) are excluded from the booked count — they attend the festival but don't consume seats.

### Actions

**`publish`** — sets festival status to `P`:

```abap
METHOD publish.

  MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    UPDATE FIELDS ( Status )
    WITH VALUE #(
      FOR key IN keys
        ( UUID = key-UUID Status = 'P' )
    ).

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #(
    FOR ls IN lt_result
      ( %tky = ls-%tky %param = ls )
  ).

ENDMETHOD.
```

**`cancel`** — sets visit status to `C` (Cancelled). The seat recalculation happens automatically via `determineAvailableSeats` which triggers on `update`:

```abap
METHOD cancel.

  MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    UPDATE FIELDS ( Status )
    WITH VALUE #(
      FOR key IN keys
        ( %tky = key-%tky Status = 'C' )
    ).

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #(
    FOR ls IN lt_result
      ( %tky = ls-%tky
        %param-VisitorUuid        = ls-VisitorUuid
        %param-ArtistIndicator    = ls-ArtistIndicator
        %param-Status             = ls-Status
        %param-LocalLastChangedAt = ls-LocalLastChangedAt )
  ).

ENDMETHOD.
```

### Virtual Element Calculation Class

`ZCL_G_MF_CALC_MF_ELEMENTS` implements `IF_SADL_EXIT_CALC_ELEMENT_READ` to calculate the `CapacityText` virtual element at runtime. It has two methods:

**`get_calculation_info`** — tells the framework which real fields are needed to calculate the virtual element:

```abap
METHOD if_sadl_exit_calc_element_read~get_calculation_info.

  IF iv_entity EQ 'ZPRA_G_MF_C_MUSICFESTIVALTP'.
    IF line_exists( it_requested_calc_elements[ table_line = 'CAPACITYTEXT' ] ).
      INSERT |MAXVISITORSNUMBER| INTO TABLE et_requested_orig_elements.
      INSERT |FREEVISITORSEATS|  INTO TABLE et_requested_orig_elements.
    ENDIF.
  ENDIF.

ENDMETHOD.
```

**`calculate`** — performs the actual calculation and formats the output:

```abap
METHOD if_sadl_exit_calc_element_read~calculate.

  DATA events TYPE STANDARD TABLE OF ZPRA_G_MF_C_MUSICFESTIVALTP WITH DEFAULT KEY.
  events = CORRESPONDING #( it_original_data ).

  LOOP AT events REFERENCE INTO DATA(event).
    LOOP AT it_requested_calc_elements REFERENCE INTO DATA(req_calc_elements).
      CASE req_calc_elements->*.
        WHEN 'CAPACITYTEXT'.
          event->CapacityText = |{ event->FreeVisitorSeats } / { event->MaxVisitorsNumber }|.
      ENDCASE.
    ENDLOOP.
  ENDLOOP.

  ct_calculated_data = CORRESPONDING #( events ).

ENDMETHOD.
```

This produces the `98 / 100` style display shown in the app header.

---
