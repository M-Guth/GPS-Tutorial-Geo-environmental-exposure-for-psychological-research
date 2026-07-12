# Setup.R
#
# This script initializes the tutorial environment.
#
# It activates renv when available and loads the packages used by the
# tutorial processing pipeline.


# renv --------------------------------------------------------------------
if (!file.exists("renv/activate.R")) {
  stop("renv/activate.R not found. Please open Tutorial_Repo.Rproj first.")
}

source("renv/activate.R")

# Package imports ---------------------------------------------------------
packages <- c(
  "dplyr",        # Core data wrangling verbs for joins, grouping, and summaries
  "tidyr",        # Completes minute-level GPS sequences and reshapes tables
  "purrr",        # Applies functions across files and nested data structures
  "readr",        # Reads and writes CSV files with consistent parsing
  "tibble",       # Creates tidy data frames used across the pipeline
  "ggplot2",      # Produces calendar plots and other visualisations
  "here",         # Builds project-relative file paths
  "lubridate",    # Parses and converts timestamps and dates
  "dbscan",       # Clustering algorithm for place identification
  "ggTimeSeries", # Builds calendar heatmaps from day-level data
  "viridis",      # Provides colour scales for readable plots
  "sf",           # Handles spatial point and geometry operations
  "raster",       # Reads raster geodata such as imperviousness layers
  "exactextractr",# Extracts raster statistics inside GPS buffers
  "terra"         # Buffers spatial points and works with raster/vector data
)

for (pkg in packages) {
  library(pkg, character.only = TRUE)
}

# Confirmation message ----------------------------------------------------
message("01_Setup.R: Packages loaded successfully.")
