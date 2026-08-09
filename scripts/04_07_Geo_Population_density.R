# Geo_Population_density.R
#
# This script calculates mean population density around each GPS point
# within a 100 m buffer using Eurostat population grid data.
#
# Data source:
# https://ec.europa.eu/eurostat/web/gisco/geodata/population-distribution/population-grids
# Pigaiani, Cristian; Freire, Sergio; Batista, Filipe (2026):
# JRC-ESTAT Census Population Grid 2021.
# European Commission, Joint Research Centre [Dataset].
# DOI: https://doi.org/10.2905/JRC.VP18KXG
# DOI: https://doi.org/10.2905/98336641-fd1c-4992-8c7b-c470dd5eb81e

# Load input data if needed -------------------------------------------------
if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_07_Geo_Population_density.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- readr::read_csv2(
    here("interims/geo/gps_df_geo_distance.csv"),
    show_col_types = FALSE
  )
  message("04_07_Geo_Population_density.R: gps_df_geo loaded from interims/geo/gps_df_geo_distance.csv")
}

# Calculate mean population density within a 100 m buffer around EMA points -----
# Convert GPS data to Simple Feature (SF)
gps_sf <- gps_df_geo %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Load Basel-Stadt population raster
population_raster <- raster(here("geodata/pop_grid_100m/basel_stadt_population_2021_100m.tif"))

# Align CRS between raster and GPS points
gps_sf <- st_transform(gps_sf, crs(population_raster))


## Create buffers ####
# Check if buffers_sf already exists
if (!exists("buffers_sf")) {

  # Convert GPS SF points to SpatVector for faster buffering
  gps_vect <- vect(gps_sf)  # SF → SpatVector

  # Create 100 m buffer around GPS points
  buffers_vect <- buffer(gps_vect, width = 100)

  # Convert SpatVector buffers back to SF for further processing
  buffers_sf <- st_as_sf(buffers_vect)

  message("buffers_sf created.")

} else {
  message("buffers_sf already exists. Skipping conversion and buffering.")
}

# Ensure buffers use the same CRS as the population raster
buffers_sf <- st_transform(buffers_sf, crs(population_raster))

# Calculate mean population per buffer -------------------------------------
population_mean <- exact_extract(population_raster, buffers_sf, fun = "mean")
population_cells <- exact_extract(
  population_raster,
  buffers_sf,
  fun = function(values, coverage_fraction) sum(!is.na(values))
)

# Create tidyverse dataframe with results
gps_population <- gps_df_geo %>%
  ungroup() %>%
  mutate(
    avg_T = round(population_mean, 2),
    grid_cells = population_cells
  )


# Clean up workspace to free memory ---------------------------------------
rm(list = intersect(c("gps_sf", "gps_vect", "buffers_vect", "population_raster"), ls()))
gc()


# Write result to file -----------------------------------------------------
write.csv2(gps_population, here("interims/geo/gps_population.csv"))


# Confirmation message ----------------------------------------------------
message("Geo_Population_density.R: 100 m buffer mean population density calculated successfully")
