# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal working directory for kiosk and retail automation tools built for **Anson Supermart**. The main projects are:

1. **Price/Loyalty Checker Kiosk** (`price_loyalty_checker.py`) — Tkinter fullscreen kiosk app for barcode price lookup and loyalty card point balance display.
2. **People Counter** (`people_count/people_counter.py`) — YOLO-based person detection and entry/exit counting via RTSP camera.
3. **Data pipeline scripts** (`Documents/Python Scripts/`) — Utilities for converting FPB/DBF files from the POS system into CSVs consumed by the kiosk.
4. **BYD Trip Calculator** (`byd-trip-calculator/`) — Leaflet.js web app for EV trip energy estimation, hosted on GitHub Pages.

## Running the Projects

### Price/Loyalty Checker Kiosk
```bash
# Normal (fullscreen kiosk mode)
python price_loyalty_checker.py

# Windowed mode (development/testing)
python price_loyalty_checker.py --windowed

# Build standalone exe (no-console, UPX-compressed)
pyinstaller price_loyalty_checker.spec
# Output: dist/price_loyalty_checker.exe
# Deploy to: F:\kiosk\price_loyalty_checker.exe
```

### People Counter
```bash
cd people_count
python people_counter.py
# Press Q to quit; logs counts to counts.csv every 10 seconds
```

### Data Pipeline (FPB → CSV)
```bash
# Sync FE_PLU.FPB from POS server to kiosk share and convert to prices.csv
python "Documents/Python Scripts/fpb_sync_and_convert.py"

# One-off FPB/DBF inspection or conversion
python "Documents/Python Scripts/convert_fpb_to_csv.py" <file.fpb>
python "Documents/Python Scripts/fpb_inspector.py"
```

## Architecture

### Data Flow
```
POS server: F:\SSIMS\FE_PLU.FPB   (DBF-format proprietary file)
        ↓  fpb_sync_and_convert.py
F:\kiosk\prices.csv                (barcode, description, price, pack_code, merkey, clrkey, surkey)
F:\kiosk\loyalty.csv               (card_no, name, pts_total, pts_redeemed, pts_available)
        ↓  hot-reloaded every 1.5s
price_loyalty_checker.py           (Tkinter kiosk UI)
        ↓  writes
F:\kiosk\logs\activity_YYYY-MM-DD.csv
```

### Price Checker Key Concepts

**Multi-mode pricing**: Products can have up to 3 pack_code entries in prices.csv for the same item (identified by matching merkey/clrkey/surkey):
- `pack_code=3` → unit/retail price (shown large)
- `pack_code=2` → pack/chilled price (shown if different from unit)
- `pack_code=1` → case/box price (shown if different)

The CSV is order-sensitive — mode 2 and mode 1 rows must appear immediately below mode 3.

**Loyalty card detection**: Cards are 13 digits starting with `1010570`. Scanning one shows points balance instead of price.

**Server offline detection**: If both `prices.csv` and `loyalty.csv` become inaccessible for 3 consecutive poll cycles, the kiosk shows "Server Unavailable".

**Per-kiosk identity**: Each kiosk machine has `C:\kiosk_id.txt` (e.g., `MOLAVE_K1`) used to tag activity log entries.

**Keyboard shortcuts** (kiosk mode):
- `F5` — force reload prices.csv
- `F11` — toggle fullscreen
- `Escape` or `Ctrl+Q` — exit
- `Ctrl+L` — clear screen

### People Counter Key Concepts
- Uses YOLOv8 (`yolov8n.pt`) for real-time person detection on an RTSP stream.
- Entry/exit is determined by Y-coordinate line crossings (`ENTRY_LINE_Y=450`, `EXIT_LINE_Y=390`).
- Occupancy = cumulative IN − OUT.

### FPB Files
`.FPB` files are dBASE III/IV DBF files used by the FrontEnd POS system. Read them with `dbfread` using `encoding="latin-1"`. Key files:
- `FE_PLU.FPB` — Product/price list (PLU = Price Look-Up)
- `FE_DSC.FPB` — Loyalty/discount customer data
- `FE_WRK.FPB` — Working/transaction data

