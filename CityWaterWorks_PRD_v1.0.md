# 💧 Water Supply— Machinery Billing & Record Management App
## Product Requirements Document (PRD) — v1.0

| Field | Value |
|---|---|
| Document Version | 1.0 — Initial Release |
| Status | DRAFT |
| Platform | Flutter (iOS, Android, Windows, macOS, Web) |
| Date | 02-03-2026 |
| Author | Water Works Office Team |
| Database | SQLite (Local) + Context7 |
| Date Format | DD-MM-YYYY (throughout entire app) |
| Currency | Rs. (Pakistani Rupee) |

---

## Table of Contents

1. [Introduction & Problem Statement](#1-introduction--problem-statement)
2. [Scope & Objectives](#2-scope--objectives)
3. [Target Users](#3-target-users)
4. [Data Model](#4-data-model)
5. [Feature Requirements](#5-feature-requirements)
6. [UI / UX Design Requirements](#6-ui--ux-design-requirements)
7. [Context7 Integration](#7-context7-integration)
8. [Technical Architecture](#8-technical-architecture)
9. [Excel Import — Detailed Parsing Specification](#9-excel-import--detailed-parsing-specification)
10. [Acceptance Criteria](#10-acceptance-criteria)
11. [Non-Functional Requirements](#11-non-functional-requirements)
12. [Development Milestones](#12-development-milestones)
13. [Open Questions & Decisions](#13-open-questions--decisions)
14. [Glossary](#14-glossary)
15. [Sign-Off](#15-sign-off)

---

## 1. Introduction & Problem Statement

The City Water Works office currently manages machinery maintenance billing records using Microsoft Excel workbooks. Each Excel file covers a location (e.g., **Tanky No. 2**) and is subdivided by **Sets** (e.g., Set No. 1, Set No. 2). Within each Set, multiple machinery sub-heads exist — **Motor**, **Pump**, **Transformer** — each with its own billing history columns: Serial No., Date, Voucher No., Amount, and (new) **Register Page No.**

### Current Excel Structure (Sample)

```
Sheet: Tanky 2
├── City Water Works Tanky No.2 Set No.1
│   ├── Motor 25/HP Siemens  → Sr.No | Date | Voucher No. | Amount
│   ├── Pump 4x5             → Sr.No | Date | Voucher No. | Amount
│   └── Transformer 50 Kv   → Sr.No | Date | Voucher No. | Amount
├── City Water Works Tanky No.2 Set No.2
│   ├── Motor 25/HP Siemens
│   ├── Pump 4x5
│   └── (no transformer)
├── City Water Works Tanky No.2 Set No.3
│   ├── Motor 30/HP Siemens
│   └── Pump 3x4
└── City Water Works Tanky No.2 Set No.4
    ├── Motor 20/HP Siemens
    └── Pump 3x4
```

### Problems with the Current Process

- **No mobile/cross-platform access** — Excel files tied to desktop PCs.
- **No validation** — incorrect date formats, missing voucher numbers enter unchecked.
- **No search or filter** — finding a specific bill requires scrolling large spreadsheets.
- **No export or sharing** — bills cannot be shared via WhatsApp directly.
- **No backup strategy** — file corruption or loss leads to permanent data loss.
- **No customisation** — adding a new machinery type requires restructuring the whole spreadsheet.
- **No register page linkage** — the physical office register page number is not recorded digitally.

This PRD defines the complete requirements for a **Flutter-based cross-platform application** that replaces this Excel workflow with a modern, offline-first, fully-featured record management system.

---

## 2. Scope & Objectives

### 2.1 In Scope

- Import data from existing Excel / CSV files (matching the current schema).
- Create, read, update, and delete all records — Schemes, Sets, Machinery, Billing Entries.
- **Register Page Number (Reg. Page No.)** column added to every billing sub-head table.
- Responsive UI — Mobile (primary), Tablet, and Desktop (Windows / macOS / Web).
- Local SQLite database — works 100% offline; no server dependency.
- Context7 integration for intelligent form auto-suggestions.
- Export to PDF, Excel (.xlsx), and CSV from any view.
- WhatsApp share button for PDFs.
- Full backup: create, restore, and share backup files.
- Settings page: app preferences, date format, currency symbol, theme.
- Customisable machinery table — add / rename / remove machinery types and their attributes.

### 2.2 Out of Scope

- Cloud sync (planned for v2).
- Multi-user role-based access (planned for v2).
- Automated payment processing.
- Online reporting dashboards.

---

## 3. Target Users

| User Type | Role | Primary Tasks |
|---|---|---|
| Office Clerk | Data Entry Operator | Add/edit billing entries, upload Excel files, print PDFs |
| Supervisor | Reviewer / Approver | Review records, export reports, share PDFs via WhatsApp |
| IT Admin | App Administrator | Backup, restore, configure machinery types and settings |

---

## 4. Data Model

### 4.1 Entity Relationship Overview

```
Scheme (Location / Excel Sheet)
  └── Set (Set No. 1, Set No. 2, ...)
        └── Machinery (Motor, Pump, Transformer, ...)
              └── BillingEntry (Sr.No, Date, Voucher No., Amount, Reg. Page No.)
```

### 4.2 Scheme

Derived from each Excel sheet tab. Examples: `Tanky 2`, `Tanky 1`, `Mehboob Colony`.

| Column | Type | Description |
|---|---|---|
| `scheme_id` | INTEGER PK | Auto-increment primary key |
| `scheme_name` | TEXT | Full location name (e.g., `Tanky No. 2`) |
| `description` | TEXT | Optional notes |
| `created_at` | TEXT | DD-MM-YYYY HH:MM |
| `updated_at` | TEXT | DD-MM-YYYY HH:MM |

### 4.3 Set

Each Scheme has one or more Sets (e.g., Set No. 1, Set No. 2). Each Set maps to a column group in the Excel file.

| Column | Type | Description |
|---|---|---|
| `set_id` | INTEGER PK | Auto-increment primary key |
| `scheme_id` | INTEGER FK | References Scheme |
| `set_number` | INTEGER | Set number (1, 2, 3...) |
| `set_label` | TEXT | Display label e.g. `Set No. 1` |

### 4.4 Machinery (Sub-Head)

Each Set contains multiple machinery items. Type and specs are defined per Set. Machinery types are fully customisable.

| Column | Type | Description |
|---|---|---|
| `machinery_id` | INTEGER PK | Auto-increment primary key |
| `set_id` | INTEGER FK | References Set |
| `machinery_type` | TEXT | e.g., `Motor`, `Pump`, `Transformer`, `Turbine` |
| `brand` | TEXT | e.g., `Siemens` |
| `specs` | TEXT (JSON) | Key-value pairs: `{"hp":"25","size":"4x5","kva":"50"}` |
| `display_label` | TEXT | Full label shown in UI e.g. `Motor 25/HP Siemens` |
| `sort_order` | INTEGER | Display order within the Set |

### 4.5 Billing Entry

Each Machinery sub-head has a ledger of billing entries. This is the primary data users enter daily.

| Column | Type | Description |
|---|---|---|
| `entry_id` | INTEGER PK | Auto-increment primary key |
| `machinery_id` | INTEGER FK | References Machinery |
| `serial_no` | INTEGER | Row serial number (auto-incremented, editable) |
| `entry_date` | TEXT | **DD-MM-YYYY format** |
| `voucher_no` | INTEGER | Voucher reference number |
| `amount` | REAL | Amount in **Rs.** (Rupees) |
| `reg_page_no` | TEXT | **NEW: Physical register page number** |
| `notes` | TEXT | Optional remarks |
| `created_at` | TEXT | Record creation timestamp |
| `updated_at` | TEXT | Last update timestamp |

> ⚠️ **KEY REQUIREMENT — Register Page No.**
> A new column `Reg. Page No.` must be added to **every** machinery sub-head billing table. This column records the physical page number in the office ledger/register where this bill is also noted. It is an optional, free-text field (e.g., `45`, `A-12`, `3B`). This column must appear in **all exports** (PDF, Excel, CSV) and printed views.

### 4.6 Machinery Types (Customisable)

| Column | Type | Description |
|---|---|---|
| `type_id` | INTEGER PK | Auto-increment primary key |
| `type_name` | TEXT | e.g., `Motor`, `Pump`, `Transformer` |
| `attributes` | TEXT (JSON) | Array of attribute definitions (see Section 5.6) |
| `created_at` | TEXT | Creation timestamp |

### 4.7 App Settings

| Column | Type | Description |
|---|---|---|
| `key` | TEXT PK | Setting key |
| `value` | TEXT | Setting value |

---

## 5. Feature Requirements

### 5.1 Dashboard (Home Screen)

- Summary cards: **Total Schemes**, **Total Sets**, **Total Entries This Month**, **Total Amount This Month (Rs.)**.
- Recent entries list (last 10 billing entries across all schemes).
- Quick action buttons: **Add Scheme**, **Add Entry**, **Import Excel/CSV**, **Export**.
- Global search bar — searches across all schemes, sets, voucher numbers, amounts.
- Responsive grid layout: 2 columns on mobile, 3–4 on tablet, 5+ on desktop.

### 5.2 Scheme Management

- List all schemes with scheme name, set count, last updated date, total amount.
- Create new scheme — enter name and optional description.
- Edit scheme name / description inline.
- Delete scheme — confirmation dialog; **cascades** to all Sets, Machinery, Entries.
- Tap a scheme → navigate to Scheme Detail page.

### 5.3 Scheme Detail Page

- Header shows scheme name and total amount (sum of all entries under this scheme).
- Horizontal tab bar or card list of Sets within the scheme.
- Each Set card shows: Set label, machinery types, entry count, total amount.
- Tap a Set → navigate to Set Detail page.
- Add / Edit / Delete Sets from this screen.

### 5.4 Set Detail Page — Core Form

> This is the **primary data entry screen**. It must present ALL machinery sub-heads for the Set simultaneously so the user does not need to navigate away.

- Set header: scheme name, set label, total amount for this Set.
- Each machinery sub-head displayed as an **expandable section / card**:
  - Section header: Machinery Type + specs (e.g., `Motor — 25HP Siemens`).
  - Below header: billing entry table with columns: `Sr.No` | `Date` | `Voucher No.` | `Amount (Rs.)` | `Reg. Page No.` | `Actions`.
  - **Add Entry** button at bottom of each sub-head table.
  - Each entry row has **Edit** (pencil icon) and **Delete** (trash icon) buttons.
  - Machinery spec biodata shown at top of section (read-only, editable via **Edit Machinery** button).

### 5.5 Add / Edit Billing Entry Form

Triggered by **Add Entry** or row Edit icon. Must be a **bottom sheet or dialog** — not a separate page.

| Field | Widget | Validation |
|---|---|---|
| Sr. No. | Auto-filled, editable number field | Required, numeric |
| Date | Date picker — **DD-MM-YYYY** display | Required, valid date |
| Voucher No. | Number input | Optional, numeric |
| Amount (Rs.) | Number input with `Rs.` prefix | Required, positive number |
| Reg. Page No. | Text input | Optional, max 20 chars |
| Notes | Multiline text | Optional |

- All amounts displayed and entered as `Rs. XX,XXX` (Rupee format with thousands separator).
- Date field always stored and displayed as **DD-MM-YYYY**.
- Context7 provides auto-suggestion for Voucher No. based on recent entries.
- **Save** — validates all fields, saves to SQLite, refreshes the table immediately.
- **Cancel** — dismisses without saving.

### 5.6 Machinery Management (Customisable Tables)

Users must be able to fully customise machinery types without developer intervention.

**Machinery Types Screen** (accessible from Settings):

- List of all machinery types: Motor, Pump, Transformer, Turbine, etc.
- **Add new type** — enter type name and define its attribute fields.
  - Each attribute has: `name`, `input_type` (text / number / dropdown), `options` (for dropdown), `required` flag.
- **Edit type** — rename or change attributes.
- **Delete type** — only if no machinery of that type exists; else show warning with count.

**Attribute Examples by Machinery Type:**

| Machinery Type | Attributes |
|---|---|
| Motor | Horsepower (dropdown: 20HP, 25HP, 30HP, 40HP), Brand (text), Phase (dropdown: Single, Three) |
| Pump | Size (text, e.g., `4x5`, `3x4`), Type (dropdown: Centrifugal, Submersible) |
| Transformer | kVA Rating (dropdown: 25kVA, 50kVA, 100kVA, 200kVA), Brand (text) |
| Turbine | Model (text), Flow Rate (number) |

- When adding machinery to a Set, the form **dynamically renders** based on the selected type's attribute definitions.
- Dropdown attributes show the pre-configured options list.

### 5.7 Excel / CSV Import

- Import button on Dashboard and Scheme List.
- Supports `.xlsx`, `.xls`, `.csv` file formats.
- File picker opens system file browser — works on Android, iOS, Windows, macOS.

**Parsing logic:**

1. Row 1: Scheme Set header (e.g., `City Water Works Tanky No.2 Set No.1`).
2. Row 2: Machinery sub-heads (e.g., `Motor 25/HP Siemens`, `Pump 4x5`, `Transformer 50 Kv`).
3. Row 3: Column headers (`Sr.No`, `Date`, `Voucher No.`, `Amount`).
4. Row 4+: Data rows.

- **Preview screen** shows parsed data before committing to DB.
- **Conflict detection**: if Scheme+Set already exists, user chooses **Merge** or **Replace**.
- Import errors shown per-row with row number, field, and reason.
- `Reg. Page No.` column auto-added as empty for all imported rows (user fills in later).
- Progress indicator for large files.

### 5.8 Export Features

#### 5.8.1 PDF Export

- Export scope options: Single Machinery Table | Single Set | Full Scheme | All Schemes.
- PDF layout mirrors the Excel layout: horizontal machinery sub-heads side by side (or stacked on narrow paper).
- **Header**: Scheme name, Set label, date of export.
- **Footer**: Page number, `Prepared by City Water Works`.
- Amount totals per machinery sub-head at the bottom of each column.
- All columns included: `Sr.No` | `Date` | `Voucher No.` | `Amount (Rs.)` | `Reg. Page No.`
- Landscape orientation for multi-machinery Sets; Portrait for single machinery.

#### 5.8.2 Excel Export (.xlsx)

- Recreates the original Excel layout — horizontal sub-heads, same column groupings.
- `Reg. Page No.` column inserted after `Amount` in each sub-head column group.
- Sheet name = Scheme name (truncated to 31 chars per Excel limit).
- Multiple Sets on same sheet (matching original file structure).
- Styled headers in blue (`#1E3A5F`) with white text.

#### 5.8.3 CSV Export

- Flat CSV with columns: `Scheme`, `Set`, `Machinery Type`, `Specs`, `Sr.No`, `Date`, `Voucher No.`, `Amount`, `Reg. Page No.`, `Notes`.
- One row per billing entry.
- UTF-8 encoded with BOM for Excel compatibility.

### 5.9 WhatsApp Share

- Every export view has a **Share via WhatsApp** button with the WhatsApp icon.
- On mobile: uses `whatsapp://` deep link with the file attached.
- On desktop: shows QR code to transfer file to mobile, or copies the file path.
- File is always **PDF format** for WhatsApp sharing.
- If WhatsApp is not installed, falls back to generic system share sheet.

### 5.10 Backup & Restore

**Backup Screen** (accessible from Settings):

- **Create Backup** button — exports entire SQLite database as a `.cww` backup file (zip of DB + metadata JSON).
  - File name format: `CityWaterWorks_Backup_DD-MM-YYYY_HH-MM.cww`
- **Share Backup** button — system share sheet (save to Drive, email, WhatsApp, etc.).
- **Restore Backup** button — file picker for `.cww` files; restores DB; existing data replaced after confirmation.
- **Backup History list** — last 10 local backups with date, size, entry count.
- **Auto-backup option**: run backup automatically every N days (configurable in Settings).
- Backup validates schema version — shows warning if restoring from older app version.

### 5.11 Settings Page

| Setting | Description |
|---|---|
| App Theme | Light / Dark / System Default |
| Primary Color | Color picker for accent color |
| Date Format | DD-MM-YYYY (default, locked per PRD requirement) |
| Currency Symbol | Default `Rs.` — editable text field |
| Amount Format | Toggle: `1,000` vs `1000` (thousands separator) |
| Auto Backup | Off / Daily / Weekly / Monthly |
| Backup Location | Local storage path |
| Machinery Types | Navigate to Machinery Customisation screen |
| Default Export Format | PDF / Excel / CSV |
| PDF Paper Size | A4 / Letter / Legal |
| App Version | Display only |
| Data Reset | Delete all data (with 2-step confirmation) |

---

## 6. UI / UX Design Requirements

### 6.1 Design Principles

- **Modern Material Design 3** — clean, flat, professional.
- **Primary color**: Deep Navy Blue `#1E3A5F`. **Accent**: Orange `#E67E22`.
- White backgrounds with card-based layout.
- **Typography**: Poppins (headings) + Roboto (body).
- Consistent **8px grid** spacing system.
- All interactive elements have clear tap / hover states.

### 6.2 Responsive Layout Breakpoints

| Device | Screen Width | Layout Behavior |
|---|---|---|
| Mobile | < 600px | Single column. Bottom navigation bar. Floating Action Button. |
| Tablet | 600px – 1200px | Two columns. Side navigation rail. Wider cards. |
| Desktop | > 1200px | Persistent side navigation drawer. Multi-column grid. Data tables with full column sets visible. |

### 6.3 Navigation Structure

- **Bottom nav (mobile)**: Home | Schemes | Add Entry | Export | Settings.
- **Side rail (tablet/desktop)**: Expanded with labels; icons-only on collapsed mode.
- **Breadcrumb trail** on detail pages: `Home > Scheme > Set > Entry`.
- Back button always available; swipe-back on iOS / Android.

### 6.4 Key UX Flows

#### Flow A: Add a Billing Entry

1. Open Schemes list → tap scheme.
2. Tap Set card.
3. In Set Detail, find the machinery sub-head (Motor / Pump / Transformer).
4. Tap **Add Entry** below that sub-head's table.
5. Fill form: Date (DD-MM-YYYY picker), Voucher No., Amount (Rs.), Reg. Page No.
6. Tap **Save**. Entry appears immediately in the table.

#### Flow B: Import Excel File

1. Dashboard → tap **Import**.
2. File picker opens. Select `.xlsx` or `.csv` file.
3. App parses file and shows preview table.
4. User confirms or cancels. On confirm, data imported to DB.
5. Success toast with entry count.

#### Flow C: Export & Share via WhatsApp

1. Open Set Detail page.
2. Tap three-dot menu → **Export PDF**.
3. PDF preview shown.
4. Tap **WhatsApp icon** → WhatsApp opens with PDF attached.

#### Flow D: Restore Backup

1. Settings → Backup & Restore.
2. Tap **Restore Backup**.
3. File picker → select `.cww` file.
4. Confirmation dialog: *"This will replace all existing data. Continue?"*
5. On confirm, DB restored. App reloads to Dashboard.

---

## 7. Context7 Integration

### 7.1 Purpose

Context7 provides intelligent form assistance — auto-completing voucher numbers, suggesting amounts based on historical patterns, and flagging potential duplicate entries. It operates **entirely locally** using SQLite data. No external API calls.

### 7.2 Integration Points

| Touch Point | Context7 Behavior |
|---|---|
| Voucher No. field | Suggests next sequential voucher number based on last entry's voucher |
| Amount field | Shows average amount for this machinery type as hint text |
| Date field | Defaults to today's date; remembers last-used date |
| Duplicate detection | Warns if same Date + Voucher No. + Amount already exists in this machinery |
| Machinery type selection | Remembers the most-recently-used type per Set for next entry |

### 7.3 Implementation Note

Implement as a Dart service class `Context7Service` that:

```dart
class Context7Service {
  Future<int?> suggestNextVoucherNo(int machineryId);
  Future<double?> averageAmount(int machineryId);
  Future<bool> checkDuplicate(int machineryId, String date, int? voucherNo, double amount);
  Future<String?> lastUsedMachineryType(int setId);
  Future<String> lastUsedDate(); // returns DD-MM-YYYY
}
```

---

## 8. Technical Architecture

### 8.1 Technology Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| State Management | Riverpod + StateNotifier (recommended) |
| Local Database | SQLite via `sqflite` (mobile) + `sqflite_common_ffi` (desktop) |
| ORM / Query Builder | `drift` — type-safe SQL queries in Dart |
| File Picker | `file_picker` package |
| Excel Import | `excel` package (pure Dart, reads .xlsx / .csv) |
| PDF Generation | `pdf` + `printing` packages |
| Excel Export | `excel` package |
| Share / WhatsApp | `share_plus` package |
| Date Picker | Custom DD-MM-YYYY picker using `table_calendar` or custom widget |
| Responsive Layout | `flutter_adaptive_scaffold` or custom `LayoutBuilder` |
| Backup Archive | `archive` package (creates .cww zip) |
| Context7 Service | Custom Dart service — no external dependency |

### 8.2 Flutter Package Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Database
  drift: ^2.x
  sqflite: ^2.x
  sqflite_common_ffi: ^2.x          # Desktop support
  path_provider: ^2.x
  path: ^1.x

  # State management
  flutter_riverpod: ^2.x
  riverpod_annotation: ^2.x

  # File operations
  file_picker: ^6.x
  share_plus: ^7.x

  # Excel import/export
  excel: ^4.x

  # PDF
  pdf: ^3.x
  printing: ^5.x

  # UI
  flutter_adaptive_scaffold: ^0.x
  table_calendar: ^3.x
  google_fonts: ^6.x
  fl_chart: ^0.x                    # Dashboard charts

  # Backup
  archive: ^3.x

  # Utilities
  intl: ^0.x
  uuid: ^4.x

dev_dependencies:
  drift_dev: ^2.x
  build_runner: ^2.x
  riverpod_generator: ^2.x
```

### 8.3 Project Directory Structure

```
lib/
├── main.dart                         # App entry, theme, routing
├── core/
│   ├── database/
│   │   ├── app_database.dart         # drift database class
│   │   ├── tables/                   # drift table definitions
│   │   │   ├── schemes_table.dart
│   │   │   ├── sets_table.dart
│   │   │   ├── machinery_table.dart
│   │   │   ├── billing_entries_table.dart
│   │   │   ├── machinery_types_table.dart
│   │   │   └── app_settings_table.dart
│   │   └── daos/                     # Data Access Objects
│   │       ├── schemes_dao.dart
│   │       ├── sets_dao.dart
│   │       ├── machinery_dao.dart
│   │       ├── billing_entries_dao.dart
│   │       └── settings_dao.dart
│   ├── models/                       # Dart model classes
│   │   ├── scheme.dart
│   │   ├── set_model.dart
│   │   ├── machinery.dart
│   │   ├── billing_entry.dart
│   │   └── machinery_type.dart
│   └── services/
│       ├── context7_service.dart     # Local intelligence engine
│       ├── backup_service.dart       # Backup / restore logic
│       ├── export_service.dart       # PDF, Excel, CSV generation
│       └── import_service.dart       # Excel / CSV parser
├── features/
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   ├── dashboard_controller.dart
│   │   └── widgets/
│   │       ├── summary_card.dart
│   │       └── recent_entries_list.dart
│   ├── schemes/
│   │   ├── schemes_list_screen.dart
│   │   ├── scheme_detail_screen.dart
│   │   ├── scheme_form.dart
│   │   └── schemes_controller.dart
│   ├── sets/
│   │   ├── set_detail_screen.dart
│   │   ├── set_form.dart
│   │   └── sets_controller.dart
│   ├── machinery/
│   │   ├── machinery_form.dart
│   │   ├── machinery_types_screen.dart
│   │   └── machinery_controller.dart
│   ├── entries/
│   │   ├── billing_entry_form.dart   # Bottom sheet form
│   │   ├── entries_table_widget.dart
│   │   └── entries_controller.dart
│   ├── import/
│   │   ├── import_screen.dart
│   │   ├── import_preview_screen.dart
│   │   └── import_controller.dart
│   ├── export/
│   │   ├── export_screen.dart
│   │   ├── pdf_builder.dart
│   │   ├── excel_builder.dart
│   │   └── csv_builder.dart
│   ├── backup/
│   │   ├── backup_screen.dart
│   │   └── backup_controller.dart
│   └── settings/
│       ├── settings_screen.dart
│       └── settings_controller.dart
└── shared/
    ├── widgets/
    │   ├── app_button.dart
    │   ├── app_text_field.dart
    │   ├── dd_mm_yyyy_date_picker.dart
    │   ├── amount_field.dart         # Rs. prefix input
    │   ├── machinery_card.dart
    │   ├── responsive_layout.dart
    │   └── whatsapp_share_button.dart
    ├── theme/
    │   ├── app_theme.dart
    │   └── app_colors.dart
    └── utils/
        ├── date_utils.dart           # DD-MM-YYYY helpers
        ├── currency_utils.dart       # Rs. formatting
        └── constants.dart
```

### 8.4 Database Schema (drift)

```dart
// billing_entries table — core data
class BillingEntries extends Table {
  IntColumn get entryId => integer().autoIncrement()();
  IntColumn get machineryId => integer().references(Machinery, #machineryId)();
  IntColumn get serialNo => integer()();
  TextColumn get entryDate => text()();           // DD-MM-YYYY
  IntColumn get voucherNo => integer().nullable()();
  RealColumn get amount => real()();              // Rs.
  TextColumn get regPageNo => text().nullable()(); // NEW: Register Page No.
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}
```

### 8.5 SQLite Migrations

- **Version 1**: Initial schema as defined above.
- **Version 2+**: Add columns via `ALTER TABLE` — never drop columns.
- `drift` handles migrations via `schemaVersion` and `MigrationStrategy`.

```dart
@DriftDatabase(tables: [Schemes, Sets, Machinery, BillingEntries, MachineryTypes, AppSettings])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Example: await m.addColumn(billingEntries, billingEntries.regPageNo);
      }
    },
  );
}
```

---

## 9. Excel Import — Detailed Parsing Specification

### 9.1 File Structure Analysis

Based on analysis of the provided sample file (`City_water_works_set_1.xlsx`):

Each Excel sheet = one **Scheme**. Within a sheet, Sets are arranged **side by side** as column groups.

**Parsing Algorithm:**

```
1. Scan Row 1 for non-empty cells
   → Each non-empty cell = start of a new Set column group
   → Extract Set number using regex: /Set No\.?(\d+)/i

2. Within each Set's column range, scan Row 2 for non-empty cells
   → Each non-empty cell = a machinery sub-head
   → Parse type and specs (see Section 9.2)

3. Row 3 = column headers: Sr.No | Date | Voucher No. | Amount

4. Rows 4+ = data rows
   → Parse each row per the column offsets defined in Row 2
   → Stop reading when 3+ consecutive empty rows encountered

5. Add empty Reg. Page No. for all imported entries
```

### 9.2 Machinery Label Parsing Rules

| Input Text (from Excel) | Detected Type | Extracted Specs |
|---|---|---|
| `Motor 25/HP Siemens` | Motor | `{hp: "25", brand: "Siemens"}` |
| `Motor30/HP Siemens` | Motor | `{hp: "30", brand: "Siemens"}` |
| `Motor 40/HP Siemens` | Motor | `{hp: "40", brand: "Siemens"}` |
| `Pump 4x5` | Pump | `{size: "4x5"}` |
| `Pump 3x4` | Pump | `{size: "3x4"}` |
| `Transformer 50 Kv` | Transformer | `{kva: "50"}` |
| `Transformer 100 Kv` | Transformer | `{kva: "100"}` |
| `Turbine` | Turbine | `{}` |

**Regex patterns:**

```dart
// Motor: extract HP and brand
final motorRegex = RegExp(r'Motor\s*(\d+)\s*/?\s*HP\s+(.+)', caseSensitive: false);

// Pump: extract size
final pumpRegex = RegExp(r'Pump\s*(\d+x\d+)', caseSensitive: false);

// Transformer: extract kVA
final transformerRegex = RegExp(r'Transformer\s*(\d+)\s*[Kk][Vv]', caseSensitive: false);
```

### 9.3 Date Parsing

Input dates from the Excel file may arrive in multiple formats:

| Input Format | Example | Handling |
|---|---|---|
| `dd-mm-yy` | `26-03-24` | Parse as DD-MM-20YY |
| `dd-mm-yyyy` | `14-09-2023` | Parse directly |
| `yyyy-mm-dd` | `2024-03-26` | Reformat to DD-MM-YYYY |
| Excel numeric date | `45362` (DateTime object) | Convert from Excel epoch |

- All dates **normalised to DD-MM-YYYY** for storage and display.
- Failed date parses flagged in import preview with orange warning icon.
- User can manually correct dates in the preview screen before import.

### 9.4 Sheet Names → Scheme Names

| Sheet Name | Scheme Name |
|---|---|
| `Tanky 2` | City Water Works Tanky No. 2 |
| `Tanky 1` | City Water Works Tanky No. 1 |
| `Mehboob colony` | Mehboob Colony Water Works |
| `Hussain Colony` | Hussain Colony Water Works |
| `14G` | 14G Water Works |
| `46F` | 46F Water Works |
| `Sodha` | Sodha Water Works |
| `list` | (Skip — metadata sheet) |

---

## 10. Acceptance Criteria

| # | Test Scenario | Expected Result |
|---|---|---|
| 1 | Import provided sample Excel file | All 13 sheets, 4+ sets, all machinery rows imported with correct values |
| 2 | Add billing entry with all fields | Entry saved, visible in table, amounts updated in summary |
| 3 | Edit existing entry | Changes saved, `updated_at` timestamp refreshed |
| 4 | Delete entry with confirmation | Entry removed, serial numbers re-ordered, total updated |
| 5 | Export single Set as PDF | PDF generated with all sub-heads, correct totals, Reg. Page No. column visible |
| 6 | Export as Excel (.xlsx) | File opens in Excel; layout matches original; Reg. Page No. column present |
| 7 | Export as CSV | Flat CSV with one row per entry; all columns present; opens in Excel without encoding issues |
| 8 | Share PDF via WhatsApp (mobile) | WhatsApp opens with PDF attached |
| 9 | Create backup | `.cww` file created with today's date in filename |
| 10 | Restore backup | All data restored; confirmation dialog shown before overwrite |
| 11 | Add custom machinery type with dropdown | New type appears in machinery form dropdown; custom attributes rendered correctly |
| 12 | Run app on Windows desktop | Full UI renders; navigation drawer visible; tables sortable and scrollable |
| 13 | Context7 duplicate warning | Adding same Date + Voucher No. + Amount shows warning toast |
| 14 | Responsive layout on tablet | Side navigation rail appears; two-column layout active |
| 15 | Date always DD-MM-YYYY | All dates in UI, PDF, Excel, CSV display in DD-MM-YYYY format |
| 16 | Amount always Rs. prefixed | All amounts show `Rs.` prefix throughout app and exports |

---

## 11. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Performance | App cold-start under 3 seconds. List of 10,000 entries loads and scrolls at 60fps. |
| Offline | 100% offline operation. Zero network dependency for any core feature. |
| Storage | SQLite DB with 50,000 billing entries should not exceed 50MB. |
| Compatibility | Android 8+, iOS 14+, Windows 10+, macOS 12+. |
| Accessibility | Text scales with OS font size. Contrast ratio ≥ 4.5:1 for all text. |
| Localisation | UI in English. Date/Currency formatted for Pakistan (`Rs.`, `DD-MM-YYYY`). |
| Security | DB not exported without explicit user action. No sensitive data in logs. |
| Crash Handling | All DB operations wrapped in try/catch. Errors shown as user-friendly snack bars. |
| PDF Quality | PDFs render correctly on all platforms; min 150 DPI for print quality. |
| Backup Integrity | Backup file includes version metadata; restore validates schema version before applying. |

---

## 12. Development Milestones

| Phase | Duration | Deliverables |
|---|---|---|
| **1** | Week 1 | Project setup, Flutter skeleton, SQLite schema, drift models, CRUD DAOs |
| **2** | Week 2 | Scheme / Set / Machinery screens, full CRUD UI, responsive layout |
| **3** | Week 3 | Billing Entry form, validation, Context7 service, DD-MM-YYYY date picker |
| **4** | Week 4 | Excel/CSV import parser, preview screen, conflict resolution |
| **5** | Week 5 | PDF export, Excel export, CSV export, WhatsApp share |
| **6** | Week 6 | Backup / Restore, Settings page, machinery type customisation |
| **7** | Week 7 | Desktop (Windows) testing, responsive fixes, performance optimisation |
| **8** | Week 8 | UAT with office team, bug fixes, final release build |

---

## 13. Open Questions & Decisions

| # | Question | Decision Needed From |
|---|---|---|
| 1 | Should deleted entries be soft-deleted (hidden) or hard-deleted (removed)? | Office Supervisor |
| 2 | Should auto-backup store files on device storage or allow Google Drive? | IT Admin |
| 3 | Is a PIN lock or biometric authentication required for app access? | Office Supervisor |
| 4 | PDF language: English only, or also Urdu labels? | Office Supervisor |
| 5 | How many years of historical data to import on initial setup? | Office Clerk |
| 6 | Should amounts support decimal values (e.g., Rs. 100.50)? | Office Supervisor |

---

## 14. Glossary

| Term | Definition |
|---|---|
| **Scheme** | A water works location. Maps to an Excel sheet. Example: `Tanky No. 2`. |
| **Set** | A sub-unit of a Scheme with specific machinery. Example: `Set No. 1`. |
| **Machinery / Sub-head** | Equipment type within a Set: Motor, Pump, Transformer, Turbine, etc. |
| **Billing Entry** | A single maintenance/billing record row: Date, Voucher No., Amount. |
| **Reg. Page No.** | Physical page number in the office ledger where this entry is recorded. |
| **Voucher No.** | Office voucher/bill reference number for an expenditure. |
| **Context7** | Local intelligent suggestion engine built into the app (no cloud API). |
| **.cww** | City Water Works backup file format (zip archive containing SQLite DB + metadata). |
| **kVA** | Kilovolt-Ampere — unit for transformer capacity rating. |
| **HP** | Horsepower — unit for motor power rating. |
| **drift** | Dart ORM library for type-safe SQLite queries. |
| **DD-MM-YYYY** | Date format used throughout the entire application (e.g., `26-03-2024`). |

---

## 15. Sign-Off

This PRD must be reviewed and approved by the following stakeholders before development begins:

| Name | Role | Signature | Date |
|---|---|---|---|
| ___________________ | Office Supervisor | ___________ | __________ |
| ___________________ | IT Administrator | ___________ | __________ |
| ___________________ | Lead Developer | ___________ | __________ |

---

*City Water Works | Machinery Billing App | PRD v1.0 | 02-03-2026*
*Confidential — Internal Use Only*
