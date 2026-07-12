# Residential_interactions.R
#
# This script identifies home locations and calculates distances from home for
# each GPS point.
#
# For each user, the following are computed:
# 1. Approximate home location using the geometric median of nighttime GPS
#    coordinates (between 01:00 and 05:00, when users are typically at home).
# 2. Distance from each GPS point to the identified home location using the
#    Haversine formula (in meters).
# 3. Home indicator variable:
#    - at_home: 1 if distance to home <= 200 meters, 0 otherwise


# Load input data if needed -------------------------------------------------
if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_05_Geo_crowded_areas.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- readr::read_csv2(
    here("interims/geo/gps_df_geo_distance.csv"),
    show_col_types = FALSE
  )
  message("04_05_Geo_crowded_areas.R: gps_df_geo loaded from interims/geo/gps_df_geo_distance.csv")
}

# Functions ---------------------------------------------------------------
## Weiszfeld algorithm for geometric median calculation ####
weiszfeld_median <- function(coords, tol = 1e-6, max_iter = 100) {
  # Remove rows with missing values
  coords <- coords[complete.cases(coords), ]

  if (nrow(coords) < 1) return(c(NA_real_, NA_real_))

  # Initialize with mean of all coordinates
  median_point <- colMeans(coords)

  for (i in 1:max_iter) {
    # Calculate Euclidean distances from current point to all coordinates
    distances <- sqrt(rowSums((coords - matrix(median_point, nrow(coords), 2, byrow = TRUE))^2))

    # If a point lies exactly on the median, return that point
    if (any(distances < tol)) {
      median_point <- coords[which.min(distances), ]
      break
    }

    # Weiszfeld update: calculate weighted average based on inverse distances
    weighted_coords <- coords / (distances + tol)
    weights <- 1 / (distances + tol)

    median_point_new <- colSums(weighted_coords) / sum(weights)

    # Convergence check: if change is smaller than tolerance, stop iteration
    if (sqrt(sum((median_point_new - median_point)^2)) < tol) {
      median_point <- median_point_new
      break
    }

    median_point <- median_point_new
  }

  return(median_point)
}

## Haversine distance function ####
distanceGPS <- function(lat1, lon1, lat2, lon2) {

  # Convert degrees to radians
  lat1 <- lat1 * pi / 180
  lat2 <- lat2 * pi / 180
  lon2 <- lon2 * pi / 180
  lon1 <- lon1 * pi / 180

  # Haversine formula: calculates shortest distance between two points on a sphere
  R <- 6371000
  a <- sin(0.5 * (lat2 - lat1))
  b <- sin(0.5 * (lon2 - lon1))
  d <- 2 * R * asin(sqrt(a * a + cos(lat1) * cos(lat2) * b * b))

  return(d)

}


# Approximate Home Locations ----------------------------------------------
# Filter for night times (between 01:00 and 05:00) to identify home location
nighttimes <- gps_df_geo %>%
  filter(
    hour(timestamp_minute) >= 1,
    hour(timestamp_minute) < 5
  )

# Calculate geometric median of nighttime coordinates per user
geometric_median_by_user <- nighttimes %>%
  dplyr::group_by(ID) %>%
  dplyr::summarise(
    median_latitude = weiszfeld_median(cbind(latitude, longitude))[1],
    median_longitude = weiszfeld_median(cbind(latitude, longitude))[2],
    .groups = "drop"
  ) %>%
  dplyr::select(ID, median_latitude, median_longitude)


# Calculate Distance from Home --------------------------------------------
# Join home coordinates to all GPS observations
gps_df_geo_home <- gps_df_geo %>%
  dplyr::left_join(
    geometric_median_by_user %>%
      dplyr::select(
        ID,
        home_latitude = median_latitude,
        home_longitude = median_longitude
      ),
    by = "ID"
  )

# Calculate haversine distance to home for each GPS point
# Also create binary indicator for whether user is at home (within 200 meters)
gps_df_geo_home <- gps_df_geo_home %>%
  dplyr::mutate(
    distance_to_home = distanceGPS(
      lat1 = latitude,
      lon1 = longitude,
      lat2 = home_latitude,
      lon2 = home_longitude
    ),
    at_home = dplyr::if_else(distance_to_home <= 200, 1, 0)
  )


# Clean up workspace to free memory ---------------------------------------
rm(nighttimes)
gc()


# Write result to file with home coordinates and indicators ----------------
gps_df_geo_home_for_saving <- gps_df_geo_home %>%
  dplyr::select(ID, timestamp_minute, home_latitude, home_longitude, distance_to_home, at_home)

write.csv2(gps_df_geo_home_for_saving, here("interims/geo/gps_df_geo_home.csv"))


# Confirmation message ----------------------------------------------------
message("Home_Location.R: Home locations and distances calculated successfully")
