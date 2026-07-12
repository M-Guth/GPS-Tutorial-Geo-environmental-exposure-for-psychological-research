# Spatial Digital Phenotyping Tutorial Repository

This repository contains a reproducible R pipeline for transforming simulated
minute-level GPS traces into behavioral mobility indicators and
geo-environmental exposure variables for psychological research.

The workflow accompanies the manuscript draft
*From minute-level GPS traces to geo-environmental exposure: a reproducible
pipeline for psychological research* 

The repository is intentionally GPS-only. It uses synthetic GPS data from five
simulated participants in Basel, Switzerland, so the full workflow can be run
without access to identifiable human mobility traces.

---

## Project Overview

| Component | Description |
|---|---|
| Input data | Simulated smartphone GPS CSV with latitude, longitude, timestamp, accuracy, movement flag, and participant ID |
| Study area | Basel-Stadt, Switzerland |
| Temporal resolution | Raw irregular GPS observations regularized to a participant-by-minute time series |
| Geo-enrichment | Distance, speed, DBSCAN place clusters, home proximity, crowded-area exposure, imperviousness, population density, NDVI |
| Main outputs | Minute-level, day-level, user-level, quality-control summaries, and calendar heatmaps |
| Language | R with `renv` |

Current example data size:

| Dataset | Rows excluding header | File |
|---|---:|---|
| Raw simulated GPS observations | 140,245 | `raw_data/basel_gps_data_simulated_v4.csv` |
| Regularized minute-level GPS data | 107,347 | `interims/gps_df_filled.csv` |
| Final minute-level output | 107,347 | `Results/gps_full_minute_data.csv` |
| Final day-level output | 71 participant-days | `Results/gps_daylevel.csv` |
| Final user-level output | 5 participants | `Results/gps_userlevel.csv` |

---

## Quick Start

Open the project root in RStudio by opening:

```r
Tutorial_Repo.Rproj
```

Then run the complete workflow from the repository root:

```r
source("run_all.R")
```

The pipeline expects the working directory to be the repository root. The
scripts use project-relative paths via `here()`.

If `interims/gps_df_filled.csv` and later intermediate files already exist,
the raw import can be skipped by editing the option at the top of `run_all.R`:

```r
run_raw_import <- FALSE
```

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
the results.

Relevant files:

- `renv/activate.R`: activates the project library.
- `renv/settings.json`: stores `renv` settings.
- `renv.lock`: records the package state.
- `.Rprofile`: activates `renv` when the project is opened.

If package versions need to be restored on a new machine, run from the project
root:

```r
renv::restore()
```

If packages are intentionally updated, update the lockfile with:

```r
renv::snapshot()
```

---

## Repository Structure

```text
Tutorial_Repo/
├── Tutorial_Repo.Rproj
├── run_all.R
├── README.md
├── .gitignore
├── .here
│
├── raw_data/
│   └── basel_gps_data_simulated_v4.csv
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
│   ├── daily_summary.csv
│   ├── days_per_user.csv
│   └── overall_completeness.csv
│
├── calendar_plots/
│   └── <variable>/<ID>.png
│
├── scripts/
│   ├── 01_Setup.R
│   ├── 02_load_raw_data.R
│   ├── 03_Datawrangling.R
│   ├── 04_1_Geo_Distance.R
│   ├── 04_2_Geo_uniqueplaces.R
│   ├── 04_3_Geo_Imperviousness.R
│   ├── 04_04_Geo_Population_density.R
│   ├── 04_05_Geo_crowded_areas.R
│   ├── 04_06_Geo_residential_interactions.R
│   ├── 04_07_Geo_greenspace.R
│   ├── 05_merge_and_aggregate.R
│   ├── 06_descriptive_analysis.R
│   ├── 07_calendar_plots_daylevel.R
│   └── 08_merge_questionnaire_daylevel.R
│
├── renv/
├── data/
└── questionnaire_data/
```

`Results/` and `interims/` keep their folder structure through `.gitkeep`
files, while generated contents are ignored by `.gitignore`.

---

## Input Data

### Simulated GPS Data

The raw GPS input is:

