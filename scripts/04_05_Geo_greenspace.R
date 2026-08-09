# 04_05_Geo_greenspace.R
#
# This script calculates vegetation exposure around GPS points using
# Sentinel-2 NDVI raster data for Basel.
#
# Workflow:
# 1. Load GPS data with distance indicators.
# 2. Convert GPS coordinates to spatial features.
# 3. Generate the Basel NDVI raster in Google Earth Engine (reference code).
# 4. Load the exported Basel NDVI raster.
# 5. Reproject data to EPSG:3035 for buffer and area calculations.
# 6. Create 100 m buffers around GPS points.
# 7. Calculate mean NDVI per buffer.
# 8. Calculate dense-vegetation area (NDVI > 0.5).
# 9. Calculate vegetation share per buffer.
#
# Output variables:
# - ndvi_mean_100m
# - ndvi_green_area_100m_m2
# - ndvi_green_share_100m
#
# Data source:
# Sentinel-2 Surface Reflectance Harmonized
# (COPERNICUS/S2_SR_HARMONIZED)


# Load GPS data with distance indicators ----------------------------------

# Load from 04_01_Geo_Distance.R to avoid dependency on global variables

if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_05_Geo_greenspace.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- read.csv2(
    here("interims/geo/gps_df_geo_distance.csv")
  )
  message(
    paste0(
      "04_05_Geo_greenspace.R: gps_df_geo loaded from ",
      "interims/geo/gps_df_geo_distance.csv"
    )
  )
}


# Convert GPS data to Simple Feature (SF) ---------------------------------

gps_sf <- gps_df_geo %>%
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326
  )


# Google Earth Engine preprocessing ---------------------------------------
#
# The NDVI raster used below is generated from Sentinel-2 Surface
# Reflectance imagery in Google Earth Engine (GEE). The following code is
# provided as a reference and is NOT executed by R.
#
# To reproduce the raster:
# 1. Open the Google Earth Engine Code Editor:
#    https://code.earthengine.google.com/
# 2. Paste the JavaScript code below into the editor.
# 3. Make sure the Basel-Stadt boundary asset is available in your
#    GEE account or replace the asset path with your own study-area layer.
# 4. Run the script and export the NDVI raster to Google Drive.
# 5. Save the exported GeoTIFF as:
#    geodata/ndvi/Basel_NDVI.tif
#
# -------------------------------------------------------------------------
# BEGIN GOOGLE EARTH ENGINE JAVASCRIPT
# -------------------------------------------------------------------------
#
# // Cloud masking function for Sentinel-2
# function maskS2clouds(image) {
#   var qa = image.select('QA60');
#
#   var cloudBitMask = 1 << 10;
#   var cirrusBitMask = 1 << 11;
#
#   var mask = qa.bitwiseAnd(cloudBitMask).eq(0)
#     .and(qa.bitwiseAnd(cirrusBitMask).eq(0));
#
#   return image.updateMask(mask).divide(10000);
# }
#
#
# // Load Basel-Stadt boundary from GEE asset
# var basel_stadt = ee.FeatureCollection(
#   'projects/ee-marvinguth2/assets/basel_stadt'
# );
#
#
# // Filter Sentinel-2 SR Harmonized collection for Basel-Stadt
# var S2_BS = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
#   .filterDate('2023-04-01', '2023-09-30')
#   .filterBounds(basel_stadt)
#   .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 20))
#   .map(maskS2clouds)
#   .median();
#
#
# // Calculate NDVI and clip to Basel-Stadt
# var NDVI = S2_BS
#   .normalizedDifference(['B8', 'B4'])
#   .rename('NDVI')
#   .clip(basel_stadt);
#
#
# // Select RGB and NIR bands and clip to Basel-Stadt
# var RGBNIR = S2_BS
#   .select(['B4', 'B3', 'B2', 'B8'])
#   .clip(basel_stadt);
#
#
# // Center the map on Basel-Stadt
# Map.centerObject(basel_stadt, 11);
#
#
# // Add Basel-Stadt boundary to the map
# Map.addLayer(
#   basel_stadt,
#   {color: 'red'},
#   'Basel-Stadt Boundary'
# );
#
#
# // Add NDVI layer to the map
# Map.addLayer(
#   NDVI,
#   {min: 0, max: 1, palette: ['FFFFFF', '115718']},
#   'S2 NDVI Basel-Stadt'
# );
#
#
# // Print images to the console
# print('NDVI Image:', NDVI);
# print('RGB+NIR Image:', RGBNIR);
#
#
# // Export NDVI as GeoTIFF clipped to Basel-Stadt
# Export.image.toDrive({
#   image: NDVI,
#   description: 'Basel_NDVI',
#   folder: 'GEE_Exports',
#   fileNamePrefix: 'Basel_NDVI',
#   region: basel_stadt.geometry(),
#   scale: 10,
#   crs: 'EPSG:4326',
#   maxPixels: 1e13
# });
#
#
# // Optional: export RGB+NIR as GeoTIFF clipped to Basel-Stadt
# Export.image.toDrive({
#   image: RGBNIR,
#   description: 'Basel_RGBNIR',
#   folder: 'GEE_Exports',
#   fileNamePrefix: 'Basel_RGBNIR',
#   region: basel_stadt.geometry(),
#   scale: 10,
#   crs: 'EPSG:4326',
#   maxPixels: 1e13
# });
#
# -------------------------------------------------------------------------
# END GOOGLE EARTH ENGINE JAVASCRIPT
# -------------------------------------------------------------------------


