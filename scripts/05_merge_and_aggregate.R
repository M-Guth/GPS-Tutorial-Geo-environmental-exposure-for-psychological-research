# merge_and_aggregate.R
#
# This script merges all minute-level GPS indicators and creates day-level
# and user-level summary datasets.
#
# Main processing steps:
# 1. Load the filled GPS data and all geo-enriched datasets.
# 2. Keep one row per ID and minute in every dataset.
# 3. Merge all indicators by ID and timestamp_minute.
# 4. Aggregate the merged data to day and user level.


# Load data ---------------------------------------------------------------
## Load filled GPS base data ####
if (exists("gps_df_filled", inherits = TRUE)) {
  message("05_merge_and_aggregate.R: gps_df_filled already loaded")
} else {
  gps_df_filled <- readr::read_csv2(
    here("interims/gps_df_filled.csv"),
    show_col_types = FALSE
  )
  message("05_merge_and_aggregate.R: gps_df_filled loaded from interims/gps_df_filled.csv")
}

## Load and select the indicators created by the geo scripts ####
distance <- readr::read_csv2(
  here("interims/geo/gps_df_geo_distance.csv"),
  show_col_types = FALSE,
  locale = readr::locale(tz = "Europe/Zurich")
) %>%
  dplyr::select(
    ID, timestamp_minute, date, distances, speed_kmh, cumulative_distance,
    `Minutes_<20_kmh`, `Minutes_>20_kmh`, Minutes_Stationary,
    cumulative_distance_slow, cumulative_distance_fast
  ) %>%
  mutate(date = as.character(date)) %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE)

cluster <- readr::read_csv2(
  here("interims/geo/clusters_final_df.csv"),
  show_col_types = FALSE,
  locale = readr::locale(tz = "Europe/Zurich")
) %>%
  dplyr::select(
    ID, timestamp_minute, cluster_number, cluster_id,
    day_unique_cluster_count, day_total_cluster_changes,
    day_mean_time_at_cluster, day_total_time_in_noise
  ) %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE)

crowded_areas <- readr::read_csv2(
  here("interims/geo/gps_df_geo_crowded_areas.csv"),
  show_col_types = FALSE,
  locale = readr::locale(tz = "Europe/Zurich")
) %>%
  dplyr::select(ID, timestamp_minute, crowded_area, pedestrian, shop, railway) %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE)

home <- readr::read_csv2(
  here("interims/geo/gps_df_geo_home.csv"),
  show_col_types = FALSE,
  locale = readr::locale(tz = "Europe/Zurich")
) %>%
  dplyr::select(
    ID, timestamp_minute, home_latitude, home_longitude,
    distance_to_home, at_home
  ) %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE)

imperviousness <- readr::read_csv2(
  here("interims/geo/gps_imperviousness.csv"),
  show_col_types = FALSE,
  locale = readr::locale(tz = "Europe/Zurich")
) %>%
  dplyr::select(ID, timestamp_minute, imperviousness_mean_100m) %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE)

green <- readr::read_csv2(
  here("interims/geo/gps_ndvi.csv"),
  show_col_types = FALSE,
  locale = readr::locale(tz = "Europe/Zurich")
) %>%
  dplyr::select(
    ID, timestamp_minute, ndvi_mean_100m,
    ndvi_green_area_100m_m2, ndvi_green_share_100m
  ) %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE)

population <- readr::read_csv2(
  here("interims/geo/gps_population.csv"),
  show_col_types = FALSE,
  locale = readr::locale(tz = "Europe/Zurich")
) %>%
  dplyr::select(ID, timestamp_minute, avg_T, grid_cells) %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE)


# Merge minute-level datasets --------------------------------------------
# The filled GPS data define the complete minute-level time grid. Left joins
# therefore retain all GPS minutes, including minutes without geo indicators.
gps_full_minute_data <- gps_df_filled %>%
  distinct(ID, timestamp_minute, .keep_all = TRUE) %>%
  left_join(distance, by = c("ID", "timestamp_minute")) %>%
  left_join(crowded_areas, by = c("ID", "timestamp_minute")) %>%
  left_join(home, by = c("ID", "timestamp_minute")) %>%
  left_join(imperviousness, by = c("ID", "timestamp_minute")) %>%
  left_join(green, by = c("ID", "timestamp_minute")) %>%
  left_join(population, by = c("ID", "timestamp_minute")) %>%
  left_join(cluster, by = c("ID", "timestamp_minute")) %>%
  mutate(population = as.numeric(avg_T)) %>%
  dplyr::select(-avg_T)


