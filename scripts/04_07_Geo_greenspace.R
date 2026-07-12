# Geo_NDVI.R
#
# This script calculates vegetation exposure around GPS points using
# Sentinel-2 NDVI raster data for Basel.
#
# Workflow:
# 1. Load GPS data with distance indicators.
# 2. Convert GPS coordinates to spatial features.
# 3. Load the Basel NDVI raster.
# 4. Reproject data to EPSG:3035 for buffer and area calculations.
# 5. Create 100 m buffers around GPS points.
# 6. Calculate mean NDVI per buffer.
# 7. Calculate dense-vegetation area (NDVI > 0.5).
# 8. Calculate vegetation share per buffer.
#
# Output variables:
# - ndvi_mean_100m
# - ndvi_green_area_100m_m2
# - ndvi_green_share_100m
#
# Data source: Sentinel-2 NDVI, Basel subset


# Load GPS data with distance indicators ----------------------------------
# Load from 04_1_Geo_Distance.R to avoid dependency on global variables
if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_07_Geo_greenspace.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- read.csv2(here("interims/geo/gps_df_geo_distance.csv"))
  message("04_07_Geo_greenspace.R: gps_df_geo loaded from interims/geo/gps_df_geo_distance.csv")
}


# Convert GPS data to Simple Feature (SF) ---------------------------------
gps_sf <- gps_df_geo %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)


# Load NDVI raster --------------------------------------------------------
ndvi_raster <- rast(here("geodata/ndvi/Basel_NDVI.tif"))


# Reproject raster to metric CRS (meters) for correct area calculations ----
ndvi_raster_3035 <- project(ndvi_raster, "EPSG:3035")

# Transform GPS points to same CRS
gps_sf <- st_transform(gps_sf, 3035)


# Create 100 m buffers around GPS points ----------------------------------
if (!exists("buffers_sf_3035")) {
  
  # Convert to SpatVector for faster buffering
  gps_vect <- vect(gps_sf)
  
  # Create 100 m buffers
  buffers_vect <- buffer(gps_vect, width = 100)
  
  # Convert back to sf
  buffers_sf_3035 <- st_as_sf(buffers_vect)
  
  message("buffers_sf_3035 created.")
  
} else {
  message("buffers_sf_3035 already exists. Skipping conversion and buffering.")
}


# Calculate mean NDVI within each buffer ----------------------------------
ndvi_mean <- exact_extract(ndvi_raster_3035, buffers_sf_3035, "mean")


# Identify NDVI values > 0.5 (dense vegetation) ---------------------------
# Create binary raster
ndvi_green <- ndvi_raster_3035 > 0.5


## Calculate pixel area ####
pixel_res <- res(ndvi_raster_3035)
pixel_area <- pixel_res[1] * pixel_res[2]


## Calculate green vegetation area per buffer ####
# Sum NDVI > 0.5 pixel coverage within each buffer
green_pixel_count <- exact_extract(ndvi_green, buffers_sf_3035, "sum")

# Convert pixel count to square meters
green_area_m2 <- green_pixel_count * pixel_area


## Calculate percentage of green area within the buffer ####
# Total area of a 100 m radius buffer
buffer_area_m2 <- pi * 100^2

# Percentage of vegetation area
green_share <- (green_area_m2 / buffer_area_m2) * 100


# Combine results with original dataset -----------------------------------
gps_ndvi <- gps_df_geo %>%
  ungroup() %>%
  mutate(
    ndvi_mean_100m = ndvi_mean,
    ndvi_green_area_100m_m2 = green_area_m2,
    ndvi_green_share_100m = green_share
  )


# Save results ------------------------------------------------------------
write.csv2(gps_ndvi, here("interims/geo/gps_ndvi.csv"))


# Clean up workspace to free memory ---------------------------------------
rm(list = intersect(
  c(
    "gps_sf", "gps_vect", "buffers_vect", "ndvi_raster",
    "ndvi_raster_3035", "ndvi_green", "ndvi_mean",
    "green_pixel_count", "green_area_m2", "green_share",
    "pixel_res", "pixel_area", "buffer_area_m2"
  ),
  ls()
))
gc()


# Confirmation message ----------------------------------------------------
message("Geo_NDVI.R: 100m buffer NDVI metrics calculated successfully.")
