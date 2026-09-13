# Spatial Digital Phenotyping Tutorial Repository

This repository contains a reproducible R pipeline for transforming simulated
minute-level GPS traces into behavioral mobility indicators and
geo-environmental exposure variables for psychological research.

The workflow accompanies the manuscript draft
*From minute-level GPS traces to geo-environmental exposure: a reproducible
pipeline for psychological research* 

The repository includes fixed synthetic GPS and questionnaire inputs from five
simulated participants in Basel, Switzerland, so the full workflow can be run
without identifiable human mobility or clinical data. The active inputs are
`basel_gps_data_simulated.csv` and `questionnaire_data.csv`. Repository script 06 links
both data streams through the shared participant `ID` and calendar date.

---

## Project Overview

| Component | Description |
|---|---|
| Input data | Simulated smartphone GPS CSV plus supplied synthetic EMA and short questionnaire data |
| Study area | Basel-Stadt, Switzerland |
| Temporal resolution | Raw irregular GPS observations regularized to a participant-by-minute time series |
| Geo-enrichment | Distance, speed, DBSCAN place clusters, home proximity, crowded-area exposure, imperviousness, population density, NDVI |
| Main outputs | Minute-level, day-level, user-level, questionnaire-linked, and statistical outputs |
| Language | R with `renv` |

Current example data size:

| Dataset | Rows excluding header | File |
|---|---:|---|
| Raw simulated GPS observations | 93,787 | `raw_data/basel_gps_data_simulated.csv` |
| Regularized minute-level GPS data | 111,365 | `interims/gps_df_filled.csv` |
| Final minute-level output | 111,365 | `Results/gps_full_minute_data.csv` |
| Final day-level output | 79 participant-days | `Results/gps_daylevel.csv` |
| Final user-level output | 5 participants | `Results/gps_userlevel.csv` |
| Combined questionnaire data | 484 rows: 474 momentary prompts plus 10 baseline/follow-up records | `questionnaire_data/questionnaire_data.csv` |

---

## Quick Start

Open the project root in RStudio by opening:

```r
Tutorial_Repo.Rproj
```

On a new machine, restore the locked packages first. Then run the complete
workflow from the repository root:

```r
renv::restore(prompt = FALSE)
source("run_all.R")
```

The pipeline expects the working directory to be the repository root. The
scripts use project-relative paths via `here()`. The numbered workflow reads
the supplied GPS and questionnaire files but does not regenerate or
overwrite them.

Individual scripts can also be run step by step:

```r
source("scripts/01_Setup.R")
source("scripts/02_load_raw_data.R")
source("scripts/03_Datawrangling.R")
```

---

## Reproducible R Environment

The repository uses `renv` for project-specific package management. `renv`
creates an isolated R package library for this project and records package
versions in `renv.lock`, reducing the risk that global package updates change
the results. The environment is pinned to **R 4.2.3** and **renv 1.2.4**.
Use R 4.2.3 to reproduce the tested setup; `renv` installs R packages, not R
itself or operating-system libraries.

Relevant files:

- `renv/activate.R`: activates the project library.
- `renv/settings.json`: stores `renv` settings.
- `renv.lock`: records the package state.
- `.Rprofile`: activates `renv` when the project is opened.
- `.renvignore`: limits package discovery to the numbered tutorial scripts and
  their entry points, excluding simulation helpers, data, and generated outputs.

The 16 direct tutorial packages are explicitly loaded in
`scripts/01_Setup.R`: `dplyr`, `tidyr`, `purrr`, `readr`, `tibble`, `ggplot2`,
`here`, `lubridate`, `dbscan`, `viridis`, `sf`, `raster`, `exactextractr`,
`terra`, `nlme`, and `gridExtra`. Literal `library()` calls allow `renv` to
detect every import. The lockfile contains these packages, `renv`, and their
required `Depends`, `Imports`, and `LinkingTo` dependencies: 69 packages in
total. Suggested packages and unrelated development packages are not installed.
Base R packages are provided by R; matching recommended packages may be used
from renv's sandbox library.

### Restore on a new machine

Install R 4.2.3 for the machine's operating system and architecture, copy or
clone the project including its input data, and open `Tutorial_Repo.Rproj`.
The project `.Rprofile` bootstraps the pinned `renv` version. Internet access
is required for the first download. Then run:

