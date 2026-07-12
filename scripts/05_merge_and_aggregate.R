# merge_and_aggregate.R
#
# This script merges all geo-enriched GPS datasets into one minute-level table
# and derives day-level and user-level summary indicators.
#
# Main steps:
# 1. Remove duplicate rows caused by daylight saving time shifts.
# 2. Load all relevant intermediate datasets (cluster, home, crowded areas, imperviousness, green, population, steps).
# 3. Merge datasets by `ID` and `timestamp_minute`.
# 4. Derive day-level and user-level indicators.
# 5. Split homestay and distance-from-home into whole-day, daytime, and nighttime windows.

# Functions ---------------------------------------------------------------
## Remove duplicate rows based on specified keys ####
# Duplicates in EMA/GPS datasets can appear due to daylight saving shifts.
# Keeping duplicates may cause many-to-many joins and inflated row counts.
remove_duplicates_df <- function(df, join_keys = c("ID", "timestamp_minute")) {
  df %>%
    distinct(across(all_of(join_keys)), .keep_all = TRUE)
}

## Clean imported CSV tables ####
# write.csv2() often stores row numbers as unnamed index columns. Some prior
# processing steps can also create duplicated column names. These columns do
# not carry analytic information and would otherwise pollute joins.
clean_import_df <- function(df) {
  df <- as.data.frame(df, check.names = FALSE)

  index_columns <- names(df) %in% c("", "X", "V1", "...1")
  df <- df[, !index_columns, drop = FALSE]

  if (anyDuplicated(names(df))) {
    df <- df[, !duplicated(names(df), fromLast = TRUE), drop = FALSE]
  }

  df
}

## Read semicolon-separated CSV files and remove import artifacts ####
# All tutorial intermediates are written with write.csv2(), so read.csv2()
# preserves German decimal commas and semicolon separators without extra setup.
read_csv2_clean <- function(path) {
  read.csv2(path, check.names = FALSE) %>%
    clean_import_df()
}

## Add missing columns expected by later steps ####
# This keeps the merge robust when optional tutorial outputs are missing a
# column. For example, railway indicators may be absent if no railway features
# were returned by Overpass.
ensure_columns <- function(df, columns, value = NA_real_) {
  for (column_name in columns) {
    if (!column_name %in% names(df)) {
      df[[column_name]] <- value
    }
  }
  df
}

## Convert shared variable types consistently ####
# This helper normalizes numeric columns, logical fill indicators, and minute
# timestamps before duplicate removal and joins.
convert_common_types <- function(df) {
  numeric_columns <- c(
    "accuracy", "accuracy_m", "altitude", "altitudeAccuracy", "speed", "heading",
    "movement_flag", "distances", "speed_kmh", "cumulative_distance",
    "Minutes_<20_kmh", "Minutes_>20_kmh", "Minutes_Stationary",
    "cumulative_distance_slow", "cumulative_distance_fast", "cluster_number",
    "day_unique_cluster_count", "day_total_cluster_changes",
    "day_mean_time_at_cluster", "day_total_time_in_noise", "crowded_area",
    "pedestrian", "shop", "railway", "at_home", "distance_to_home",
    "imperviousness_mean_100m", "avg_T", "grid_cells", "ndvi_mean_100m",
    "ndvi_green_area_100m_m2", "ndvi_green_share_100m", "population", "steps"
  )

  existing_numeric_columns <- intersect(numeric_columns, names(df))
  if (length(existing_numeric_columns) > 0) {
    # Handle both numeric values and character values with decimal commas.
    df[existing_numeric_columns] <- lapply(df[existing_numeric_columns], function(column) {
      suppressWarnings(as.numeric(gsub(",", ".", as.character(column))))
    })
  }

  if ("filled" %in% names(df)) {
    df$filled <- as.character(df$filled) %in% c("TRUE", "T", "1", "true", "True")
  }

  if ("timestamp_minute" %in% names(df)) {
    # gps_df_filled uses ISO timestamps such as 2025-03-01T08:27:00Z.
    # ymd_hms() preserves the full minute precision, while base as.POSIXct()
    # can silently collapse these strings to dates only.
    timestamp_parsed <- lubridate::ymd_hms(df$timestamp_minute, tz = "UTC", quiet = TRUE)

    # Some derived files already use "YYYY-mm-dd HH:MM:SS"; keep a fallback
    # for those standard POSIX-like strings.
    if (all(is.na(timestamp_parsed))) {
      timestamp_parsed <- as.POSIXct(df$timestamp_minute, tz = "UTC")
    }

    df$timestamp_minute <- timestamp_parsed
  }

  df
}