## Key Dependencies
- `tkinter`, `winsound` — kiosk UI (Windows built-ins)
- `pyinstaller` — packaging kiosk app as `.exe`
- `ultralytics` (YOLOv8/v11), `opencv-python` — people counter
- `dbfread`, `pandas` — FPB/DBF conversion scripts
- `Documents/Python Scripts/` also uses: `openpyxl`, `pytesseract`, `sqlite3`

## File Locations
- Kiosk shared data: `F:\kiosk\` (prices.csv, loyalty.csv, logs/)
- Kiosk identity: `C:\kiosk_id.txt` on each kiosk PC
- YOLO models: `~/yolo11n.pt`, `people_count/yolov8n.pt`
- Activity logs: `F:\kiosk\logs\activity_YYYY-MM-DD.csv`
- SQLite DB (misc scripts): `~/database.db`, `Documents/Python Scripts/database.db`

---

## D:\Projects — Retail Data Projects

### AnsonInventory (`D:\Projects\AnsonInventory\`)
Branch-level inventory pipeline from the WI_LGR ledger DBF.

```bash
# Full pipeline (copy snapshot + generate report)
D:\Projects\AnsonInventory\run_inventory_pipeline.bat

# Or step by step:
python scripts/copy_wi_lgr_snapshot.py      # copies WI_LGR.FPB into data/raw/wi_lgr_snapshots/
python scripts/generate_branch_inventory.py  # computes on-hand per branch, outputs to data/processed/branch_inventory/
```

**Key concepts:**
- `WI_LGR.FPB` — Stock ledger DBF; rows are movement transactions per MERKEY+DIRKEY (branch)
- On-hand = `sum(IN_FIELDS)` − `sum(OUT_FIELDS)` (field lists are hardcoded in the script)
- `ARS_FR` is an IN field; `BOR_RE` is an OUT field
- Branch names come from `config/branch_mapping.csv` (DIRKEY → BRANCH_NAME)
- Output: `BRANCH_INVENTORY_YYYY-MM-DD.csv` + `BRANCH_INVENTORY_latest.csv`

---

### CatalogAutomation (`D:\Projects\CatalogAutomation\Scripts\`)
Syncs the merchandise master (`MP_MER.FPB`) into a SQLite product database with full change detection.

```bash
cd D:\Projects\CatalogAutomation\Scripts

# Manual sync
python sync_mp_mer.py "\\server\share\MP_MER.FPB"
python sync_mp_mer.py "\\server\share\MP_MER.FPB" "\\server\share\MP_MER2.FPB"

# Automated check (run via Windows Task Scheduler at 3:00 AM)
python daily_sync.py
```

**Key concepts:**
- `MP_MER.FPB` — Merchandise master; ~55K products; updated nightly by POS at ~2:30 AM
- Database: `anson_products.db` (SQLite) with tables: `products`, `prices` (full history), barcodes
- Change detection: new products → `data_quality='NEEDS_DESCRIPTION'`; MEDESC changes → `data_quality='NEEDS_REVIEW'`
- Price history is fully preserved; `is_current=1` marks the active price
- `daily_sync.py` uses `.last_mp_mer_sync.json` to skip syncs when file hasn't changed
- Configure `CONFIG['mp_mer_path']` in `daily_sync.py` to point to the actual server share

---

### CatalogSync (`D:\Projects\CatalogSync\`)
Builds the active online catalog feed from the product master, manages product images for S3/website.

```bash
cd D:\Projects\CatalogSync\scripts

# Build 24-month activity master (prerequisite)
python build_activity_24m.py

# Export active catalog for Awesome Table (website display)
python export_active_catalog_feed.py
# → output/Catalog_Active_24M_AwesomeTable.csv
# → output/Photo_Priority_Queue_Active_24M.xlsx
# → output/Desc_Priority_Queue_Active_24M.xlsx