```r
renv::restore(prompt = FALSE)
renv::status()
source("run_all.R")
```

The same sequence is available from a terminal in the repository root:

```sh
Rscript -e 'renv::restore(prompt = FALSE)'
Rscript run_all.R
```

If R was started with `--vanilla` or from a different working directory, first
change to the project root and run `source("renv/activate.R")` before restoring.
Do not copy another computer's `renv/library/` directory: restore the lockfile
so packages are installed for the destination platform.

### Platform prerequisites

The spatial packages also depend on GDAL, GEOS, PROJ, and UDUNITS-2. Package
binaries normally supply their native dependencies on Windows and macOS.
Because the environment pins older versions, some packages may need to be
compiled from source when a matching binary is unavailable.

- **Windows:** use Rtools42 with R 4.2.x for source compilation.
- **macOS:** use an R build matching the Mac's CPU architecture. Source
  compilation requires Xcode Command Line Tools, an R-compatible Fortran
  compiler where needed, and the spatial libraries. Homebrew users can install
  the native libraries with `brew install pkg-config gdal geos proj udunits`.
- **Ubuntu/Debian:** before restoring source packages, install the build tools
  and spatial headers, for example:

  ```sh
  sudo apt-get update
  sudo apt-get install -y build-essential gfortran pkg-config cmake \
    libgdal-dev libgeos-dev libproj-dev libudunits2-dev libssl-dev libsqlite3-dev
  ```

