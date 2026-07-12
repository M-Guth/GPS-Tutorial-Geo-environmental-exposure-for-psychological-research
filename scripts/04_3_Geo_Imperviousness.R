# Geo_Imperviousness.R
#
# This script calculates mean imperviousness around each GPS point
# within a 100 m buffer.
#
# Data source:
# Imperviousness Density 2024 (raster 10 m and 100 m), Europe, 3-yearly
# DOI (100 m): https://doi.org/10.2909/f0bcb6f0-d775-4218-bec1-13adea01ff8f

# Load input data if needed -------------------------------------------------
if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_3_Geo_Imperviosness.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- readr::read_csv2(
    here("interims/geo/gps_df_geo_distance.csv"),
    show_col_types = FALSE
  )
  message("04_3_Geo_Imperviosness.R: gps_df_geo loaded from interims/geo/gps_df_geo_distance.csv")
}

# Calculate Mean Imperviousness in 100m Buffer around EMA Points ----------
# Convert GPS data to Simple Feature (SF)
gps_sf <- gps_df_geo %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Load Imperviousness raster
imperviousness_raster <- raster(here("geodata/imperviousness/CLMS_NVLCC_IMD_S2024_R10m_E41N27_03035_V01_R01.tif"))

# Align CRS between raster and GPS points
gps_sf <- st_transform(gps_sf, crs(imperviousness_raster))

## Create buffers ####
# Check if buffers_sf already exists
if (!exists("buffers_sf")) {

  # Convert GPS SF points to SpatVector for faster buffering
  gps_vect <- vect(gps_sf)  # SF → SpatVector

  # Create 100m buffer around GPS points
  buffers_vect <- buffer(gps_vect, width = 100)

  # Convert SpatVector buffers back to SF for exact_extract
  buffers_sf <- st_as_sf(buffers_vect)

  message("buffers_sf created.")

} else {
  message("buffers_sf already exists. Skipping conversion and buffering.")
}

## Calculate mean imperviousness per buffer ####
imperviousness_mean <- exact_extract(imperviousness_raster, buffers_sf, fun= "mean")

# Create tidyverse dataframe with results
gps_imperviousness <- gps_df_geo %>%
  ungroup() %>%
  mutate(imperviousness_mean_100m = imperviousness_mean)

# Write result to file -----------------------------------------------------
write.csv2(gps_imperviousness,here("interims/geo/gps_imperviousness.csv"))

# Clean up workspace to save memory ---------------------------------------
rm(gps_sf, gps_vect, buffers_vect)
gc()

# Notify that processing is complete --------------------------------------
message("Geo_imperviousness.R: 100m buffer mean imperviousness calculated successfully")