# Image management (PowerShell)
powershell -File copy_images_to_barcode_READY.ps1
```

**Key concepts:**
- Source of truth for the online catalog: `output/Operational_Master_Active_24M.xlsx` (sheet: `Operational_Master`)
- Active products = sold in last 24 months (`Active_24M=True`)
- Product images are stored locally as `images/barcode/<barcode>.jpg` and served from AWS S3 (`ansonsupermart.com`)
- Placeholder image used when no barcode photo exists
- Products have up to 5 barcodes (`BARCD1`–`BARCD5`) + `DEFAULT_BARCODE`; image lookup tries each

---

### NewCatalog (`D:\Projects\NewCatalog\`)
Scripts for working with `WI_LGR.FPB` (stock ledger) and image migration planning.

```bash
cd D:\Projects\NewCatalog\scripts
# (see individual script headers for usage)
```

---

## Documents\Python Scripts — Utility Scripts

Path: `C:\Users\alex\Documents\Python Scripts\`

### FE_T Report Tool (`FE_T_report_tool_v5.py`)
Tkinter GUI that loads a full year of monthly transaction CSVs (`FE_T01.CSV`–`FE_T12.CSV`) and computes Gross Profit per item/category.

```bash
python FE_T_report_tool_v5.py
# GUI: select folder containing FE_T01.CSV ... FE_T12.CSV
```

**Key concepts:**
- Transaction type `TRETYP` is zero-padded to 3 digits (e.g. `"9"` → `"009"`)
- TRETYP `001`–`010` = normal sales; `009` = inventory/adjustment transactions (seed for GP calculation)
- GP is computed from RE (revenue) and VL (cost) transaction subtypes; VL always reduces cost via `-abs(TRQUAN)`
- The `v5` file header says v7 internally — it's the latest version

---

### FPB/DBF Conversion Utilities

| Script | Purpose |
|--------|---------|
| `fpb_sync_and_convert.py` | Copies `FE_PLU.FPB` from POS server (`F:\SSIMS\`) to `F:\kiosk\` and converts to `prices.csv` — the primary feed for the kiosk |
| `plu_fpb_to_csv.py` | Standalone FE_PLU→CSV; accepts `argv[1]=input`, `argv[2]=output` |
| `convert_fpb_to_csv.py` | Generic any-FPB→CSV via `dbfread`; usage: `python convert_fpb_to_csv.py <file.fpb>` |
| `fpb_inspector.py` | Interactive Tkinter browser for any FPB/DBF — useful for discovering field names |
| `convert_dbf_to_sqlite.py` | Generic DBF→SQLite (via pandas + sqlalchemy) |
| `convert_sqlite_to_dbf.py` | Reverse: SQLite table→DBF |
| `export_dbf_to_excel.py` | Exports FE_T DBF records to Excel; requires `TRETYP`, `TRDESC`, `TRACER` fields |
| `export_009_to_excel.py` | Filters and exports only TRETYP `009` (inventory/variance) records with TRDESC normalization |
| `fix_fe_t_csv_headers.py` | Normalises column headers in FE_T CSV exports |
| `process_dbf.py` | GUI tool to pack/rewrite a DBF (removes deleted records); uses `dbf` library with `cp1252` encoding |

---

### Transaction Processing

**`process_fe_tMM_nielsen.py`** — Tkinter GUI that processes the current month's `FE_Txx.FPB` into a SQLite database (`D:\VM50\yourfile.sqlite`). Prompts to use yesterday's file or pick another. Includes a progress bar window.

**`migrate_to_sqlite.py`** — Reads any DBF/FPB into a pandas DataFrame and writes to SQLite via sqlalchemy. Default config: `D:\VM50\ssims.bak\2025\FE_T01.fpb` → `D:\ssims_data.db` table `sales_data`.

**`gpt_process_dbf.py` / `qwen_process_dbf.py`** — AI-assisted variants of the DBF processor (experimental).

---

### Flask Sales Dashboard (`app.py` + `static/`)

A local Flask web app serving sales reports from `D:\ssims_data.db`.

```bash
python app.py   # runs on http://0.0.0.0:5000
```

**API endpoints:**
- `GET /api/reports/total_sales_per_day?start_date=&end_date=&dirkeys=&tregnos=` — daily sales totals from `sales_data` table
- `GET /api/filters` — distinct DIRKEY and TREGNO values for filter dropdowns

Frontend HTML is in `static/index.html`. The database is the `sales_data` table populated by `migrate_to_sqlite.py`.

---

### Receipt OCR (`receipt_crop_ocr.py`, `receipt_to_script.py`)

OCR specific zones from a scanned receipt image using Tesseract.

```bash
python receipt_crop_ocr.py <image_path>
# Prints: TRACER number, total amount due, DSRKEY
```

Crop coordinates are hardcoded and may need tuning per receipt layout. Uses `pytesseract` + Pillow. Tesseract must be installed; set `tesseract_cmd` path if not in PATH.

---

### Earlier Price Checker Versions

`asi_price_checker_autoscale.py` and `asi_price_checker_autoscale v1.py` are earlier iterations of the kiosk price checker (price-only, no loyalty). The current production version is `price_loyalty_checker.py` in the home directory.

There is also a copy of `price_loyalty_checker.py` in this folder kept for reference.

---

## FPB File Reference

All `.FPB` files are dBASE III/IV DBF format. Open with `dbfread` using `encoding="latin-1"`.

| File | Contents |
|------|----------|
| `FE_PLU.FPB` | Price lookup — barcodes, prices, pack codes |
| `FE_DSC.FPB` | Loyalty/discount customers |
| `FE_WRK.FPB` | POS working/transaction data |
| `MP_MER.FPB` | Merchandise master (55K+ products, pricing, barcodes) |
| `WI_LGR.FPB` | Stock ledger — IN/OUT movements per branch |
| `FE_T01–T12.FPB` | Monthly transaction files |

---

## BYD Trip Calculator (`byd-trip-calculator/`)

An EV trip energy calculator web app hosted on GitHub Pages. Estimates energy consumption for trips plotted on an interactive map.

**Live URL:** `https://axgtan77.github.io/anson-tools/`

