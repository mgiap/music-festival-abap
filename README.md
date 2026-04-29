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

*More sections coming — Step 2: CDS Layer*