```text
raw_data/basel_gps_data_simulated_v4.csv
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
and participant-specific mobility patterns.

### External Geodata

The workflow uses Basel-specific geodata stored under `geodata/`.

| Folder | File | Used in | Purpose |
|---|---|---|---|
| `geodata/crowded_areas/raw/` | `overpass_turbo_export.geojson` | `04_05_Geo_crowded_areas.R` | OpenStreetMap features from Overpass Turbo |
| `geodata/crowded_areas/combined/` | `crowded_areas.gpkg` | Generated by `04_05_Geo_crowded_areas.R` | Buffered and merged crowded-area layer |
| `geodata/imperviousness/` | `CLMS_NVLCC_IMD_S2024_R10m_E41N27_03035_V01_R01.tif` | `04_3_Geo_Imperviousness.R` | Copernicus imperviousness raster |
| `geodata/ndvi/` | `Basel_NDVI.tif` | `04_07_Geo_greenspace.R` | Sentinel-2 NDVI raster for Basel-Stadt |
| `geodata/pop_grid_100m/` | `basel_stadt_population_2021_100m.tif` | `04_04_Geo_Population_density.R` | Basel-Stadt population raster |

---

## Pipeline Workflow

The full workflow is orchestrated by `run_all.R`.

### 01_Setup.R

Initializes the project environment.

- Checks that `renv/activate.R` exists.
- Activates the project-specific `renv` environment.
- Loads the package stack:
  `dplyr`, `tidyr`, `purrr`, `readr`, `tibble`, `ggplot2`, `here`,
  `lubridate`, `dbscan`, `ggTimeSeries`, `viridis`, `sf`, `raster`,
  `exactextractr`, and `terra`.

### 02_load_raw_data.R

Loads the simulated GPS input CSV.

- Reads `raw_data/basel_gps_data_simulated_v4.csv`.
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

### 04_1_Geo_Distance.R

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

### 04_2_Geo_uniqueplaces.R

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

### 04_3_Geo_Imperviousness.R

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

### 04_04_Geo_Population_density.R

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

### 04_05_Geo_crowded_areas.R

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

### 04_06_Geo_residential_interactions.R

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

### 04_07_Geo_greenspace.R

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
- Optionally loads `interims/steps_df_clean.csv` if it exists. The tutorial
  does not require step data; if no step file exists, `steps` is set to zero.
- Normalizes numeric columns, logical `filled` values, and timestamps.
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

### 06_descriptive_analysis.R

Computes quality-control summaries for the final minute-level GPS file.

Outputs:

- `Results/daily_summary.csv`: daily counts of total, filled, and observed GPS
  rows.
- `Results/days_per_user.csv`: participant-level capture statistics.
- `Results/overall_completeness.csv`: global completeness summary.

Important variables:

- `filled_true`: number of carry-forward rows.
- `filled_false`: number of observed GPS rows.
- `perc_filled_true`: percentage of carry-forward rows.
- `perc_filled_false`: percentage of observed GPS rows.
- `days_less_than_50_percent_observed`: days where less than half the rows are
  observed GPS measurements.

### 07_calendar_plots_daylevel.R

Creates calendar heatmaps for numeric day-level variables.

Main steps:

- Loads `Results/gps_daylevel.csv` if `gps_daylevel` is not already in memory.
- Detects all numeric day-level variables when `variables_to_plot <- NULL`.
- Creates one plot per participant and variable.
- Saves plots as:

```text
calendar_plots/<variable>/<ID>.png
```

### 08_merge_questionnaire_daylevel.R

Creates questionnaire-compatible output filenames for the GPS-only tutorial.

This repository does not require questionnaire files. The script therefore
copies:

- `Results/gps_daylevel.csv` to `Results/gps_daylevel_questionnaire.csv`.
- `Results/gps_userlevel.csv` to `Results/gps_userlevel_questionnaire.csv`.

In a real study, this step can be replaced with a merge between GPS-derived
day/user-level indicators and time-stamped questionnaire, EMA, REDCap, or
clinical data.

---

## Output Files

### Intermediate Files

| File | Created by | Description |
|---|---|---|
| `interims/gps_df_filled.csv` | `03_Datawrangling.R` | Regularized participant-by-minute GPS time series |
| `interims/geo/gps_df_geo_distance.csv` | `04_1_Geo_Distance.R` | Distance, speed, and movement indicators |
| `interims/geo/clusters_final_df.csv` | `04_2_Geo_uniqueplaces.R` | DBSCAN cluster IDs and daily place summaries |
| `interims/geo/gps_imperviousness.csv` | `04_3_Geo_Imperviousness.R` | Mean imperviousness in 100 m buffer |
| `interims/geo/gps_population.csv` | `04_04_Geo_Population_density.R` | Mean population value and raster-cell counts in 100 m buffer |
| `interims/geo/gps_df_geo_crowded_areas.csv` | `04_05_Geo_crowded_areas.R` | OSM crowded-area indicators |
| `interims/geo/gps_df_geo_home.csv` | `04_06_Geo_residential_interactions.R` | Home coordinates, distance to home, and at-home indicator |
| `interims/geo/gps_ndvi.csv` | `04_07_Geo_greenspace.R` | NDVI mean, green area, and green share in 100 m buffer |

### Final Files

| File | Description |
|---|---|
| `Results/gps_full_minute_data.csv` | Final minute-level dataset with GPS, mobility, home, crowded-area, imperviousness, NDVI, population, cluster, and step columns |
| `Results/gps_daylevel.csv` | Day-level indicators grouped by participant and date |
| `Results/gps_userlevel.csv` | Participant-level indicators across the full observation period |
| `Results/gps_daylevel_questionnaire.csv` | GPS day-level file copied to questionnaire-compatible output name |
| `Results/gps_userlevel_questionnaire.csv` | GPS user-level file copied to questionnaire-compatible output name |
| `Results/daily_summary.csv` | Daily completeness summary |
| `Results/days_per_user.csv` | Participant-level data availability summary |
| `Results/overall_completeness.csv` | Overall completeness summary |

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
| `steps` | Optional step count; zero if no step file is available |

### Day-Level Variables

| Variable | Description |
|---|---|
| `total_rows` | Number of minute records in the participant-day |
| `filled_true`, `filled_false` | Count of carry-forward vs. observed GPS rows |
| `perc_filled_true`, `perc_filled_false` | Percentage of carry-forward vs. observed GPS rows |
| `Minutes_slow_kmh_day`, `Minutes_fast_kmh_day`, `Minutes_Stationary_day` | Daily movement-state minutes |
| `steps_day` | Daily steps, if available |
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

Recommended checks before analysis:

- Inspect `Results/overall_completeness.csv`.
- Inspect `Results/daily_summary.csv`.
- Use `calendar_plots/perc_filled_false/` to visually inspect observed GPS
  coverage per participant.
- Consider excluding or sensitivity-testing days with low observed GPS coverage.


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