# Aggregate to day level --------------------------------------------------
gps_daylevel <- gps_full_minute_data %>%
  mutate(
    timestamp_local = with_tz(timestamp_minute, "Europe/Zurich"),
    date = as.Date(timestamp_local, tz = "Europe/Zurich"),
    hour_local = hour(timestamp_local),
    is_daytime = hour_local >= 7 & hour_local < 22,
    is_nighttime = hour_local >= 22 | hour_local < 5
  ) %>%
  group_by(ID, date) %>%
  summarise(
    # Data completeness
    total_rows = n(),
    filled_true = sum(filled == TRUE, na.rm = TRUE),
    filled_false = sum(filled == FALSE, na.rm = TRUE),
    perc_filled_true = round(100 * filled_true / total_rows, 2),
    perc_filled_false = round(100 * filled_false / total_rows, 2),

    # Movement
    Minutes_slow_kmh_day = sum(`Minutes_<20_kmh`, na.rm = TRUE),
    Minutes_fast_kmh_day = sum(`Minutes_>20_kmh`, na.rm = TRUE),
    Minutes_Stationary_day = sum(Minutes_Stationary, na.rm = TRUE),
    # Sum minute-level displacement directly. This is robust to timezone
    # round-trips in CSV intermediates and exactly reconciles with user totals.
    cumulative_distance_day = round(sum(distances, na.rm = TRUE) / 1000, 3),
    cumulative_distance_slow_day = round(
      sum(if_else(speed_kmh < 20, distances, 0), na.rm = TRUE) / 1000,
      3
    ),
    cumulative_distance_fast_day = round(
      sum(if_else(speed_kmh > 20, distances, 0), na.rm = TRUE) / 1000,
      3
    ),

    # Unique places
    day_unique_cluster_count = first(na.omit(day_unique_cluster_count)),
    day_total_cluster_changes = first(na.omit(day_total_cluster_changes)),
    day_mean_time_at_cluster = first(na.omit(day_mean_time_at_cluster)),
    day_total_time_in_noise = first(na.omit(day_total_time_in_noise)),

    # Crowded areas
    crowded_area_minutes_day = sum(crowded_area, na.rm = TRUE),
    pedestrian_minutes_day = sum(pedestrian, na.rm = TRUE),
    shop_minutes_day = sum(shop, na.rm = TRUE),
    railway_minutes_day = sum(railway, na.rm = TRUE),

    # Home stay: whole day
    minutes_at_home_day = sum(at_home, na.rm = TRUE),
    minutes_not_home_day = sum(1 - at_home, na.rm = TRUE),
    homestay_whole_day_pct = round(
      100 * sum(at_home == 1, na.rm = TRUE) / sum(!is.na(at_home)),
      2
    ),

    # Home stay: daytime (07:00-22:00)
    daytime_rows = sum(is_daytime, na.rm = TRUE),
    minutes_at_home_daytime = if (daytime_rows == 0) NA_real_ else
      sum(if_else(is_daytime, at_home, NA_real_), na.rm = TRUE),
    minutes_not_home_daytime = if (daytime_rows == 0) NA_real_ else
      sum(if_else(is_daytime, 1 - at_home, NA_real_), na.rm = TRUE),
    homestay_daytime_pct = if (daytime_rows == 0) {
      NA_real_
    } else {
      round(
        100 * sum(at_home == 1 & is_daytime, na.rm = TRUE) /
          sum(!is.na(at_home) & is_daytime),
        2
      )
    },

    # Home stay: nighttime (22:00-05:00)
    nighttime_rows = sum(is_nighttime, na.rm = TRUE),
    minutes_at_home_nighttime = sum(if_else(is_nighttime, at_home, NA_real_), na.rm = TRUE),
    minutes_not_home_nighttime = sum(if_else(is_nighttime, 1 - at_home, NA_real_), na.rm = TRUE),
    homestay_nighttime_pct = round(
      100 * sum(at_home == 1 & is_nighttime, na.rm = TRUE) /
        sum(!is.na(at_home) & is_nighttime),
      2
    ),

    # Distance from home
    mean_distance_from_home_day = mean(distance_to_home, na.rm = TRUE),
    max_distance_from_home_day = max(distance_to_home, na.rm = TRUE),
    mean_distance_from_home_daytime = if (daytime_rows == 0) NA_real_ else
      mean(if_else(is_daytime, distance_to_home, NA_real_), na.rm = TRUE),
    max_distance_from_home_daytime = if (daytime_rows == 0) NA_real_ else
      max(if_else(is_daytime, distance_to_home, NA_real_), na.rm = TRUE),
    mean_distance_from_home_nighttime = mean(if_else(is_nighttime, distance_to_home, NA_real_), na.rm = TRUE),
    max_distance_from_home_nighttime = max(if_else(is_nighttime, distance_to_home, NA_real_), na.rm = TRUE),

    # Environmental exposure
    mean_imperviousness_100m_day = mean(imperviousness_mean_100m, na.rm = TRUE),
    mean_ndvi_100m_day = mean(ndvi_mean_100m, na.rm = TRUE),
    mean_ndvi_green_area_100m_m2_day = mean(ndvi_green_area_100m_m2, na.rm = TRUE),
    mean_ndvi_green_share_100m_day = mean(ndvi_green_share_100m, na.rm = TRUE),
    mean_population_day = mean(population, na.rm = TRUE),
    .groups = "drop"
  )


