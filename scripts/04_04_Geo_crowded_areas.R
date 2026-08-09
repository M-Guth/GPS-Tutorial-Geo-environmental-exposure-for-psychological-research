# Geo_crowded_areas.R
#
# This script creates crowded-area indicators from OpenStreetMap features.
#
# Workflow:
# 1. Read and process one GeoJSON export from Overpass Turbo.
# 2. Buffer points/lines and keep polygons.
# 3. Classify features into crowded-area types based on OSM tags.
# 4. Compute per-point intersection indicators for each type.
# 5. Derive a combined `crowded_area` indicator.
#
# Data source:
# OpenStreetMap (OSM) data accessed via Overpass API
# https://overpass-turbo.eu/
#
# (c) OpenStreetMap contributors
# Data licensed under the Open Database License (ODbL):
# https://www.openstreetmap.org/copyright


# Load input data if needed -------------------------------------------------
if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_04_Geo_crowded_areas.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- readr::read_csv2(
    here("interims/geo/gps_df_geo_distance.csv"),
    show_col_types = FALSE
  )
  message("04_04_Geo_crowded_areas.R: gps_df_geo loaded from interims/geo/gps_df_geo_distance.csv")
}

# Functions ---------------------------------------------------------------
## Function to process the GeoJSON ####
# - Buffer points (50 m)
# - Buffer lines (10 m)
# - Keep polygons unchanged
# - Add crowded-area type columns from OSM tags
# - Keep only geometry + type
process_geojson <- function(file_path) {

  # Read file
  x <- st_read(file_path, quiet = TRUE)

  # Transform to CRS 25832
  x <- st_transform(x, 25832)

  # Ensure valid geometries
  x <- st_make_valid(x)

  # Determine geometry type
  geom_type <- st_geometry_type(x)

  # Apply geometry-specific buffering
  point_idx <- geom_type %in% c("POINT", "MULTIPOINT")
  line_idx <- geom_type %in% c("LINESTRING", "MULTILINESTRING")

  x_buffered <- list()

  if (any(point_idx)) {
    x_buffered <- c(x_buffered, list(st_buffer(x[point_idx, ], 50)))
  }

  if (any(line_idx)) {
    x_buffered <- c(x_buffered, list(st_buffer(x[line_idx, ], 10)))
  }

  if (any(!point_idx & !line_idx)) {
    x_buffered <- c(x_buffered, list(x[!point_idx & !line_idx, ]))
  }

  x <- do.call(rbind, x_buffered)

  # Classify features based on the Overpass query used for this tutorial
  x$is_pedestrian <- !is.na(x$highway) & x$highway == "pedestrian"
  x$is_shop <- (!is.na(x$shop)) |
    (!is.na(x$building) & x$building %in% c("retail", "supermarket")) |
    (!is.na(x$landuse) & x$landuse == "retail")
  x$is_railway <- (!is.na(x$railway) & x$railway == "station") |
    (!is.na(x$public_transport) & x$public_transport == "station")

  type_layers <- list(
    pedestrian = x[x$is_pedestrian, ],
    shop = x[x$is_shop, ],
    railway = x[x$is_railway, ]
  )

  type_layers <- imap(type_layers, function(layer, layer_name) {
    if (nrow(layer) == 0) {
      return(NULL)
    }

    layer$type <- layer_name
    layer[, c("type", "geometry")]
  })

  type_layers <- compact(type_layers)

  if (length(type_layers) == 0) {
    stop("No crowded-area features found in ", file_path)
  }

  do.call(rbind, type_layers)
}


# Create crowded areas ----------------------------------------------------
# Path to raw GeoJSON
input_file <- here("geodata/crowded_areas/raw/overpass_turbo_export.geojson")

# Process GeoJSON
combined_buffered <- process_geojson(input_file)

## Save combined crowded areas ####
output_path <- here("geodata/crowded_areas/combined")
output_file <- file.path(output_path, "crowded_areas.gpkg")

st_write(
  combined_buffered,
  output_file,
  delete_dsn = TRUE
)


# Spatial Join with EMA Points --------------------------------------------
gps_sf <- st_as_sf(
  gps_df_geo,
  coords = c("longitude", "latitude"),
  crs = 4326,
  remove = FALSE
) %>%
  st_transform(25832)

# Make sure combined_buffered is in same CRS
combined_buffered <- st_transform(combined_buffered, 25832)

# Create empty columns for each type
types <- unique(combined_buffered$type)

for (t in types) {
  gps_sf[[t]] <- 0
}

# Spatial join / intersection: set 1 if point inside any geometry of type
for (t in types) {
  polys <- combined_buffered %>% filter(type == t)
  gps_sf[[t]] <- as.integer(lengths(st_intersects(gps_sf, polys)) > 0)
}

# crowded_area = 1 if any of type columns = 1
gps_sf$crowded_area <- as.integer(
  rowSums(
    as.data.frame(gps_sf[, types, drop = TRUE]),
    na.rm = TRUE
  ) > 0
)

# Convert back to tibble and keep all crowded-area type indicators
gps_df_geo_crowded_areas <- gps_sf %>%
  st_drop_geometry() %>%
  dplyr::select(ID, timestamp_minute, all_of(types), crowded_area)


# Clean up workspace to free memory ---------------------------------------
rm(list = intersect(c("gps_sf", "combined_buffered", "output_path", "output_file"), ls()))
gc()


# Write result to file -----------------------------------------------------
write.csv2(gps_df_geo_crowded_areas, here("interims/geo/gps_df_geo_crowded_areas.csv"))


# Confirmation message ----------------------------------------------------
message("Geo_crowded_areas.R: crowded area interaction calculated successfully")
