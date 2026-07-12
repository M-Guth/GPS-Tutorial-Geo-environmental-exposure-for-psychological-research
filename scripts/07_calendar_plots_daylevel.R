# calendar_plots_daylevel.R
#
# This script creates calendar heatmaps for selected day-level variables.
#
# One plot is written for each participant and variable. The plots use the
# day-level dataset created in 05_merge_and_aggregate.R and therefore use the
# project-wide participant identifier `ID`.
#
# Output:
# calendar_plots/<variable>/<ID>.png

# Configuration -----------------------------------------------------------

output_base_dir <- here("calendar_plots")

# Set to NULL to auto-detect all numeric day-level variables except `ID` and `date`.
# To restrict the output, replace NULL with a character vector of variable names.
variables_to_plot <- NULL

# Human-readable labels for the legends and plot titles.
variable_labels <- c(
  total_rows = "Total minute records per day",
  filled_true = "Interpolated/filled minute records",
  filled_false = "Observed GPS minute records",
  perc_filled_true = "Interpolated/filled GPS data (%)",
  perc_filled_false = "Observed GPS data (%)",

  Minutes_slow_kmh_day = "Minutes slow (<20 km/h)",
  Minutes_fast_kmh_day = "Minutes fast (>20 km/h)",
  Minutes_Stationary_day = "Minutes stationary",
  steps_day = "Steps per day",
  cumulative_distance_day = "Cumulative distance (km)",
  cumulative_distance_slow_day = "Cumulative slow distance (km)",
  cumulative_distance_fast_day = "Cumulative fast distance (km)",

  day_unique_cluster_count = "Unique cluster count",
  day_total_cluster_changes = "Cluster changes",
  day_mean_time_at_cluster = "Mean time at cluster",
  day_total_time_in_noise = "Time in noise cluster (min)",

  crowded_area_minutes_day = "Minutes in crowded areas",
  pedestrian_minutes_day = "Minutes on pedestrian ways",
  shop_minutes_day = "Minutes near shops",
  railway_minutes_day = "Minutes near railway/public transport stations",

  minutes_at_home_day = "Minutes at home",
  minutes_not_home_day = "Minutes not at home",
  homestay_whole_day_pct = "Homestay whole day (%)",
  daytime_rows = "Minute records in daytime window",
  minutes_at_home_daytime = "Minutes at home during daytime",
  minutes_not_home_daytime = "Minutes not at home during daytime",
  homestay_daytime_pct = "Homestay daytime (%)",
  nighttime_rows = "Minute records in nighttime window",
  minutes_at_home_nighttime = "Minutes at home during nighttime",
  minutes_not_home_nighttime = "Minutes not at home during nighttime",
  homestay_nighttime_pct = "Homestay nighttime (%)",
  mean_distance_from_home_day = "Mean distance from home (m)",
  max_distance_from_home_day = "Maximum distance from home (m)",
  mean_distance_from_home_daytime = "Mean distance from home daytime (m)",
  max_distance_from_home_daytime = "Maximum distance from home daytime (m)",
  mean_distance_from_home_nighttime = "Mean distance from home nighttime (m)",
  max_distance_from_home_nighttime = "Maximum distance from home nighttime (m)",

  mean_imperviousness_100m_day = "Mean imperviousness (%) within 100m buffer",
  mean_ndvi_100m_day = "Mean NDVI within 100m buffer",
  mean_ndvi_green_area_100m_m2_day = "Mean dense vegetation area within 100m buffer (m2)",
  mean_ndvi_green_share_100m_day = "Mean dense vegetation share within 100m buffer (%)",
  mean_population_day = "Mean population within 100m buffer"
)

# Helper functions --------------------------------------------------------

convert_numeric_like_columns <- function(df, protected_cols = c("ID", "date")) {
  # read.csv2() usually parses decimal-comma columns correctly. This helper
  # catches remaining character columns that still contain numeric values.
  value_cols <- setdiff(names(df), protected_cols)

  df %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(value_cols),
        ~ {
          if (is.numeric(.x) || is.integer(.x)) {
            return(as.numeric(.x))
          }

          if (is.logical(.x)) {
            return(as.numeric(.x))
          }

          if (!is.character(.x)) {
            return(.x)
          }

          normalized <- trimws(.x)
          normalized <- gsub(",", ".", normalized, fixed = TRUE)
          numeric_x <- suppressWarnings(as.numeric(normalized))

          if (all(is.na(.x) | !is.na(numeric_x))) {
            numeric_x
          } else {
            .x
          }
        }
      )
    )
}

prepare_daylevel_data <- function(df) {
  required_cols <- c("ID", "date")

  if (!all(required_cols %in% names(df))) {
    stop(
      "gps_daylevel must contain the columns: ",
      paste(required_cols, collapse = ", ")
    )
  }

  df %>%
    dplyr::mutate(
      ID = as.character(ID),
      date = as.Date(date)
    ) %>%
    convert_numeric_like_columns()
}