# Aggregate to user level -------------------------------------------------
gps_userlevel <- gps_full_minute_data %>%
  group_by(ID) %>%
  summarise(
    # Data completeness
    total_rows = n(),
    filled_true = sum(filled == TRUE, na.rm = TRUE),
    filled_false = sum(filled == FALSE, na.rm = TRUE),
    perc_filled_true = round(100 * filled_true / total_rows, 2),
    perc_filled_false = round(100 * filled_false / total_rows, 2),

    # Movement
    Minutes_slow_kmh_user = sum(`Minutes_<20_kmh`, na.rm = TRUE),
    Minutes_fast_kmh_user = sum(`Minutes_>20_kmh`, na.rm = TRUE),
    Minutes_Stationary_user = sum(Minutes_Stationary, na.rm = TRUE),
    # Daily cumulative-distance columns reset at midnight. Summing the
    # minute-level distances therefore gives the correct total across all
    # participant-days; max(cumulative_distance) would retain only the longest
    # single day.
    cumulative_distance_user = round(sum(distances, na.rm = TRUE) / 1000, 3),
    cumulative_distance_slow_user = round(
      sum(if_else(speed_kmh < 20, distances, 0), na.rm = TRUE) / 1000,
      3
    ),
    cumulative_distance_fast_user = round(
      sum(if_else(speed_kmh > 20, distances, 0), na.rm = TRUE) / 1000,
      3
    ),

    # Crowded areas and home stay
    crowded_area_minutes_user = sum(crowded_area, na.rm = TRUE),
    pedestrian_minutes_user = sum(pedestrian, na.rm = TRUE),
    shop_minutes_user = sum(shop, na.rm = TRUE),
    railway_minutes_user = sum(railway, na.rm = TRUE),
    minutes_at_home_user = sum(at_home, na.rm = TRUE),
    minutes_not_home_user = sum(1 - at_home, na.rm = TRUE),
    homestay_user_pct = round(
      100 * sum(at_home == 1, na.rm = TRUE) / sum(!is.na(at_home)),
      2
    ),

    # Distance from home and environmental exposure
    mean_distance_from_home_user = mean(distance_to_home, na.rm = TRUE),
    max_distance_from_home_user = max(distance_to_home, na.rm = TRUE),
    mean_imperviousness_100m_user = mean(imperviousness_mean_100m, na.rm = TRUE),
    mean_ndvi_100m_user = mean(ndvi_mean_100m, na.rm = TRUE),
    mean_ndvi_green_area_100m_m2_user = mean(ndvi_green_area_100m_m2, na.rm = TRUE),
    mean_ndvi_green_share_100m_user = mean(ndvi_green_share_100m, na.rm = TRUE),
    mean_population_user = mean(population, na.rm = TRUE),
    .groups = "drop"
  )


# Aggregate cluster indicators from one row per participant-day ------------
# The cluster script stores the same daily summaries on every minute of a
# participant-day. Summing those columns in gps_full_minute_data would therefore
# count each daily value once per minute. Aggregate the already de-duplicated
# daily summaries instead.
cluster_userlevel <- gps_daylevel %>%
  group_by(ID) %>%
  summarise(
    # DBSCAN is run separately for each day, so this is the mean number of
    # day-specific places rather than a count of recurring places across days.
    mean_daily_unique_cluster_count_user = if (all(is.na(day_unique_cluster_count))) {
      NA_real_
    } else {
      mean(day_unique_cluster_count, na.rm = TRUE)
    },
    total_cluster_changes_user = if (all(is.na(day_total_cluster_changes))) {
      NA_real_
    } else {
      sum(day_total_cluster_changes, na.rm = TRUE)
    },
    mean_time_at_cluster_user = if (all(is.na(day_mean_time_at_cluster))) {
      NA_real_
    } else {
      mean(day_mean_time_at_cluster, na.rm = TRUE)
    },
    total_time_in_noise_user = if (all(is.na(day_total_time_in_noise))) {
      NA_real_
    } else {
      sum(day_total_time_in_noise, na.rm = TRUE)
    },
    .groups = "drop"
  )

gps_userlevel <- gps_userlevel %>%
  left_join(cluster_userlevel, by = "ID")


# Save results ------------------------------------------------------------
write_csv2(gps_full_minute_data, here("Results/gps_full_minute_data.csv"))
write_csv2(gps_daylevel, here("Results/gps_daylevel.csv"))
write_csv2(gps_userlevel, here("Results/gps_userlevel.csv"))


# Confirmation message ----------------------------------------------------
message("05_merge_and_aggregate.R: GPS datasets merged and aggregated successfully")
