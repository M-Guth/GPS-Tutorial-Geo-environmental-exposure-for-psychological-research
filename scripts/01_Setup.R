# Setup.R
#
# This script initializes the tutorial environment.
#
# It activates renv when available and loads the packages used by the
# tutorial processing pipeline.


# renv --------------------------------------------------------------------
skip_renv <- identical(Sys.getenv("TUTORIAL_SKIP_RENV"), "1")

if (!skip_renv) {
  if (!file.exists("renv/activate.R")) {
    stop("renv/activate.R not found. Please open Tutorial_Repo.Rproj first.")
  }
  source("renv/activate.R")
} else {
  message("01_Setup.R: Skipping renv activation because TUTORIAL_SKIP_RENV=1")
}

# Package imports ---------------------------------------------------------
# Keep literal library() calls: renv can detect these without executing R.
# A library(pkg, character.only = TRUE) loop hides packages from snapshots.
library(dplyr)         # Joins, grouping, and summaries
library(tidyr)         # Completes minute-level sequences and reshapes tables
library(purrr)         # Applies functions across files and nested data
library(readr)         # Reads and writes delimited files
library(tibble)        # Creates tidy data frames
library(ggplot2)       # Statistical visualisations
library(here)          # Project-relative file paths
library(lubridate)     # Timestamps, dates, and time zones
library(dbscan)        # Place identification
library(viridis)       # Colour scales
library(sf)            # Spatial points and geometry operations
library(raster)        # Raster geodata
library(exactextractr) # Raster statistics inside GPS buffers
library(terra)         # Spatial buffers and raster/vector operations
library(nlme)          # Random-intercept model in 07_statistics.R
library(gridExtra)     # Combines the two panels in Figure 3

# Confirmation message ----------------------------------------------------
message("01_Setup.R: Packages loaded successfully.")
