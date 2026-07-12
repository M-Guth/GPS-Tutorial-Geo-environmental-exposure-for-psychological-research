# merge_questionnaire_daylevel.R
#
# Tutorial GPS-only fallback.
# The tutorial repository does not require questionnaire files to complete the
# workflow. This script simply copies the GPS outputs to the questionnaire
# targets so downstream examples can still run.

if (!file.exists(here("Results/gps_daylevel.csv")) || !file.exists(here("Results/gps_userlevel.csv"))) {
  stop("GPS aggregation outputs are missing. Run the merge and aggregate scripts first.", call. = FALSE)
}

gps_daylevel <- read_csv2(here("Results/gps_daylevel.csv"), show_col_types = FALSE)
gps_userlevel <- read_csv2(here("Results/gps_userlevel.csv"), show_col_types = FALSE)

write_csv2(gps_daylevel, here("Results/gps_daylevel_questionnaire.csv"))
write_csv2(gps_userlevel, here("Results/gps_userlevel_questionnaire.csv"))

message("08_merge_questionnaire_daylevel.R: Tutorial GPS-only outputs written successfully")