# Load NDVI raster ---------------------------------------------------------

# Load the GeoTIFF previously generated and exported from Google Earth Engine

ndvi_raster <- rast(
  here("geodata/ndvi/Basel_NDVI.tif")
)


# Reproject raster to metric CRS ------------------------------------------

# EPSG:3035 uses metric units and is therefore suitable for buffer and
# area calculations.

ndvi_raster_3035 <- project(
  ndvi_raster,
  "EPSG:3035"
)

# Transform GPS points to the same CRS

gps_sf <- st_transform(
  gps_sf,
  3035
)


# Create 100 m buffers around GPS points ----------------------------------

if (!exists("buffers_sf_3035")) {

  # Convert to SpatVector for faster buffering
  gps_vect <- vect(gps_sf)

  # Create 100 m buffers
  buffers_vect <- buffer(
    gps_vect,
    width = 100
  )

  # Convert back to sf
  buffers_sf_3035 <- st_as_sf(
    buffers_vect
  )

  message("buffers_sf_3035 created.")

} else {
  message(
    "buffers_sf_3035 already exists. Skipping conversion and buffering."
  )
}


# Calculate mean NDVI within each buffer ----------------------------------

ndvi_mean <- exact_extract(
  ndvi_raster_3035,
  buffers_sf_3035,
  "mean"
)


# Identify NDVI values > 0.5 (dense vegetation) ---------------------------

# Create binary raster

ndvi_green <- ndvi_raster_3035 > 0.5


# Calculate pixel area -----------------------------------------------------

pixel_res <- res(
  ndvi_raster_3035
)

pixel_area <- pixel_res[1] * pixel_res[2]


# Calculate green vegetation area per buffer ------------------------------

# Sum NDVI > 0.5 pixel coverage within each buffer

green_pixel_count <- exact_extract(
  ndvi_green,
  buffers_sf_3035,
  "sum"
)

# Convert pixel count to square meters

green_area_m2 <- green_pixel_count * pixel_area


# Calculate percentage of green area within the buffer --------------------

# Total area of a 100 m radius circular buffer

buffer_area_m2 <- pi * 100^2

# Percentage of vegetation area

green_share <- (
  green_area_m2 / buffer_area_m2
) * 100


# Combine results with original dataset -----------------------------------

gps_ndvi <- gps_df_geo %>%
  ungroup() %>%
  mutate(
    ndvi_mean_100m = ndvi_mean,
    ndvi_green_area_100m_m2 = green_area_m2,
    ndvi_green_share_100m = green_share
  )


# Save results -------------------------------------------------------------

write.csv2(
  gps_ndvi,
  here("interims/geo/gps_ndvi.csv")
)


# Clean up workspace to free memory ---------------------------------------

rm(
  list = intersect(
    c(
      "gps_sf",
      "gps_vect",
      "buffers_vect",
      "ndvi_raster",
      "ndvi_raster_3035",
      "ndvi_green",
      "ndvi_mean",
      "green_pixel_count",
      "green_area_m2",
      "green_share",
      "pixel_res",
      "pixel_area",
      "buffer_area_m2"
    ),
    ls()
  )
)

gc()


# Confirmation message ----------------------------------------------------

message(
  "04_05_Geo_greenspace.R: 100 m buffer NDVI metrics calculated successfully."
)