## NA-safe aggregation helpers ####
# Base sum(..., na.rm = TRUE) returns 0 for groups that are entirely missing.
# For environmental and home indicators, NA is more honest when no valid value
# exists in the group.
safe_sum <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  sum(x, na.rm = TRUE)
}

safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}

safe_max <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  max(x, na.rm = TRUE)
}

## Calculate percentage of valid minutes spent at home ####
# Homestay is defined as the proportion of non-missing at_home observations
# where at_home == 1. Missing at_home values are excluded from the denominator.
homestay_pct <- function(at_home_values) {
  valid_n <- sum(!is.na(at_home_values))
  if (valid_n == 0) {
    return(NA_real_)
  }
  round(100 * sum(at_home_values == 1, na.rm = TRUE) / valid_n, 2)
}


# Load Data ---------------------------------------------------------------
## Load the filled GPS base table ####
# If the script is sourced after earlier steps in the same R session, reuse the
# in-memory object. Otherwise, read the saved intermediate file.
gps_df_filled <- if (exists("gps_df_filled", inherits = TRUE)) {
  clean_import_df(gps_df_filled)
} else {
  read_csv2_clean(here("interims/gps_df_filled.csv"))
}

## Load geo-enriched minute-level datasets ####
# Each file contributes one domain of indicators and is merged back onto the
# filled minute-level GPS sequence.
distance       <- read_csv2_clean(here("interims/geo/gps_df_geo_distance.csv"))
cluster        <- read_csv2_clean(here("interims/geo/clusters_final_df.csv"))
crowded_areas  <- read_csv2_clean(here("interims/geo/gps_df_geo_crowded_areas.csv"))
home           <- read_csv2_clean(here("interims/geo/gps_df_geo_home.csv"))
imperviousness <- read_csv2_clean(here("interims/geo/gps_imperviousness.csv"))
green          <- read_csv2_clean(here("interims/geo/gps_ndvi.csv"))
population     <- read_csv2_clean(here("interims/geo/gps_population.csv"))

## Load optional step data ####
# The tutorial can run without step counts. When the file is absent, steps are
# filled with zero after merging so step summaries still exist.
if (file.exists(here("interims/steps_df_clean.csv"))) {
  steps_df <- read_csv2_clean(here("interims/steps_df_clean.csv"))

  # Some step exports use timestamp rather than timestamp_minute.
  if ("timestamp" %in% names(steps_df) && !"timestamp_minute" %in% names(steps_df)) {
    steps_df$timestamp_minute <- steps_df$timestamp
  }

  # Collapse possible multiple step entries per user-minute before joining.
  steps_df <- steps_df %>%
    convert_common_types() %>%
    group_by(ID, timestamp_minute) %>%
    summarise(
      steps = sum(steps, na.rm = TRUE),
      .groups = "drop"
    )
} else {
  steps_df <- NULL
}


# Clean and prepare data --------------------------------------------------
## Normalize types across all required tables ####
data_frame_names <- c(
  "gps_df_filled", "distance", "cluster", "crowded_areas",
  "home", "imperviousness", "green", "population"
)

for (data_frame_name in data_frame_names) {
  data_frame <- get(data_frame_name) %>%
    convert_common_types()
  assign(data_frame_name, data_frame)
}

cluster <- cluster %>%
  mutate(date = as.Date(date))

