# run_all.R
#
# This script executes the tutorial pipeline in the correct order.


# Pipeline script list -----------------------------------------------------
pipeline_scripts <- c(
  "scripts/01_Setup.R",
  "scripts/02_load_raw_data.R",
  "scripts/03_Datawrangling.R",
  "scripts/04_01_Geo_Distance.R",
  "scripts/04_02_Geo_uniqueplaces.R",
  "scripts/04_03_Geo_residential_interactions.R",
  "scripts/04_04_Geo_crowded_areas.R",
  "scripts/04_05_Geo_greenspace.R",
  "scripts/04_06_Geo_Imperviousness.R",
  "scripts/04_07_Geo_Population_density.R",
  "scripts/05_merge_and_aggregate.R",
  "scripts/06_merge_questionnaire_daylevel.R",
  "scripts/07_statistics.R"
)

# Run pipeline -------------------------------------------------------------
for (script_path in pipeline_scripts) {
  message("Running: ", script_path)
  source(script_path)
}

message("run_all.R: Full pipeline executed successfully")
