# run_all.R
#
# This script executes the tutorial pipeline in the correct order.
#
# Set `run_raw_import <- FALSE` if interim CSV files already exist and raw
# input import should be skipped.

# Options -----------------------------------------------------------------
run_raw_import <- TRUE

# Pipeline script list -----------------------------------------------------
pipeline_scripts <- c(
  "scripts/01_Setup.R",
  if (run_raw_import) "scripts/02_load_raw_data.R",
  "scripts/03_Datawrangling.R",
  "scripts/04_1_Geo_Distance.R",
  "scripts/04_2_Geo_uniqueplaces.R",
  "scripts/04_3_Geo_Imperviousness.R",
  "scripts/04_04_Geo_Population_density.R",
  "scripts/04_05_Geo_crowded_areas.R",
  "scripts/04_06_Geo_residential_interactions.R",
  "scripts/04_07_Geo_greenspace.R",
  "scripts/05_merge_and_aggregate.R",
  "scripts/06_descriptive_analysis.R",
  "scripts/07_calendar_plots_daylevel.R",
  "scripts/08_merge_questionnaire_daylevel.R"
)

# Run pipeline -------------------------------------------------------------
for (script_path in pipeline_scripts) {
  message("Running: ", script_path)
  source(script_path)
}

message("run_all.R: Full pipeline executed successfully")