## Guarantee expected enrichment variables exist ####
# Missing variables are added before select() so the downstream aggregation can
# always refer to the same column names.
crowded_areas <- crowded_areas %>%
  ensure_columns(c("crowded_area", "pedestrian", "shop", "railway"), value = 0)

home <- home %>%
  ensure_columns(c("home_latitude", "home_longitude", "at_home", "distance_to_home"))

imperviousness <- imperviousness %>%
  ensure_columns(c("imperviousness_mean_100m"))

green <- green %>%
  ensure_columns(c("ndvi_mean_100m", "ndvi_green_area_100m_m2", "ndvi_green_share_100m"))

population <- population %>%
  ensure_columns(c("avg_T", "grid_cells"))

## Keep only domain-specific columns before merging ####
# Several enrichment files were created by appending new variables to the full
# GPS table. Selecting only each file's own variables prevents duplicate or
# malformed columns from being carried into the merged table.
distance <- distance %>%
  dplyr::select(
    ID, timestamp_minute,
    any_of(c(
      "date", "distances", "speed_kmh", "cumulative_distance",
      "Minutes_<20_kmh", "Minutes_>20_kmh", "Minutes_Stationary",
      "cumulative_distance_slow", "cumulative_distance_fast"
    ))
  )

cluster <- cluster %>%
  dplyr::select(
    ID, timestamp_minute,
    any_of(c(
      "cluster_number", "cluster_id", "day_unique_cluster_count",
      "day_total_cluster_changes", "day_mean_time_at_cluster",
      "day_total_time_in_noise"
    ))
  )

crowded_areas <- crowded_areas %>%
  dplyr::select(ID, timestamp_minute, any_of(c("crowded_area", "pedestrian", "shop", "railway")))

home <- home %>%
  dplyr::select(ID, timestamp_minute, any_of(c("home_latitude", "home_longitude", "distance_to_home", "at_home")))

imperviousness <- imperviousness %>%
  dplyr::select(ID, timestamp_minute, any_of(c("imperviousness_mean_100m")))

green <- green %>%
  dplyr::select(ID, timestamp_minute, any_of(c("ndvi_mean_100m", "ndvi_green_area_100m_m2", "ndvi_green_share_100m")))

population <- population %>%
  dplyr::select(ID, timestamp_minute, any_of(c("avg_T", "grid_cells")))

## Remove duplicate user-minute rows before joining ####
# This protects the reduce(left_join) step from accidental many-to-many joins.
distance       <- remove_duplicates_df(distance)
gps_df_filled  <- remove_duplicates_df(gps_df_filled)
crowded_areas  <- remove_duplicates_df(crowded_areas)
home           <- remove_duplicates_df(home)
imperviousness <- remove_duplicates_df(imperviousness)
green          <- remove_duplicates_df(green)
population     <- remove_duplicates_df(population)
cluster        <- remove_duplicates_df(cluster)

## Define merge keys and merge order ####
# gps_df_filled is the complete minute-level base; all enrichment tables add
# columns to that base by ID and timestamp_minute.
join_keys <- c("ID", "timestamp_minute")

dfs_to_join <- list(
  distance,
  crowded_areas,
  home,
  imperviousness,
  green,
  population,
  cluster
)

if (!is.null(steps_df)) {
  dfs_to_join <- c(dfs_to_join, list(steps_df))
}


# Merge all datasets iteratively ------------------------------------------
gps_full_minute_data <- reduce(
  dfs_to_join,
  function(base_df, new_df) {
    # Join only columns that are not already present in the base table.
    # This keeps the original GPS columns from gps_df_filled and avoids suffixes.
    new_cols <- setdiff(names(new_df), names(base_df))

    base_df %>%
      left_join(
        new_df %>% dplyr::select(all_of(join_keys), all_of(new_cols)),
        by = join_keys
      )
  },
  .init = gps_df_filled
) %>%
  mutate(
    # The population script keeps avg_T for compatibility with earlier code;
    # expose it as the clearer `population` variable after merging.
    population = as.numeric(avg_T),
    steps = if ("steps" %in% names(.)) replace_na(steps, 0) else 0
  ) %>%
  dplyr::select(-any_of(c("avg_T")))


