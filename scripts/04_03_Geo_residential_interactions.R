# 04_03_Geo_residential_interactions.R
#
# This script identifies each user's home location with an adaptation of the
# binned mean-shift algorithm (A4) described by Verma et al. (2024).
#
# Main processing steps:
# 1. Select all minute-level locations between 01:00 and 05:00 local time.
# 2. Calculate one spatial centroid for each 30-minute interval.
# 3. Apply mean-shift clustering with a 250 m flat-kernel bandwidth.
# 4. Define home as the centroid of the largest cluster.
# 5. Calculate distance to home and flag locations within 200 m as at home.


# Parameters --------------------------------------------------------------
home_crs <- 2056
mean_shift_bandwidth <- 250
mean_shift_tolerance <- 1
mean_shift_iterations <- 100
minimum_night_points <- 10
home_radius <- 200


# Load input data if needed -----------------------------------------------
if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_03_Geo_residential_interactions.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- readr::read_csv2(
    here("interims/geo/gps_df_geo_distance.csv"),
    show_col_types = FALSE
  )
  message("04_03_Geo_residential_interactions.R: gps_df_geo loaded from interims/geo/gps_df_geo_distance.csv")
}


# Functions ---------------------------------------------------------------
## Euclidean distance in projected coordinates ####
point_distance <- function(points, center) {
  sqrt(
    (points[, 1] - center[1])^2 +
      (points[, 2] - center[2])^2
  )
}


## Binned mean-shift home estimation ####
mean_shift_home <- function(
  data,
  bandwidth = mean_shift_bandwidth,
  tolerance = mean_shift_tolerance,
  max_iterations = mean_shift_iterations
) {
  points <- as.matrix(data[, c("x", "y")])

  # Start mean shift once from every 30-minute centroid.
  candidate_modes <- t(apply(points, 1, function(starting_point) {
    center <- starting_point

    for (iteration in seq_len(max_iterations)) {
      distances <- point_distance(points, center)
      points_in_window <- points[distances <= bandwidth, , drop = FALSE]
      updated_center <- colMeans(points_in_window)

      if (sqrt(sum((updated_center - center)^2)) <= tolerance) {
        center <- updated_center
        break
      }

      center <- updated_center
    }

    center
  }))

  # Retain one representative for modes that are within one bandwidth of
  # each other, giving priority to modes supported by more interval centroids.
  mode_support <- apply(candidate_modes, 1, function(mode) {
    sum(point_distance(points, mode) <= bandwidth)
  })

  mode_order <- order(
    -mode_support,
    candidate_modes[, 1],
    candidate_modes[, 2]
  )

  modes <- matrix(numeric(0), ncol = 2)

  for (index in mode_order) {
    candidate <- candidate_modes[index, ]

    if (
      nrow(modes) == 0 ||
        all(point_distance(modes, candidate) > bandwidth)
    ) {
      modes <- rbind(modes, candidate)
    }
  }

  # Assign every interval centroid to its closest mode.
  distances_to_modes <- sapply(seq_len(nrow(modes)), function(index) {
    point_distance(points, modes[index, ])
  })

  distances_to_modes <- matrix(
    distances_to_modes,
    nrow = nrow(points),
    ncol = nrow(modes)
  )

  cluster <- max.col(-distances_to_modes, ties.method = "first")
  cluster_size <- tabulate(cluster, nbins = nrow(modes))
  largest_cluster <- which.max(cluster_size)

  # Home is the centroid of the largest cluster.
  colMeans(points[cluster == largest_cluster, , drop = FALSE])
}


## Haversine distance function ####
distanceGPS <- function(lat1, lon1, lat2, lon2) {
  lat1 <- lat1 * pi / 180
  lat2 <- lat2 * pi / 180
  lon1 <- lon1 * pi / 180
  lon2 <- lon2 * pi / 180

  earth_radius <- 6371000
  latitude_difference <- sin(0.5 * (lat2 - lat1))
  longitude_difference <- sin(0.5 * (lon2 - lon1))

  2 * earth_radius * asin(sqrt(
    latitude_difference^2 +
      cos(lat1) * cos(lat2) * longitude_difference^2
  ))
}


# Select nighttime locations ---------------------------------------------
# All locations in the regularised minute-level sequence are included,
# irrespective of whether they were observed or filled.
nighttimes <- gps_df_geo %>%
  mutate(
    timestamp_local = with_tz(timestamp_minute, "Europe/Zurich"),
    hour_local = hour(timestamp_local),
    time_bin = floor_date(timestamp_local, unit = "30 minutes")
  ) %>%
  filter(
    hour_local >= 1,
    hour_local < 5,
    is.finite(latitude),
    is.finite(longitude)
  ) %>%
  group_by(ID) %>%
  filter(n() >= minimum_night_points) %>%
  ungroup()

if (nrow(nighttimes) == 0) {
  stop("No user has at least ten valid locations between 01:00 and 05:00.")
}


# Calculate 30-minute centroids ------------------------------------------
# EPSG:2056 provides metric coordinates for the 250 m bandwidth.
nighttime_sf <- nighttimes %>%
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  ) %>%
  st_transform(home_crs)

nighttime_coordinates <- st_coordinates(nighttime_sf)

night_bins <- nighttime_sf %>%
  st_drop_geometry() %>%
  mutate(
    x = nighttime_coordinates[, 1],
    y = nighttime_coordinates[, 2]
  ) %>%
  group_by(ID, time_bin) %>%
  summarise(
    x = mean(x),
    y = mean(y),
    .groups = "drop"
  )


# Identify home locations -------------------------------------------------
home_xy <- night_bins %>%
  group_by(ID) %>%
  group_modify(~ {
    home <- mean_shift_home(.x)
    tibble(home_x = home[1], home_y = home[2])
  }) %>%
  ungroup()

# Convert home locations back to longitude and latitude.
home_sf <- home_xy %>%
  st_as_sf(
    coords = c("home_x", "home_y"),
    crs = home_crs,
    remove = FALSE
  ) %>%
  st_transform(4326)

home_coordinates <- st_coordinates(home_sf)

home_locations <- home_xy %>%
  mutate(
    home_longitude = home_coordinates[, 1],
    home_latitude = home_coordinates[, 2]
  ) %>%
  dplyr::select(ID, home_latitude, home_longitude)

home_locations_by_user <- gps_df_geo %>%
  distinct(ID) %>%
  left_join(home_locations, by = "ID")


# Calculate distance from home -------------------------------------------
gps_df_geo_home <- gps_df_geo %>%
  left_join(home_locations_by_user, by = "ID") %>%
  mutate(
    distance_to_home = distanceGPS(
      lat1 = latitude,
      lon1 = longitude,
      lat2 = home_latitude,
      lon2 = home_longitude
    ),
    # The 200 m home radius is independent of the 250 m clustering bandwidth.
    at_home = if_else(distance_to_home <= home_radius, 1, 0)
  )


# Write result to file ----------------------------------------------------
gps_df_geo_home_for_saving <- gps_df_geo_home %>%
  dplyr::select(
    ID,
    timestamp_minute,
    home_latitude,
    home_longitude,
    distance_to_home,
    at_home
  )

write_csv2(
  gps_df_geo_home_for_saving,
  here("interims/geo/gps_df_geo_home.csv")
)


# Clean up workspace ------------------------------------------------------
rm(
  nighttimes,
  nighttime_sf,
  nighttime_coordinates,
  night_bins,
  home_xy,
  home_sf,
  home_coordinates,
  home_locations
)
gc()


# Confirmation message ---------------------------------------------------
message("04_03_Geo_residential_interactions.R: home locations and at-home indicators calculated successfully")
