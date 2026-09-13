# load_raw_data.R
#
# This script loads the simulated GPS input data from the raw_data folder
# and prepares it for the tutorial pipeline.

input_file <- here("raw_data", "basel_gps_data_simulated.csv")

if (!file.exists(input_file)) {
  stop(
    "Input file not found: ", input_file,
    call. = FALSE
  )
}

message("02_load_raw_data.R: Loading simulated GPS CSV from ", input_file)

gps_df <- read_csv(
  input_file,
  col_types = cols(
    latitude = col_double(),
    longitude = col_double(),
    movement_flag = col_double(),
    accuracy_m = col_double(),
    timestamp = col_character(),
    ID = col_character()
  )
) %>%
  mutate(
    # The simulator exports Basel local wall-clock time without an offset.
    # Parse it explicitly so readr does not silently assume UTC.
    timestamp = ymd_hms(timestamp, tz = "Europe/Zurich")
  )

message("02_load_raw_data.R: Tutorial GPS input loaded and saved successfully")