### Files
- `byd-trip-calculator/index.html` — Main HTML with model selector, drive settings, results grid
- `byd-trip-calculator/style.css` — Dark theme UI, responsive layout (sidebar stacks on mobile)
- `byd-trip-calculator/app.js` — Map logic, routing, energy calculation, 21 EV models

### Deployment
The app is deployed via the `gh-pages` branch. Files in `byd-trip-calculator/` on the feature branch must be copied to the **root** of the `gh-pages` branch for GitHub Pages to serve them:
```bash
# Deploy workflow:
git checkout gh-pages
git show <feature-branch>:byd-trip-calculator/index.html > index.html
git show <feature-branch>:byd-trip-calculator/style.css > style.css
git show <feature-branch>:byd-trip-calculator/app.js > app.js
git add index.html style.css app.js
git commit -m "Deploy: <description>"
git push -u origin gh-pages
git checkout <feature-branch>
```

### Key Technical Details

**Map & Routing:**
- Leaflet.js with CartoDB Dark tiles (default), plus Voyager, Satellite (Esri), OSM layer options
- OSRM (Open Source Routing Machine) for free route calculation — no API key needed
- Nominatim for geocoding/search, limited to Philippines (`countrycodes=ph`)

**Energy Calculation:**
- Base consumption per model × distance + AC penalty (2.0 kWh/100km) + passenger penalty (0.3 kWh/100km per extra passenger beyond 1)
- Calibrated from real-world data: BYD Atto 3, QC↔Paniqui Tarlac round trip (~320km), 4 passengers, AC on = 80% of 60.48 kWh battery → ~15.1 kWh/100km all-in, base ~12.5 kWh/100km

**EV Models (21 total):**
- BYD: Atto 3, Seal, Dolphin, Han
- Tesla: Model 3 LR, Model 3 SR, Model Y LR
- Hyundai/Kia: Ioniq 5 LR, EV6 LR
- Geely/Zeekr: Emgrand EV, Galaxy E5, Zeekr 001 LR, Zeekr X
- Xiaomi/Denza: SU7, SU7 Max, D9 EV
- Others: MG4 LR, Nissan Leaf e+, Volvo EX30, GAC Aion Y Plus, Chery Tiggo 8 Pro e+

**Known Issues / Gotchas:**
- HTML structure is sensitive — the sidebar div nesting must be correct or the `#map` div gets swallowed and Leaflet can't render. Always verify `</div>` closings for `.settings-section`, `.results-section`, `.specs-section` before the `<div id="map">`.
- When deploying, always copy ALL 3 files together (index.html, style.css, app.js) to avoid mismatched versions.
- The `.gitignore` has `*` (ignore everything) — `byd-trip-calculator/` is explicitly excluded via `!byd-trip-calculator/` and `!byd-trip-calculator/**`.
