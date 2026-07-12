# Datawrangling.R
#
# This script cleans and harmonizes the tutorial GPS input table.
#
# Main processing steps:
# 1. GPS timestamp conversion and minute-level selection.
# 2. Minute-wise completion for stationary periods.

# GPS data wrangling ------------------------------------------------------
## Select one row per minute with best GPS accuracy ####
gps_df_minute <- gps_df %>%
  # Round timestamp down to the minute
  mutate(timestamp_minute = floor_date(timestamp, unit = "minute")) %>%
  group_by(ID, timestamp_minute) %>%
  # Keep the row with the lowest accuracy per minute
  slice_min(order_by = accuracy_m, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  # Move timestamp_minute to the 3rd column
  relocate(timestamp_minute, .after = timestamp)

## Fill missing minutes for stationary periods ####
gps_df_filled <- gps_df_minute %>%
  group_by(ID) %>%
  # Create a complete sequence of minutes per user
  complete(
    timestamp_minute = seq(
      from = min(timestamp_minute),
      to   = max(timestamp_minute),
      by   = "1 min"
    )
  ) %>%
  # Mark rows that were originally present
  mutate(filled = is.na(latitude)) %>%
  # Carry forward the original values except for movement_flag
  fill(latitude, longitude, accuracy_m, timestamp, .direction = "down") %>%
  # Set movement_flag to 0 in all filled rows
  mutate(movement_flag = if_else(filled, 0, movement_flag)) %>%
  # Rename timestamp
  rename(last_gps_signal = timestamp) %>%
  ungroup() %>%
  arrange(ID, timestamp_minute)

# Save wrangled data -----------------------------------------------------
write_csv2(gps_df_filled, here("interims/gps_df_filled.csv"))

# Confirmation message ----------------------------------------------------
message("03_Datawrangling.R: Tutorial GPS input cleaned successfully")
