# Geo_Distance.R
#
# This script calculates distance and movement indicators from GPS data.
#
# For each user and each timestamp (at 1-minute intervals), the following are computed:
# 1. Distance to the previous GPS point using the Haversine formula (in meters).
# 2. Speed per minute in km/h based on the distance travelled.
# 3. Cumulative distance per user per day.
# 4. Movement categories per minute:
#    - Minutes_<20_kmh: moving slowly (speed > 0.001 km/h and < 20 km/h)
#    - Minutes_>20_kmh: moving fast (speed > 20 km/h)
#    - Minutes_Stationary: stationary (speed <= 0.001 km/h)
# 5. Cumulative distance separated by movement type:
#    - cumulative_distance_slow: sum of distances where speed is slow
#    - cumulative_distance_fast: sum of distances where speed is fast
#
# The purpose of this processing is to quantify daily mobility patterns
# and movement intensity per participant, including stationary periods.
#
# 04_01_Geo_Distance.R
#
# This script calculates distance and movement indicators from GPS data.

# Functions ---------------------------------------------------------------
## Haversine distance function ####
distanceGPS <- function(lat1, lon1, lat2, lon2) {
  
  # Convert degrees to radians
  lat1 <- lat1 * pi/180
  lat2 <- lat2 * pi/180
  lon2 <- lon2 * pi/180
  lon1 <- lon1 * pi/180
  
  # Haversine formula;
  R = 6371000
  a <- sin(0.5 * (lat2 - lat1))
  b <- sin(0.5 * (lon2 - lon1))
  d <- 2 * R * asin(sqrt(a * a + cos(lat1) * cos(lat2) * b * b))
  
  return(d)
  
}

# Load input data if needed -------------------------------------------------
if (exists("gps_df_filled", inherits = TRUE)) {
  message("04_01_Geo_Distance.R: gps_df_filled already loaded")
} else {
  gps_df_filled <- readr::read_csv2(
    here("interims/gps_df_filled.csv"),
    show_col_types = FALSE
  )
  message("04_01_Geo_Distance.R: gps_df_filled loaded from interims/gps_df_filled.csv")
}

# Calculate distance indicators --------------------------------------------
# CRITICAL: arrange() by ID and timestamp_minute BEFORE group_by() to ensure
# distances are calculated within each user's chronological sequence, not across users
gps_df_geo <- gps_df_filled %>%
  mutate(date = as.Date(timestamp_minute)) %>%
  arrange(ID, timestamp_minute) %>%
  group_by(ID, date) %>%
  mutate(
    distances = c(0, distanceGPS(
      lat1 = latitude[-length(latitude)],
      lon1 = longitude[-length(longitude)],
      lat2 = latitude[-1],
      lon2 = longitude[-1]
    )),
    speed_kmh = distances * 60 / 1000,
    cumulative_distance = cumsum(distances),
    `Minutes_<20_kmh` = ifelse(speed_kmh > 0.001 & speed_kmh < 20, 1, 0),
    `Minutes_>20_kmh` = ifelse(speed_kmh > 20, 1, 0),
    Minutes_Stationary = ifelse(speed_kmh > 0, 0, 1),
    cumulative_distance_slow = cumsum(ifelse(speed_kmh < 20, distances, 0)),
    cumulative_distance_fast = cumsum(ifelse(speed_kmh > 20, distances, 0))
  ) %>%
  ungroup() 

# Save result to file (will be loaded by 04_5 and 04_6) --------------------
write.csv2(gps_df_geo, here("interims/geo/gps_df_geo_distance.csv"))

# Confirmation message ----------------------------------------------------
message("Geo_Distance.R: Distance calculated successfully")




