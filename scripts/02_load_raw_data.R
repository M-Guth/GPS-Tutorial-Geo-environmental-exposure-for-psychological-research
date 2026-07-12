# load_raw_data.R
#
# This script loads the simulated GPS input data from the raw_data folder
# and prepares it for the tutorial pipeline.

input_file <- here("raw_data", "basel_gps_data_simulated_v4.csv")

if (!file.exists(input_file)) {
  stop(
    "Input file not found: ", input_file,
    call. = FALSE
  )
}

message("02_load_raw_data.R: Loading simulated GPS CSV from ", input_file)

gps_df <- read_csv(input_file)

message("02_load_raw_data.R: Tutorial GPS input loaded and saved successfully")


