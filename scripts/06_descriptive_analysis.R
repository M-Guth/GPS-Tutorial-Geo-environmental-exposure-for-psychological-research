# descriptive_analysis.R
#
# This script calculates descriptive completeness statistics for minute-level
# GPS data at day and participant level.
#
# For each participant and day, the following are computed:
# 1. total_rows: total number of observations per day
#    (should be 1440 if every minute is represented)
# 2. filled_true / filled_false: number of rows where `filled` is TRUE or FALSE
# 3. perc_filled_true / perc_filled_false: percentage of filled rows per day
# 4. n_days: total number of days recorded per participant
#
# In addition, overall completeness indicators are calculated to summarize how
# much of the minute-level series consists of imputed/fill-forward data.


# Helper functions --------------------------------------------------------
## Convert filled to logical ####
# The column can be logical already, or character after CSV import.
as_filled_logical <- function(x) {
  as.character(x) %in% c("TRUE", "T", "1", "true", "True")
}

## Parse timestamps robustly ####
# gps_full_minute_data may contain ISO timestamps such as
# 2025-03-01T08:27:00Z. ymd_hms() keeps minute precision for those strings.
parse_timestamp_utc <- function(x) {
  parsed <- lubridate::ymd_hms(x, tz = "UTC", quiet = TRUE)
  
  if (all(is.na(parsed))) {
    parsed <- as.POSIXct(x, tz = "UTC")
  }
  
  parsed
}


# Ensure minute-level dataset is available --------------------------------
if (!exists("gps_full_minute_data", inherits = TRUE)) {
  gps_file <- here("Results/gps_full_minute_data.csv")
  
  if (!file.exists(gps_file)) {
    stop("gps_full_minute_data not found in memory and file is missing: ", gps_file)
  }
  
  gps_full_minute_data <- read.csv2(gps_file, check.names = FALSE)
  message("gps_full_minute_data loaded from Results/gps_full_minute_data.csv")
} else {
  message("gps_full_minute_data already exists in memory. Skipping load.")
}


# Prepare variables -------------------------------------------------------
gps_full_minute_data <- gps_full_minute_data %>%
  mutate(
    ID = as.character(ID),
    timestamp_minute = parse_timestamp_utc(timestamp_minute),
    filled = as_filled_logical(filled),
    date = as.Date(timestamp_minute)
  )


# Aggregate by ID and date ------------------------------------------------
daily_summary <- gps_full_minute_data %>%
  group_by(ID, date) %>%
  summarise(
    total_rows = n(),                                     # total observations per day
    filled_true = sum(filled == TRUE, na.rm = TRUE),      # count of imputed/fill-forward rows
    filled_false = sum(filled == FALSE, na.rm = TRUE),    # count of observed GPS rows
    perc_filled_true = round(100 * filled_true / total_rows, 2),
    perc_filled_false = round(100 * filled_false / total_rows, 2),
    .groups = "drop"
  )


# Count number of days per participant ------------------------------------
days_per_user <- daily_summary %>%
  group_by(ID) %>%
  summarise(
    n_days = n(),                                         # number of unique days per participant
    complete_days_1440 = sum(total_rows == 1440),
    days_all_filled = sum(perc_filled_true == 100, na.rm = TRUE),
    days_any_filled = sum(filled_true > 0, na.rm = TRUE),
    days_less_than_50_percent_observed = sum(perc_filled_false < 50, na.rm = TRUE),
    mean_perc_filled_true = round(mean(perc_filled_true, na.rm = TRUE), 2),
    mean_perc_filled_false = round(mean(perc_filled_false, na.rm = TRUE), 2),
    .groups = "drop"
  )


# Overall completeness statistics -----------------------------------------
overall_completeness <- tibble(
  total_rows = nrow(gps_full_minute_data),
  filled_true = sum(gps_full_minute_data$filled == TRUE, na.rm = TRUE),
  filled_false = sum(gps_full_minute_data$filled == FALSE, na.rm = TRUE),
  perc_filled_true = round(100 * filled_true / total_rows, 2),
  perc_filled_false = round(100 * filled_false / total_rows, 2),
  total_days = nrow(daily_summary),
  days_all_filled = sum(daily_summary$perc_filled_true == 100, na.rm = TRUE),
  days_any_filled = sum(daily_summary$filled_true > 0, na.rm = TRUE),
  days_less_than_50_percent_observed = sum(daily_summary$perc_filled_false < 50, na.rm = TRUE)
)


# Preview first rows ------------------------------------------------------
head(daily_summary)
head(days_per_user)
overall_completeness


# Save results as CSV files -----------------------------------------------
write.csv2(daily_summary, here("Results/daily_summary.csv"), row.names = FALSE)
write.csv2(days_per_user, here("Results/days_per_user.csv"), row.names = FALSE)
write.csv2(overall_completeness, here("Results/overall_completeness.csv"), row.names = FALSE)


# Confirmation message ----------------------------------------------------
message("descriptive_analysis.R: Daily summary, days per participant, and overall completeness saved successfully.")
message("  - Filled/imputed rows: ", overall_completeness$filled_true, " (", overall_completeness$perc_filled_true, "%)")
message("  - Observed GPS rows: ", overall_completeness$filled_false, " (", overall_completeness$perc_filled_false, "%)")
message("  - Days with 100% filled data: ", overall_completeness$days_all_filled)
message("  - Days with any filled data: ", overall_completeness$days_any_filled)
message("  - Days with <50% observed GPS data: ", overall_completeness$days_less_than_50_percent_observed)