# Aggregate to day level --------------------------------------------------
gps_daylevel <- gps_full_minute_data %>%
  mutate(
    # Use local civil time for day assignment and diurnal windows.
    timestamp_local = as.POSIXct(timestamp_minute, tz = "CET"),
    date = as.Date(timestamp_local),
    hour_local = hour(timestamp_local),
    # Paper definition: daytime = 07:00-22:00, nighttime = 22:00-05:00.
    # Hours 05:00-06:59 are intentionally not part of either subwindow.
    is_daytime = hour_local >= 7 & hour_local < 22,
    is_nighttime = hour_local >= 22 | hour_local < 5
  ) %>%
  group_by(ID, date) %>%
  summarise(
    # Data completeness metrics
    total_rows = n(),
    filled_true = sum(filled == TRUE, na.rm = TRUE),
    filled_false = sum(filled == FALSE, na.rm = TRUE),
    perc_filled_true = round(100 * filled_true / total_rows, 2),
    perc_filled_false = round(100 * filled_false / total_rows, 2),

    # Movement and step metrics
    Minutes_slow_kmh_day = safe_sum(`Minutes_<20_kmh`),
    Minutes_fast_kmh_day = safe_sum(`Minutes_>20_kmh`),
    Minutes_Stationary_day = safe_sum(Minutes_Stationary),
    steps_day = safe_sum(steps),

    cumulative_distance_day = round(safe_max(cumulative_distance) / 1000, 3),
    cumulative_distance_slow_day = round(safe_max(cumulative_distance_slow) / 1000, 3),
    cumulative_distance_fast_day = round(safe_max(cumulative_distance_fast) / 1000, 3),

    # Daily clustering metrics from the unique places script
    day_unique_cluster_count = first(na.omit(day_unique_cluster_count)),
    day_total_cluster_changes = first(na.omit(day_total_cluster_changes)),
    day_mean_time_at_cluster = first(na.omit(day_mean_time_at_cluster)),
    day_total_time_in_noise = first(na.omit(day_total_time_in_noise)),

    # Crowded-area exposure in minutes
    crowded_area_minutes_day = safe_sum(crowded_area),
    pedestrian_minutes_day = safe_sum(pedestrian),
    shop_minutes_day = safe_sum(shop),
    railway_minutes_day = safe_sum(railway),

    # Whole-day homestay
    minutes_at_home_day = safe_sum(at_home),
    minutes_not_home_day = safe_sum(1 - at_home),
    homestay_whole_day_pct = homestay_pct(at_home),

    # Daytime homestay: 07:00-22:00
    daytime_rows = sum(is_daytime, na.rm = TRUE),
    minutes_at_home_daytime = safe_sum(if_else(is_daytime, at_home, NA_real_)),
    minutes_not_home_daytime = safe_sum(if_else(is_daytime, 1 - at_home, NA_real_)),
    homestay_daytime_pct = homestay_pct(if_else(is_daytime, at_home, NA_real_)),

    # Nighttime homestay: 22:00-05:00
    nighttime_rows = sum(is_nighttime, na.rm = TRUE),
    minutes_at_home_nighttime = safe_sum(if_else(is_nighttime, at_home, NA_real_)),
    minutes_not_home_nighttime = safe_sum(if_else(is_nighttime, 1 - at_home, NA_real_)),
    homestay_nighttime_pct = homestay_pct(if_else(is_nighttime, at_home, NA_real_)),

    # Distance-from-home metrics, split into the same time windows
    mean_distance_from_home_day = safe_mean(distance_to_home),
    max_distance_from_home_day = safe_max(distance_to_home),
    mean_distance_from_home_daytime = safe_mean(if_else(is_daytime, distance_to_home, NA_real_)),
    max_distance_from_home_daytime = safe_max(if_else(is_daytime, distance_to_home, NA_real_)),
    mean_distance_from_home_nighttime = safe_mean(if_else(is_nighttime, distance_to_home, NA_real_)),
    max_distance_from_home_nighttime = safe_max(if_else(is_nighttime, distance_to_home, NA_real_)),

    # Environmental exposure metrics
    mean_imperviousness_100m_day = safe_mean(imperviousness_mean_100m),
    mean_ndvi_100m_day = safe_mean(ndvi_mean_100m),
    mean_ndvi_green_area_100m_m2_day = safe_mean(ndvi_green_area_100m_m2),
    mean_ndvi_green_share_100m_day = safe_mean(ndvi_green_share_100m),
    mean_population_day = safe_mean(population),

    .groups = "drop"
  )


