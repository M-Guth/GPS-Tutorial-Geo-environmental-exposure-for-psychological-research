# 06_merge_questionnaire_daylevel.R
#
# Read the externally created questionnaire file, aggregate momentary
# responses, and merge them with the GPS day- and user-level outputs. This
# numbered repository script does not simulate or overwrite source data in
# questionnaire_data/.


# Load GPS and the single questionnaire source file -----------------------
gps_daylevel <- read.csv2(
  here("Results/gps_daylevel.csv")
) %>%
  mutate(date = as.Date(date))

gps_userlevel <- read.csv2(
  here("Results/gps_userlevel.csv")
)

questionnaire_data <- read.csv2(
  here("questionnaire_data/questionnaire_data.csv")
) %>%
  mutate(date = as.Date(date))

# Validate keys and source ranges before aggregation ----------------------
required_questionnaire_columns <- c(
  "ID", "assessment_type", "date", "completed",
  "ema_positive_affect", "ema_negative_affect", "ema_stress",
  "ema_rumination", "ema_activity_engagement", "ema_social_connectedness",
  paste0("who_", 1:5), "who5_raw", "who5_percent",
  paste0("phq_", 1:4), "phq4_depression", "phq4_anxiety",
  "phq4_total", "phq4_severity"
)

missing_questionnaire_columns <- setdiff(
  required_questionnaire_columns,
  names(questionnaire_data)
)

if (length(missing_questionnaire_columns) > 0) {
  stop(
    "Questionnaire source columns are missing: ",
    paste(missing_questionnaire_columns, collapse = ", "),
    call. = FALSE
  )
}

momentary_records <- questionnaire_data %>%
  dplyr::filter(assessment_type == "momentary") %>%
  mutate(ema_completed = completed)

baseline_followup_records <- questionnaire_data %>%
  dplyr::filter(assessment_type %in% c("baseline", "followup")) %>%
  mutate(assessment = assessment_type)

stopifnot(
  all(questionnaire_data$assessment_type %in% c("baseline", "momentary", "followup")),
  all(momentary_records$ID %in% gps_daylevel$ID),
  all(baseline_followup_records$ID %in% gps_daylevel$ID),
  all(momentary_records$ema_completed %in% c(0L, 1L)),
  all(momentary_records$ema_positive_affect %in% 1:7 | is.na(momentary_records$ema_positive_affect)),
  all(baseline_followup_records$who5_raw >= 0 & baseline_followup_records$who5_raw <= 25),
  all(baseline_followup_records$phq4_total >= 0 & baseline_followup_records$phq4_total <= 12)
)


# Aggregate momentary responses to participant-day ------------------------
momentary_day <- momentary_records %>%
  group_by(ID, date) %>%
  summarise(
    ema_prompts_scheduled = n(),
    ema_prompts_completed = sum(ema_completed),
    ema_compliance_pct = round(100 * mean(ema_completed), 1),
    ema_positive_affect_mean = if (all(is.na(ema_positive_affect))) NA_real_ else mean(ema_positive_affect, na.rm = TRUE),
    ema_negative_affect_mean = if (all(is.na(ema_negative_affect))) NA_real_ else mean(ema_negative_affect, na.rm = TRUE),
    ema_stress_mean = if (all(is.na(ema_stress))) NA_real_ else mean(ema_stress, na.rm = TRUE),
    ema_rumination_mean = if (all(is.na(ema_rumination))) NA_real_ else mean(ema_rumination, na.rm = TRUE),
    ema_activity_engagement_mean = if (all(is.na(ema_activity_engagement))) NA_real_ else mean(ema_activity_engagement, na.rm = TRUE),
    ema_social_connectedness_mean = if (all(is.na(ema_social_connectedness))) NA_real_ else mean(ema_social_connectedness, na.rm = TRUE),
    .groups = "drop"
  )

baseline_followup_day <- baseline_followup_records %>%
  dplyr::select(
    ID, date, assessment,
    who_1:who_5, who5_raw, who5_percent,
    phq_1:phq_4, phq4_depression, phq4_anxiety, phq4_total, phq4_severity
  )

questionnaire_day <- momentary_day %>%
  full_join(baseline_followup_day, by = c("ID", "date")) %>%
  relocate(ID, date) %>%
  arrange(ID, date)


# Merge questionnaire and GPS day-level data ------------------------------
gps_daylevel_questionnaire <- gps_daylevel %>%
  left_join(questionnaire_day, by = c("ID", "date"))


# Aggregate questionnaire variables to participant level ------------------
momentary_user <- momentary_day %>%
  group_by(ID) %>%
  summarise(
    ema_prompts_scheduled_user = sum(ema_prompts_scheduled),
    ema_prompts_completed_user = sum(ema_prompts_completed),
    ema_compliance_pct_user = round(
      100 * ema_prompts_completed_user / ema_prompts_scheduled_user,
      1
    ),
    ema_positive_affect_mean_user = if (all(is.na(ema_positive_affect_mean))) NA_real_ else mean(ema_positive_affect_mean, na.rm = TRUE),
    ema_negative_affect_mean_user = if (all(is.na(ema_negative_affect_mean))) NA_real_ else mean(ema_negative_affect_mean, na.rm = TRUE),
    ema_stress_mean_user = if (all(is.na(ema_stress_mean))) NA_real_ else mean(ema_stress_mean, na.rm = TRUE),
    ema_rumination_mean_user = if (all(is.na(ema_rumination_mean))) NA_real_ else mean(ema_rumination_mean, na.rm = TRUE),
    ema_activity_engagement_mean_user = if (all(is.na(ema_activity_engagement_mean))) NA_real_ else mean(ema_activity_engagement_mean, na.rm = TRUE),
    ema_social_connectedness_mean_user = if (all(is.na(ema_social_connectedness_mean))) NA_real_ else mean(ema_social_connectedness_mean, na.rm = TRUE),
    .groups = "drop"
  )

baseline_followup_user <- baseline_followup_records %>%
  dplyr::select(
    ID, assessment,
    who5_raw, who5_percent,
    phq4_depression, phq4_anxiety, phq4_total
  ) %>%
  tidyr::pivot_wider(
    names_from = assessment,
    values_from = c(
      who5_raw, who5_percent,
      phq4_depression, phq4_anxiety, phq4_total
    ),
    names_glue = "{.value}_{assessment}"
  )

questionnaire_user <- momentary_user %>%
  full_join(baseline_followup_user, by = "ID") %>%
  relocate(ID)

gps_userlevel_questionnaire <- gps_userlevel %>%
  left_join(questionnaire_user, by = "ID")


# Save merged outputs ------------------------------------------------------
write.csv2(
  gps_daylevel_questionnaire,
  here("Results/gps_daylevel_questionnaire.csv"),
  row.names = FALSE,
  na = ""
)
write.csv2(
  gps_userlevel_questionnaire,
  here("Results/gps_userlevel_questionnaire.csv"),
  row.names = FALSE,
  na = ""
)
message("06_merge_questionnaire_daylevel.R: Questionnaire merge completed")
message("  - Results/gps_daylevel_questionnaire.csv: merged GPS and day-level self-report data")
message("  - Results/gps_userlevel_questionnaire.csv: merged GPS and participant-level self-report data")