get_variable_label <- function(variable_name) {
  # Fall back to the raw column name if no nicer label is defined.
  if (variable_name %in% names(variable_labels)) {
    unname(variable_labels[[variable_name]])
  } else {
    variable_name
  }
}

get_legend_title <- function(variable_name, variable_label) {
  # Keep compact legends for the most common units.
  dplyr::case_when(
    grepl("minute", variable_name, ignore.case = TRUE) ~ "Minutes",
    grepl("_pct$|percent|share", variable_name, ignore.case = TRUE) ~ "%",
    grepl("distance", variable_name, ignore.case = TRUE) ~ "Meters",
    TRUE ~ variable_label
  )
}

plot_calendar_variable <- function(user_df, variable_name, variable_label, participant_id) {
  plot_data <- user_df %>%
    dplyr::select(date, dplyr::all_of(variable_name)) %>%
    dplyr::arrange(date)

  ggTimeSeries::ggplot_calendar_heatmap(
    dtDateValue = plot_data,
    cDateColumnName = "date",
    cValueColumnName = variable_name,
    vcGroupingColumnNames = "Year",
    dayBorderSize = 0.45,
    dayBorderColour = "black",
    monthBorderSize = 2.5,
    monthBorderColour = "black",
    monthBorderLineEnd = "round"
  ) +
    viridis::scale_fill_viridis(
      name = get_legend_title(variable_name, variable_label),
      option = "C"
    ) +
    facet_wrap(~Year, ncol = 1) +
    ggplot2::labs(
      title = paste0(variable_label, " for ", participant_id),
      x = "Month",
      y = "DoW"
    ) +
    ggplot2::theme_gray(base_size = 14) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(size = 12),
      axis.text.y = ggplot2::element_text(size = 12),
      strip.text = ggplot2::element_text(face = "bold", size = 14),
      plot.title = ggplot2::element_text(face = "bold", size = 20),
      legend.title = ggplot2::element_text(size = 14),
      legend.text = ggplot2::element_text(size = 12)
    )
}

# Load data ---------------------------------------------------------------

if (!exists("gps_daylevel")) {
  gps_file <- here("Results", "gps_daylevel.csv")

  if (!file.exists(gps_file)) {
    stop("gps_daylevel not found in memory and file is missing: ", gps_file)
  }

  gps_daylevel <- read.csv2(gps_file, check.names = FALSE)
  message("gps_daylevel loaded from Results/gps_daylevel.csv")
} else {
  message("gps_daylevel already exists in memory. Skipping load.")
}

gps_daylevel <- prepare_daylevel_data(gps_daylevel)

# Determine variables to plot ---------------------------------------------

if (is.null(variables_to_plot)) {
  variables_to_plot <- gps_daylevel %>%
    dplyr::select(-ID, -date) %>%
    dplyr::select(where(is.numeric)) %>%
    names()
} else {
  missing_variables <- setdiff(variables_to_plot, names(gps_daylevel))

  if (length(missing_variables) > 0) {
    warning(
      "Skipping variables that are not present in gps_daylevel: ",
      paste(missing_variables, collapse = ", ")
    )
  }

  variables_to_plot <- intersect(variables_to_plot, names(gps_daylevel))
}

if (length(variables_to_plot) == 0) {
  stop("No numeric day-level variables available for calendar plots.")
}

if (!dir.exists(output_base_dir)) {
  dir.create(output_base_dir, recursive = TRUE)
}

# Generate plots ----------------------------------------------------------

participant_ids <- gps_daylevel %>%
  dplyr::distinct(ID) %>%
  dplyr::arrange(ID) %>%
  dplyr::pull(ID)

for (var_name in variables_to_plot) {
  var_label <- get_variable_label(var_name)

  var_dir <- file.path(output_base_dir, var_name)

  if (!dir.exists(var_dir)) {
    dir.create(var_dir, recursive = TRUE)
  }

  for (pid in participant_ids) {
    df_pid <- gps_daylevel %>%
      dplyr::filter(ID == pid) %>%
      dplyr::arrange(date)

    # Skip variables that are empty or fully missing for this participant.
    if (nrow(df_pid) == 0 || all(is.na(df_pid[[var_name]]))) {
      next
    }

    p <- plot_calendar_variable(
      user_df = df_pid,
      variable_name = var_name,
      variable_label = var_label,
      participant_id = pid
    )

    ggplot2::ggsave(
      filename = file.path(var_dir, paste0(pid, ".png")),
      plot = p,
      width = 20,
      height = 10,
      units = "cm",
      dpi = 300
    )
  }
}

# Confirmation message ----------------------------------------------------

message("07_calendar_plots_daylevel.R: Calendar plots saved in calendar_plots/")