# Aggregate to user level -------------------------------------------------
gps_userlevel <- gps_full_minute_data %>%
  group_by(ID) %>%
  summarise(
    # Overall data completeness across all minutes for each participant
    total_rows = n(),
    filled_true = sum(filled == TRUE, na.rm = TRUE),
    filled_false = sum(filled == FALSE, na.rm = TRUE),
    perc_filled_true = round(100 * filled_true / total_rows, 2),
    perc_filled_false = round(100 * filled_false / total_rows, 2),

    # Overall movement and step metrics
    Minutes_slow_kmh_user = safe_sum(`Minutes_<20_kmh`),
    Minutes_fast_kmh_user = safe_sum(`Minutes_>20_kmh`),
    Minutes_Stationary_user = safe_sum(Minutes_Stationary),
    steps_user = safe_sum(steps),

    cumulative_distance_user = round(safe_max(cumulative_distance) / 1000, 3),
    cumulative_distance_slow_user = round(safe_max(cumulative_distance_slow) / 1000, 3),
    cumulative_distance_fast_user = round(safe_max(cumulative_distance_fast) / 1000, 3),

    # Overall clustering summaries
    unique_cluster_count_user = n_distinct(cluster_number, na.rm = TRUE),
    total_cluster_changes_user = safe_sum(day_total_cluster_changes),
    mean_time_at_cluster_user = safe_mean(day_mean_time_at_cluster),
    total_time_in_noise_user = safe_sum(day_total_time_in_noise),

    # Overall crowded-area and home exposure
    crowded_area_minutes_user = safe_sum(crowded_area),
    pedestrian_minutes_user = safe_sum(pedestrian),
    shop_minutes_user = safe_sum(shop),
    railway_minutes_user = safe_sum(railway),
    minutes_at_home_user = safe_sum(at_home),
    minutes_not_home_user = safe_sum(1 - at_home),
    homestay_user_pct = homestay_pct(at_home),

    # Overall distance-from-home and environmental exposure
    mean_distance_from_home_user = safe_mean(distance_to_home),
    max_distance_from_home_user = safe_max(distance_to_home),
    mean_imperviousness_100m_user = safe_mean(imperviousness_mean_100m),
    mean_ndvi_100m_user = safe_mean(ndvi_mean_100m),
    mean_ndvi_green_area_100m_m2_user = safe_mean(ndvi_green_area_100m_m2),
    mean_ndvi_green_share_100m_user = safe_mean(ndvi_green_share_100m),
    mean_population_user = safe_mean(population),

    .groups = "drop"
  )


# Save results ------------------------------------------------------------
write_csv2(gps_full_minute_data, here("Results/gps_full_minute_data.csv"))
write_csv2(gps_daylevel, here("Results/gps_daylevel.csv"))
write_csv2(gps_userlevel, here("Results/gps_userlevel.csv"))


# Confirmation message ----------------------------------------------------
message("merge_and_aggregate.R: All datasets merged successfully")
message("  - gps_full_minute_data.csv: minute-level data with completeness indicators")
message("  - gps_daylevel.csv: day-level aggregations with day/night homestay metrics")
message("  - gps_userlevel.csv: user-level aggregations with completeness metrics")
