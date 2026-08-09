# Geo_uniqueplaces.R
#
# This script derives place-based mobility indicators from GPS data
# using DBSCAN clustering on a daily participant level.

# Functions ---------------------------------------------------------------

## Function for clustering ####
# 1. extracts coordinates from input and adds it to data_sf
# 2. the eps parameter specifies the distance in meter threshold for defining the 
# neighborhood, while minPts sets the minimum number of points in a 
# neighborhood to be considered as a core point.
cluster_function <- function(x) {
  data_sf <- x %>% st_coordinates()
  cluster_number = dbscan::dbscan(data_sf, eps = 25, minPts = 20)$cluster
  return (data.frame(cluster_number=cluster_number))
}

# Load input data if needed -------------------------------------------------
if (exists("gps_df_geo", inherits = TRUE)) {
  message("04_02_Geo_uniqueplaces.R: gps_df_geo already loaded")
} else {
  gps_df_geo <- readr::read_csv2(
    here("interims/geo/gps_df_geo_distance.csv"),
    show_col_types = FALSE
  )
  message("04_02_Geo_uniqueplaces.R: gps_df_geo loaded from interims/geo/gps_df_geo_distance.csv")
}

# Cluster analysis for places and variance --------------------------------
gps_cluster <- gps_df_geo %>%
  dplyr::select(ID, date, timestamp_minute, latitude, longitude)

# Create simple feature object for spatial operations
gps_cluster_sf<-st_as_sf(gps_cluster, 
                         coords=c("longitude","latitude"),crs=4326) %>% 
  st_transform(25832)

# DBSCAN cluster analysis
clusters <- gps_cluster_sf %>%
  group_by(ID, date) %>%
  group_modify(~ bind_cols(.x, cluster_function(.x))) %>% 
  ungroup() %>% 
  dplyr::select(ID, date, timestamp_minute, cluster_number) %>% 
  mutate(cluster_id= paste0(ID, "_", date, "_", "c_",cluster_number)) 

## Group and summarize unique cluster IDs ####
unique_cluster_counts <- clusters %>%
  filter(cluster_number != 0) %>%
  group_by(ID, date) %>%
  summarize(day_unique_cluster_count = n_distinct(cluster_id))

## Count how often cluster IDs change ####
total_cluster_changes <- clusters %>%
  filter(cluster_number != 0) %>%
  group_by(ID, date) %>%
  summarize(day_total_cluster_changes = sum(cluster_id != lag(cluster_id, default = first(cluster_id))))

## Sum time in clusters ####
cluster_time <- clusters %>%
  filter(cluster_number != 0) %>%
  group_by(ID, date, cluster_id) %>%
  summarise(time_at_cluster = n()) %>%
  ungroup() 

cluster_time_mean <- cluster_time %>%
  group_by(ID, date) %>%
  summarise(day_mean_time_at_cluster = mean(time_at_cluster)) %>%
  ungroup()

noise_time <- clusters %>%
  filter(cluster_number == 0) %>%
  group_by(ID, date) %>%
  summarise(
    day_total_time_in_noise = n(),
    .groups = "drop"
  )

## Merge all cluster dataframes ####
cluster_final<-unique_cluster_counts %>% 
  left_join(total_cluster_changes, by = c("ID", "date")) %>%
  left_join(cluster_time_mean, by = c("ID", "date")) %>% 
  left_join(noise_time, by = c("ID", "date"))

## Merge with main dataframe ####
clusters_final_df<-clusters %>% 
  left_join(cluster_final,by = c("ID", "date"))

# Save interim results ----------------------------------------------------
write_csv2(clusters_final_df,here("interims/geo/clusters_final_df.csv"))

# Remove data from workspace ----------------------------------------------
rm(noise_time,
   cluster_time_mean,
   total_cluster_changes,
   unique_cluster_counts,
   clusters,
   gps_cluster,
   gps_cluster_sf)

gc()

# Confirmation message ----------------------------------------------------
message("Geo_uniqueplaces.R: DBSCAN and unique places variables calculated successfully")