See the official [sf installation instructions](https://r-spatial.github.io/sf/#installing),
[terra installation instructions](https://rspatial.github.io/terra/), and
[Rtools42 instructions](https://cran.r-project.org/bin/windows/Rtools/rtools42/rtools.html).
System-library versions can affect floating-point results, so small numerical
differences in model coefficients can occur across platforms.

### Maintain and check the environment

When adding a tutorial package, add a literal `library(package)` call to
`scripts/01_Setup.R`, install the chosen version into the active project, and
update the lockfile and check its status:

```r
renv::snapshot(prompt = FALSE)
renv::status()
```

Keep the default `implicit` snapshot mode and commit `.renvignore`,
`renv.lock`, `renv/activate.R`, `renv/settings.json`, `.Rprofile`, and the
changed scripts together. Do not use `snapshot(type = "all")`, which would
record unrelated installed packages.

---

## Repository Structure

```text
Tutorial_Repo/
├── Tutorial_Repo.Rproj
├── run_all.R
├── README.md
├── .gitignore
├── .renvignore
├── .here
│
├── raw_data/
│   └── basel_gps_data_simulated.csv
│
├── geodata/
│   ├── crowded_areas/
│   │   ├── raw/
│   │   │   └── overpass_turbo_export.geojson
│   │   └── combined/
│   │       └── crowded_areas.gpkg
│   ├── imperviousness/
│   │   └── CLMS_NVLCC_IMD_S2024_R10m_E41N27_03035_V01_R01.tif
│   ├── ndvi/
│   │   └── Basel_NDVI.tif
│   └── pop_grid_100m/
│       └── basel_stadt_population_2021_100m.tif
│
├── interims/
│   ├── .gitkeep
│   ├── gps_df_filled.csv
│   └── geo/
│       ├── .gitkeep
│       ├── clusters_final_df.csv
│       ├── gps_df_geo_crowded_areas.csv
│       ├── gps_df_geo_distance.csv
│       ├── gps_df_geo_home.csv
│       ├── gps_imperviousness.csv
│       ├── gps_ndvi.csv
│       └── gps_population.csv
│
├── Results/
│   ├── .gitkeep
│   ├── gps_full_minute_data.csv
│   ├── gps_daylevel.csv
│   ├── gps_userlevel.csv
│   ├── gps_daylevel_questionnaire.csv
│   ├── gps_userlevel_questionnaire.csv
│   ├── descriptive_statistics_table.csv
│   ├── descriptive_statistics_questionnaire_table.csv
│   ├── ndvi_stress_multilevel_model.csv
│   ├── ndvi_stress_multilevel_model_table.csv
│   └── ndvi_stress_daily_association.png
│
├── scripts/
│   ├── 01_Setup.R
│   ├── 02_load_raw_data.R
│   ├── 03_Datawrangling.R
│   ├── 04_01_Geo_Distance.R
│   ├── 04_02_Geo_uniqueplaces.R
│   ├── 04_03_Geo_residential_interactions.R
│   ├── 04_04_Geo_crowded_areas.R
│   ├── 04_05_Geo_greenspace.R
│   ├── 04_06_Geo_Imperviousness.R
│   ├── 04_07_Geo_Population_density.R
│   ├── 05_merge_and_aggregate.R
│   ├── 06_merge_questionnaire_daylevel.R
│   └── 07_statistics.R
│
├── renv/
├── data/
└── questionnaire_data/
    └── questionnaire_data.csv
```

`Results/` and `interims/` keep their folder structure through `.gitkeep`
files, while generated contents are ignored by `.gitignore`. The active GPS
and questionnaire files are supplied as fixed tutorial inputs. The GPS data
were simulated using the street and path network. Data-generation helpers
and the source network are not included or required to run the tutorial.

The numbered main workflow ends with `07_statistics.R`.

---

## Input Data

### Simulated GPS Data

The raw GPS input is:

```text
raw_data/basel_gps_data_simulated.csv
```

Required columns:

| Column | Description |
|---|---|
| `latitude` | GPS latitude in WGS84 |
| `longitude` | GPS longitude in WGS84 |
| `movement_flag` | Simulated movement-related signal |
| `accuracy_m` | GPS horizontal accuracy in meters |
| `timestamp` | Timestamp of the GPS observation |
| `ID` | Participant identifier (`P001`-`P005`) |

The simulated data mimic common passive sensing issues: irregular sampling,
heterogeneous GPS accuracy, stationary periods, movement episodes, longer gaps,
and participant-specific mobility patterns. Routes are finite curved paths with
explicit speed limits; stationary error is small and autocorrelated. Daily
choices between greener/less sealed/non-crowded and more urban/crowded
destinations create transparent exposure variation without implausible spatial
jumps.

### External Geodata

The workflow uses Basel-specific geodata stored under `geodata/`.

| Folder | File | Used in | Purpose |
|---|---|---|---|
| `geodata/crowded_areas/raw/` | `overpass_turbo_export.geojson` | `04_04_Geo_crowded_areas.R` | OpenStreetMap features from Overpass Turbo |
| `geodata/crowded_areas/combined/` | `crowded_areas.gpkg` | Generated by `04_04_Geo_crowded_areas.R` | Buffered and merged crowded-area layer |
| `geodata/ndvi/` | `Basel_NDVI.tif` | `04_05_Geo_greenspace.R` | Sentinel-2 NDVI raster for Basel-Stadt |
| `geodata/imperviousness/` | `CLMS_NVLCC_IMD_S2024_R10m_E41N27_03035_V01_R01.tif` | `04_06_Geo_Imperviousness.R` | Copernicus imperviousness raster |
| `geodata/pop_grid_100m/` | `basel_stadt_population_2021_100m.tif` | `04_07_Geo_Population_density.R` | Basel-Stadt population raster |
---

## Pipeline Workflow

The full workflow is orchestrated by `run_all.R`.

### 01_Setup.R

Initializes the project environment.

- Checks that `renv/activate.R` exists.
- Activates the project-specific `renv` environment.
- Loads the package stack:
  `dplyr`, `tidyr`, `purrr`, `readr`, `tibble`, `ggplot2`, `here`,
  `lubridate`, `dbscan`, `viridis`, `sf`, `raster`,
  `exactextractr`, and `terra`.

### 02_load_raw_data.R

Loads the simulated GPS input CSV.

- Reads `raw_data/basel_gps_data_simulated.csv`.
- Stores the table as `gps_df` in the R session.
- Stops if the input file is missing.

### 03_Datawrangling.R

Cleans and regularizes the raw GPS data.

Main steps:

- Rounds timestamps down to the nearest minute.
- Keeps the most accurate GPS fix per `ID` and `timestamp_minute` using the
  smallest `accuracy_m`.
- Creates a complete minute sequence per participant.
- Carries forward latitude, longitude, accuracy, and timestamp for missing
  minutes.
- Creates `filled`, where `TRUE` marks inserted carry-forward rows and `FALSE`
  marks observed GPS rows.
- Sets `movement_flag = 0` for filled rows.
- Renames the original timestamp to `last_gps_signal`.
- Writes `interims/gps_df_filled.csv`.

The `filled` variable is central for data-quality interpretation. It does not
mean "valid"; it means the row was inserted during minute-level regularization.

### 04_01_Geo_Distance.R

Derives movement and distance indicators from the regularized GPS sequence.

Main steps:

- Reads `interims/gps_df_filled.csv` if `gps_df_filled` is not already in
  memory.
- Calculates Haversine distance between consecutive GPS points within each
  participant-day.
- Converts distance to per-minute speed in km/h.
- Creates movement-state indicators:
  - `Minutes_<20_kmh`: speed greater than 0.001 km/h and less than 20 km/h.
  - `Minutes_>20_kmh`: speed greater than 20 km/h.
  - `Minutes_Stationary`: speed equal to 0.
- Computes cumulative daily distance and cumulative distance by slow/fast
  movement type.
- Writes `interims/geo/gps_df_geo_distance.csv`.

### 04_02_Geo_uniqueplaces.R

Identifies daily place clusters using DBSCAN.

Main steps:

- Reads `interims/geo/gps_df_geo_distance.csv` if needed.
- Converts GPS points to `sf` and transforms them to EPSG:25832 for metric
  distance calculations.
- Runs DBSCAN separately by participant and date:
  - `eps = 25` meters.
  - `minPts = 20`.
- Treats cluster `0` as DBSCAN noise.
- Creates:
  - `cluster_number`.
  - `cluster_id`.
  - `day_unique_cluster_count`.
  - `day_total_cluster_changes`.
  - `day_mean_time_at_cluster`.
  - `day_total_time_in_noise`.
- Writes `interims/geo/clusters_final_df.csv`.

### 04_03_Geo_residential_interactions.R

Infers home location and derives residential proximity indicators.

Main steps:

- Reads `interims/geo/gps_df_geo_distance.csv` if needed.
- Defines nighttime observations as 01:00 to 05:00.
- Estimates each participant's home location from nighttime coordinates using
  the geometric median with the Weiszfeld algorithm.
- Calculates Haversine distance from every GPS point to the inferred home
  location.
- Creates `at_home = 1` if `distance_to_home <= 200` meters, otherwise `0`.
- Writes `interims/geo/gps_df_geo_home.csv`.

### 04_04_Geo_crowded_areas.R

Creates OpenStreetMap-based indicators for potentially crowded public
environments.

Data source:

- OpenStreetMap data exported from Overpass Turbo.
- Repository file:
  `geodata/crowded_areas/raw/overpass_turbo_export.geojson`.
- OSM data are licensed under the Open Database License (ODbL).

The script processes the Overpass GeoJSON as follows:

- Transforms features to EPSG:25832.
- Validates geometries with `st_make_valid()`.
- Buffers point features by 50 m.
- Buffers line features by 10 m.
- Keeps polygon features unchanged.
- Classifies features into:
  - `pedestrian`.
  - `shop`.
  - `railway`.
- Writes the processed layer to
  `geodata/crowded_areas/combined/crowded_areas.gpkg`.
- Intersects each GPS point with the crowded-area layer.
- Creates binary indicators for each available type and a combined
  `crowded_area` indicator.
- Writes `interims/geo/gps_df_geo_crowded_areas.csv`.

Overpass Turbo query used for Basel:

```overpass
[out:json][timeout:180];

// City of Basel
{{geocodeArea:Basel, Switzerland}}->.baselArea;

(
  // Shopping malls / shopping centres
  nwr["shop"="mall"](area.baselArea);

  // Optional addition: also used in OSM for shopping centres
  nwr["shop"="shopping_centre"](area.baselArea);

  // Major railway stations
  nwr["railway"="station"](area.baselArea);

  // Pedestrian zones
  nwr["highway"="pedestrian"](area.baselArea);

  // Retail areas
  nwr["landuse"="retail"](area.baselArea);

  // Optional addition: individual retail buildings
  nwr["building"="retail"](area.baselArea);

  // Department stores
  nwr["shop"="department_store"](area.baselArea);
);

out geom;
```

### 04_05_Geo_greenspace.R

Calculates vegetation exposure using Sentinel-2 NDVI.

Data source:

- Sentinel-2 Surface Reflectance Harmonized imagery processed in Google Earth
  Engine.
- Repository file:
  `geodata/ndvi/Basel_NDVI.tif`.

Main steps:

- Loads `interims/geo/gps_df_geo_distance.csv` if needed.
- Converts GPS points to `sf`.
- Loads `geodata/ndvi/Basel_NDVI.tif` with `terra::rast()`.
- Projects the NDVI raster to EPSG:3035.
- Transforms GPS points to EPSG:3035.
- Creates 100 m buffers.
- Calculates:
  - `ndvi_mean_100m`: mean NDVI in the buffer.
  - `ndvi_green_area_100m_m2`: area with NDVI > 0.5 in square meters.
  - `ndvi_green_share_100m`: percentage of the 100 m buffer with NDVI > 0.5.
- Writes `interims/geo/gps_ndvi.csv`.

Google Earth Engine code used to create the Basel NDVI raster:

```javascript
// Cloud masking function for Sentinel-2
function maskS2clouds(image) {
  var qa = image.select('QA60');
  var cloudBitMask = 1 << 10;
  var cirrusBitMask = 1 << 11;

  var mask = qa.bitwiseAnd(cloudBitMask).eq(0)
               .and(qa.bitwiseAnd(cirrusBitMask).eq(0));

  return image.updateMask(mask).divide(10000);
}

// Load Basel-Stadt boundary from your GEE asset
var basel_stadt = ee.FeatureCollection('projects/ee-marvinguth2/assets/basel_stadt');

// Filter Sentinel-2 SR Harmonized collection for Basel-Stadt
var S2_BS = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
    .filterDate('2023-04-01', '2023-09-30')
    .filterBounds(basel_stadt)
    .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 20))
    .map(maskS2clouds)
    .median();

// Calculate NDVI and clip to Basel-Stadt
var NDVI = S2_BS.normalizedDifference(['B8', 'B4'])
                  .rename('NDVI')
                  .clip(basel_stadt);

// Select RGB and NIR bands and clip to Basel-Stadt
var RGBNIR = S2_BS.select(['B4', 'B3', 'B2', 'B8'])
                  .clip(basel_stadt);

// Center the map on Basel-Stadt
Map.centerObject(basel_stadt, 11);

// Add Basel-Stadt boundary to the map
Map.addLayer(basel_stadt, {color: 'red'}, 'Basel-Stadt Boundary');

// Add NDVI layer to the map
Map.addLayer(
  NDVI,
  {min: 0, max: 1, palette: ['FFFFFF', '115718']},
  'S2 NDVI Basel-Stadt'
);

// Print images to the console
print('NDVI Image:', NDVI);
print('RGB+NIR Image:', RGBNIR);

// Export NDVI as GeoTIFF clipped to Basel-Stadt
Export.image.toDrive({
  image: NDVI,
  description: 'Basel_Stadt_NDVI',
  folder: 'GEE_Exports',
  fileNamePrefix: 'Basel_Stadt_NDVI',
  region: basel_stadt.geometry(),
  scale: 10,
  crs: 'EPSG:4326',
  maxPixels: 1e13
});

// Export RGB+NIR as GeoTIFF clipped to Basel-Stadt
Export.image.toDrive({
  image: RGBNIR,
  description: 'Basel_Stadt_RGBNIR',
  folder: 'GEE_Exports',
  fileNamePrefix: 'Basel_Stadt_RGBNIR',
  region: basel_stadt.geometry(),
  scale: 10,
  crs: 'EPSG:4326',
  maxPixels: 1e13
});
```

### 04_06_Geo_Imperviousness.R

Calculates impervious-surface exposure around each GPS point.

Data source:

- Copernicus Land Monitoring Service Imperviousness Density 2024.
- Repository file:
  `geodata/imperviousness/CLMS_NVLCC_IMD_S2024_R10m_E41N27_03035_V01_R01.tif`.
- DOI noted in the script:
  `https://doi.org/10.2909/f0bcb6f0-d775-4218-bec1-13adea01ff8f`.

Main steps:

- Converts GPS points to `sf`.
- Transforms GPS points to the raster CRS.
- Creates 100 m buffers around each GPS point.
- Uses `exactextractr::exact_extract()` to calculate mean imperviousness within
  each buffer.
- Writes `interims/geo/gps_imperviousness.csv`.

### 04_07_Geo_Population_density.R

Calculates population-density exposure around each GPS point.

Data source:

- Eurostat/JRC population grid.
- Repository file:
  `geodata/pop_grid_100m/basel_stadt_population_2021_100m.tif`.
- Script references:
  `https://ec.europa.eu/eurostat/web/gisco/geodata/population-distribution/population-grids`.

Main steps:

- Converts GPS points to `sf`.
- Loads the Basel-Stadt population raster.
- Transforms GPS points to the raster CRS.
- Creates 100 m buffers around GPS points.
- Uses `exactextractr::exact_extract()` to calculate:
  - `avg_T`: mean population value within the buffer.
  - `grid_cells`: number of non-missing raster cells contributing to the
    extraction.
- Writes `interims/geo/gps_population.csv`.

### 05_merge_and_aggregate.R

Merges all behavioral and geo-environmental layers and creates analysis-ready
outputs.

Main steps:

- Loads the filled GPS base table.
- Loads all geo-enriched intermediate files:
  - distance and movement.
  - crowded areas.
  - home proximity.
  - imperviousness.
  - NDVI.
  - population.
  - DBSCAN clusters.
- Keeps only the indicators required from each geo-enriched dataset.
- Removes duplicate `ID` and `timestamp_minute` rows before joining.
- Left-joins all layers onto the minute-level GPS backbone.
- Creates:
  - `Results/gps_full_minute_data.csv`.
  - `Results/gps_daylevel.csv`.
  - `Results/gps_userlevel.csv`.

Day-level aggregation uses:

- Whole-day grouping by `ID` and `date`.
- Daytime window: 07:00-22:00.
- Nighttime window: 22:00-05:00.
- Hours 05:00-06:59 are intentionally excluded from both subwindows.

### 06_merge_questionnaire_daylevel.R

Reads `questionnaire_data/questionnaire_data.csv` without modifying or
overwriting it.
The script:

- filters the `momentary` rows and aggregates the six daily prompts to
  participant-day summaries;
- calculates scheduled prompts, completed prompts, compliance, and item means;
- joins questionnaire and GPS data directly by the shared `ID` and date;
- merges daily momentary and assessment-day WHO-5/PHQ-4 data with
  `Results/gps_daylevel.csv`;
- creates participant-level momentary means and baseline/follow-up questionnaire
  scores before merging them with `Results/gps_userlevel.csv`;
- checks that required questionnaire columns are present and validates
  assessment types, participant IDs, completion codes, and selected score
  ranges.

Outputs:

- `Results/gps_daylevel_questionnaire.csv`.
- `Results/gps_userlevel_questionnaire.csv`.

### 07_statistics.R

Creates compact participant-plus-overall descriptive tables from the day-level
GPS and questionnaire data. It also contains an explicitly illustrative
inferential example using the simulated tutorial data: a same-day multilevel
model of daily EMA stress on within- and between-participant NDVI exposure,
controlling for observed GPS coverage. The model does not filter days by GPS
coverage; days require three completed EMA prompts. Given the simulated data
and the very small number of participants, its coefficients and p-values must
not be interpreted substantively.

Outputs:

- `Results/descriptive_statistics_table.csv`: compact participant rows and an
  overall row with data completeness and `Median [Q1-Q3]` result cells.
- `Results/descriptive_statistics_questionnaire_table.csv`: EMA compliance,
  daily EMA summaries, and baseline/follow-up WHO-5 and PHQ-4 scores.
- `Results/ndvi_stress_multilevel_model.csv`: coefficients from the
  illustrative multilevel model.
- `Results/ndvi_stress_multilevel_model_table.csv`: manuscript-ready model table
  with coefficients, confidence intervals, test statistics, p-values, and
  partial-r effect sizes.
- `Results/ndvi_stress_daily_association.png`: pooled and participant-specific
  descriptive regression lines for the illustrative example.

---

## Output Files

### Intermediate Files

| File | Created by | Description |
|---|---|---|
| `interims/gps_df_filled.csv` | `03_Datawrangling.R` | Regularized participant-by-minute GPS time series |
| `interims/geo/gps_df_geo_distance.csv` | `04_01_Geo_Distance.R` | Distance, speed, and movement indicators |
| `interims/geo/clusters_final_df.csv` | `04_02_Geo_uniqueplaces.R` | DBSCAN cluster IDs and daily place summaries |
| `interims/geo/gps_df_geo_home.csv` | `04_03_Geo_residential_interactions.R` | Home coordinates, distance to home, and at-home indicator |
| `interims/geo/gps_df_geo_crowded_areas.csv` | `04_04_Geo_crowded_areas.R` | OSM crowded-area indicators |
| `interims/geo/gps_ndvi.csv` | `04_05_Geo_greenspace.R` | NDVI mean, green area, and green share in 100 m buffer |
| `interims/geo/gps_imperviousness.csv` | `04_06_Geo_Imperviousness.R` | Mean imperviousness in 100 m buffer |
| `interims/geo/gps_population.csv` | `04_07_Geo_Population_density.R` | Mean population value and raster-cell counts in 100 m buffer |

### Simulated Questionnaire Source File

| File | Description |
|---|---|
| `questionnaire_data/questionnaire_data.csv` | All baseline, momentary, and follow-up records in one REDCap-like longitudinal table |

The questionnaire file contains 474 scheduled momentary prompts and 10
baseline/follow-up records. Of the momentary prompts, 372 are completed. The programmed
synthetic relationships are teaching-data properties, not empirical or causal
evidence.

### Final Files

| File | Description |
|---|---|
| `Results/gps_full_minute_data.csv` | Final minute-level dataset with GPS, mobility, home, crowded-area, imperviousness, NDVI, population, and cluster columns |
| `Results/gps_daylevel.csv` | Day-level indicators grouped by participant and date |
| `Results/gps_userlevel.csv` | Participant-level indicators across the full observation period |
| `Results/gps_daylevel_questionnaire.csv` | GPS participant-days linked to daily EMA summaries and assessment-day WHO-5/PHQ-4 records |
| `Results/gps_userlevel_questionnaire.csv` | GPS participant summaries linked to EMA means and baseline/follow-up questionnaire scores |
| `Results/descriptive_statistics_table.csv` | Participant-level and overall descriptive GPS statistics |
| `Results/descriptive_statistics_questionnaire_table.csv` | Participant-level and overall descriptive questionnaire statistics |
| `Results/ndvi_stress_multilevel_model.csv` | Coefficients from the illustrative multilevel example |
| `Results/ndvi_stress_multilevel_model_table.csv` | Manuscript-ready table for the illustrative multilevel example |
| `Results/ndvi_stress_daily_association.png` | Plot accompanying the illustrative multilevel example |

---

## Key Variables

### Minute-Level Variables

| Variable | Description |
|---|---|
| `ID` | Participant identifier |
| `timestamp_minute` | Regularized minute timestamp |
| `latitude`, `longitude` | GPS coordinates |
| `movement_flag` | Original movement-related signal, set to 0 for filled rows |
| `accuracy_m` | GPS accuracy in meters |
| `last_gps_signal` | Timestamp of the last observed GPS fix carried forward |
| `filled` | `TRUE` for inserted carry-forward rows, `FALSE` for observed GPS rows |
| `distances` | Haversine distance to the previous minute within participant-day |
| `speed_kmh` | Per-minute speed in km/h |
| `cumulative_distance` | Cumulative distance within participant-day |
| `Minutes_<20_kmh` | Indicator for slow movement |
| `Minutes_>20_kmh` | Indicator for fast movement |
| `Minutes_Stationary` | Indicator for stationary minutes |
| `crowded_area` | Indicator for overlap with any crowded-area feature |
| `pedestrian`, `shop`, `railway` | Type-specific OSM exposure indicators |
| `home_latitude`, `home_longitude` | Inferred home coordinates |
| `distance_to_home` | Distance from GPS point to inferred home location |
| `at_home` | Indicator for being within 200 m of inferred home |
| `imperviousness_mean_100m` | Mean imperviousness in 100 m buffer |
| `ndvi_mean_100m` | Mean NDVI in 100 m buffer |
| `ndvi_green_area_100m_m2` | Area with NDVI > 0.5 in 100 m buffer |
| `ndvi_green_share_100m` | Percent of 100 m buffer with NDVI > 0.5 |
| `grid_cells` | Number of population raster cells contributing to the buffer |
| `population` | Mean population raster value in 100 m buffer |
| `cluster_number`, `cluster_id` | DBSCAN place cluster assignments |

### Day-Level Variables

| Variable | Description |
|---|---|
| `total_rows` | Number of minute records in the participant-day |
| `filled_true`, `filled_false` | Count of carry-forward vs. observed GPS rows |
| `perc_filled_true`, `perc_filled_false` | Percentage of carry-forward vs. observed GPS rows |
| `Minutes_slow_kmh_day`, `Minutes_fast_kmh_day`, `Minutes_Stationary_day` | Daily movement-state minutes |
| `cumulative_distance_day` | Daily cumulative distance in km |
| `cumulative_distance_slow_day`, `cumulative_distance_fast_day` | Daily distance by movement speed category in km |
| `day_unique_cluster_count` | Number of non-noise DBSCAN clusters visited |
| `day_total_cluster_changes` | Number of cluster transitions |
| `day_mean_time_at_cluster` | Mean time spent at identified clusters |
| `day_total_time_in_noise` | Minutes assigned to DBSCAN noise |
| `crowded_area_minutes_day` | Minutes in any crowded-area feature |
| `pedestrian_minutes_day`, `shop_minutes_day`, `railway_minutes_day` | Type-specific OSM exposure minutes |
| `minutes_at_home_day`, `minutes_not_home_day` | Whole-day home/not-home minutes |
| `homestay_whole_day_pct` | Percent of valid home observations spent at home |
| `minutes_at_home_daytime`, `minutes_not_home_daytime` | Home/not-home minutes from 07:00-22:00 |
| `homestay_daytime_pct` | Daytime homestay percentage |
| `minutes_at_home_nighttime`, `minutes_not_home_nighttime` | Home/not-home minutes from 22:00-05:00 |
| `homestay_nighttime_pct` | Nighttime homestay percentage |
| `mean_distance_from_home_day`, `max_distance_from_home_day` | Daily distance-from-home summaries |
| `mean_imperviousness_100m_day` | Mean daily imperviousness exposure |
| `mean_ndvi_100m_day` | Mean daily NDVI exposure |
| `mean_ndvi_green_area_100m_m2_day` | Mean daily dense vegetation area |
| `mean_ndvi_green_share_100m_day` | Mean daily dense vegetation share |
| `mean_population_day` | Mean daily population exposure |

### Questionnaire Variables

`momentary` denotes the short in-the-moment assessments commonly called EMA.
The `ema_` prefix is retained in analysis variables because it is conventional
in psychological intensive-longitudinal datasets.

| Variable | Description |
|---|---|
| `ID` | Participant identifier shared by the questionnaire and GPS data |
| `assessment_type` | Record type: `baseline`, `momentary`, or `followup` |
| `redcap_repeat_instance` | Sequential momentary-assessment number within participant |
| `completed`, `form_complete` | Binary completion and REDCap-style form status |
| `ema_positive_affect`, `ema_negative_affect` | Momentary affect items scored 1-7 |
| `ema_stress`, `ema_rumination` | Momentary stress and repetitive negative thinking scored 1-7 |
| `ema_activity_engagement`, `ema_social_connectedness` | Momentary activation and connectedness scored 1-7 |
| `ema_prompts_scheduled`, `ema_prompts_completed`, `ema_compliance_pct` | Day-level EMA completion indicators |
| `who_1`-`who_5`, `who5_raw`, `who5_percent` | WHO-5 items and 0-25/0-100 well-being scores |
| `phq_1`-`phq_4`, `phq4_depression`, `phq4_anxiety`, `phq4_total` | PHQ-4 items, subscales, and 0-12 total symptom score |

---

## Data Quality and Interpretation

The minute-level regularization step creates a complete time series for each
participant by carrying forward the last observed location. This is useful for
representing stationary periods and for constructing comparable daily
denominators, but it also means that not every row is an observed GPS
measurement.

Interpret `filled` as follows:

- `filled == FALSE`: observed GPS measurement.
- `filled == TRUE`: inserted row created during minute-level completion.

Before analysis, consider excluding or sensitivity-testing days with low
observed GPS coverage.

For the synthetic questionnaire data, retain `ema_prompts_scheduled` as the
denominator when reporting compliance and distinguish scheduled missed prompts
(`completed = 0`, `form_complete = 0`) from completed prompts (`completed = 1`,
`form_complete = 2`). Associations in the synthetic data are included for
instructional purposes and are not empirical or causal evidence.


---

## Version-Control Notes

The repository keeps the `Results/` and `interims/` folder structure but ignores
their generated contents:

```gitignore
Results/**
!Results/**/
!Results/**/.gitkeep

interims/**
!interims/**/
!interims/**/.gitkeep
```

This keeps paths reproducible while avoiding accidental commits of generated
intermediate and result data.
