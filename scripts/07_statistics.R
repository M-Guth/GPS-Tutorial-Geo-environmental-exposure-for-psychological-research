# 07_statistics.R
# Creates descriptive tables and an illustrative multilevel model.


# Load data ---------------------------------------------------------------
if (!exists("gps_daylevel", inherits = TRUE)) {
  gps_daylevel <- read.csv2(
    here::here("Results/gps_daylevel.csv"),
    check.names = FALSE
  )
}


# Median [Q1-Q3] ----------------------------------------------------------
median_iqr <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_character_)

  q <- round(stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE), 2)
  paste0(q[2], " [", q[1], "-", q[3], "]")
}


# Confidence intervals and effect sizes ---------------------------------
# For each fixed-effect t test, partial r is calculated as
# t / sqrt(t^2 + df). Its confidence interval uses inversion of the
# noncentral t distribution (the pivot method). This is useful for mixed
# models because it provides a unit-free effect size directly from the
# reported test statistic and denominator degrees of freedom.
partial_r_from_t <- function(t_value, df, conf_level = 0.95) {
  alpha <- 1 - conf_level
  probabilities <- c(alpha / 2, 1 - alpha / 2)

  ncp_fit <- suppressWarnings(
    stats::optim(
      par = 1.1 * rep(t_value, 2),
      fn = function(ncp) {
        quantiles <- stats::qt(
          p = probabilities,
          df = df,
          ncp = ncp
        )
        sum(abs(quantiles - t_value))
      },
      control = list(abstol = 1e-9)
    )
  )

  ncp_bounds <- sort(unname(ncp_fit$par))

  tibble::tibble(
    partial_r = t_value / sqrt(t_value^2 + df),
    partial_r_ci_lower = ncp_bounds[1] / sqrt(ncp_bounds[1]^2 + df),
    partial_r_ci_upper = ncp_bounds[2] / sqrt(ncp_bounds[2]^2 + df)
  )
}

format_coefficient <- function(x) {
  ifelse(abs(x) < 0.1, sprintf("%.3f", x), sprintf("%.2f", x))
}

format_p_value <- function(x) {
  ifelse(
    x < 0.001,
    "< .001",
    paste0("= ", sub("^0", "", sprintf("%.3f", x)))
  )
}


# Descriptive table -------------------------------------------------------
summarise_descriptives <- function(data) {
  data |>
    dplyr::summarise(
      participant_days = dplyr::n(),
      complete_days_1440 = sum(total_rows == 1440, na.rm = TRUE),
      observed_gps_pct = round(100 * sum(filled_false) / sum(total_rows), 1),
      carried_forward_pct = round(100 * sum(filled_true) / sum(total_rows), 1),
      distance_km_day = median_iqr(cumulative_distance_day),
      unique_places_day = median_iqr(day_unique_cluster_count),
      cluster_changes_day = median_iqr(day_total_cluster_changes),
      homestay_daytime_pct = median_iqr(homestay_daytime_pct),
      crowded_area_minutes_day = median_iqr(crowded_area_minutes_day),
      mean_ndvi_100m = median_iqr(mean_ndvi_100m_day),
      mean_imperviousness_100m_pct = median_iqr(mean_imperviousness_100m_day),
      mean_population_100m = median_iqr(mean_population_day),
      .groups = "drop"
    )
}

descriptive_statistics_table <- dplyr::bind_rows(
  gps_daylevel |>
    dplyr::group_by(ID) |>
    summarise_descriptives(),
  gps_daylevel |>
    summarise_descriptives() |>
    dplyr::mutate(ID = "Overall", .before = 1)
)


# Save table --------------------------------------------------------------
write.csv2(
  descriptive_statistics_table,
  here::here("Results/descriptive_statistics_table.csv"),
  row.names = FALSE
)


# Questionnaire table ----------------------------------------------------
if (!exists("gps_daylevel_questionnaire", inherits = TRUE)) {
  gps_daylevel_questionnaire <- read.csv2(
    here::here("Results/gps_daylevel_questionnaire.csv"),
    check.names = FALSE
  )
}

ema_data <- gps_daylevel_questionnaire |>
  dplyr::filter(!is.na(ema_prompts_scheduled))

summarise_ema <- function(data) {
  data |>
    dplyr::summarise(
      ema_days = dplyr::n(),
      ema_prompts_scheduled = sum(ema_prompts_scheduled),
      ema_prompts_completed = sum(ema_prompts_completed),
      ema_compliance_pct = round(100 * ema_prompts_completed / ema_prompts_scheduled, 1),
      positive_affect = median_iqr(ema_positive_affect_mean),
      negative_affect = median_iqr(ema_negative_affect_mean),
      stress = median_iqr(ema_stress_mean),
      rumination = median_iqr(ema_rumination_mean),
      activity_engagement = median_iqr(ema_activity_engagement_mean),
      social_connectedness = median_iqr(ema_social_connectedness_mean),
      .groups = "drop"
    )
}

questionnaire_table <- dplyr::bind_rows(
  ema_data |>
    dplyr::group_by(ID) |>
    summarise_ema(),
  ema_data |>
    summarise_ema() |>
    dplyr::mutate(ID = "Overall", .before = 1)
)

scores <- gps_daylevel_questionnaire |>
  dplyr::filter(assessment %in% c("baseline", "followup")) |>
  dplyr::select(ID, assessment, who5_percent, phq4_total) |>
  tidyr::pivot_wider(
    names_from = assessment,
    values_from = c(who5_percent, phq4_total)
  )

scores_overall <- tibble::tibble(
  ID = "Overall",
  who5_percent_baseline = median_iqr(scores$who5_percent_baseline),
  who5_percent_followup = median_iqr(scores$who5_percent_followup),
  phq4_total_baseline = median_iqr(scores$phq4_total_baseline),
  phq4_total_followup = median_iqr(scores$phq4_total_followup)
)

scores <- scores |>
  dplyr::mutate(dplyr::across(-ID, as.character)) |>
  dplyr::bind_rows(scores_overall)

descriptive_statistics_questionnaire_table <- questionnaire_table |>
  dplyr::left_join(scores, by = "ID")

write.csv2(
  descriptive_statistics_questionnaire_table,
  here::here("Results/descriptive_statistics_questionnaire_table.csv"),
  row.names = FALSE
)

message("Created both descriptive statistics tables")


# Illustrative multilevel model ------------------------------------------
# This is an inferential example using simulated tutorial data. It shows
# the workflow only and is not intended for substantive interpretation.
analysis_data <- gps_daylevel_questionnaire |>
  dplyr::filter(
    ema_prompts_completed >= 3,
    !is.na(mean_ndvi_100m_day),
    !is.na(ema_stress_mean),
    !is.na(perc_filled_false)
  ) |>
  dplyr::group_by(ID) |>
  dplyr::mutate(
    ndvi_between = mean(mean_ndvi_100m_day),
    ndvi_within = mean_ndvi_100m_day - ndvi_between
  ) |>
  dplyr::ungroup()

# ndvi_within: daily deviation from a participant's mean NDVI.
# ndvi_between: participant's mean NDVI across included days.
# perc_filled_false: percentage of directly observed GPS minutes (covariate).
ndvi_stress_model <- nlme::lme(
  fixed = ema_stress_mean ~ ndvi_within + ndvi_between + perc_filled_false,
  random = ~ 1 | ID,
  data = analysis_data,
  method = "REML"
)

model_coefficients <- as.data.frame(summary(ndvi_stress_model)$tTable) |>
  tibble::rownames_to_column("term") |>
  dplyr::rename(
    estimate = Value,
    standard_error = Std.Error,
    degrees_of_freedom = DF,
    t_value = `t-value`,
    p_value = `p-value`
  )

effect_size_results <- Map(
  partial_r_from_t,
  t_value = model_coefficients$t_value,
  df = model_coefficients$degrees_of_freedom
) |>
  dplyr::bind_rows()

confidence_level <- 0.95

model_results <- dplyr::bind_cols(
  model_coefficients,
  effect_size_results
) |>
  dplyr::mutate(
    estimate_ci_lower = estimate -
      stats::qt(1 - (1 - confidence_level) / 2, degrees_of_freedom) * standard_error,
    estimate_ci_upper = estimate +
      stats::qt(1 - (1 - confidence_level) / 2, degrees_of_freedom) * standard_error,
    confidence_level = confidence_level,
    observations = nrow(analysis_data),
    participants = dplyr::n_distinct(analysis_data$ID),
    illustrative_example = TRUE,
    note = "Illustrative example using simulated data; not for substantive inference."
  )

write.csv2(
  model_results,
  here::here("Results/ndvi_stress_multilevel_model.csv"),
  row.names = FALSE
)

# Manuscript-ready version of the model table. The unstandardised
# coefficient and partial-r effect size are each accompanied by a 95% CI.
model_results_table <- model_results |>
  dplyr::mutate(
    predictor = dplyr::recode(
      term,
      `(Intercept)` = "Intercept",
      ndvi_within = "Daily NDVI (within-person)",
      ndvi_between = "Mean NDVI (between-person)",
      perc_filled_false = "Directly observed GPS minutes (%)"
    ),
    b = format_coefficient(estimate),
    b_95_ci = paste0(
      "[", format_coefficient(estimate_ci_lower),
      ", ", format_coefficient(estimate_ci_upper), "]"
    ),
    SE = format_coefficient(standard_error),
    t_df = paste0(
      format_coefficient(t_value),
      " (", degrees_of_freedom, ")"
    ),
    p = format_p_value(p_value),
    partial_r = sprintf("%.2f", partial_r),
    partial_r_95_ci = paste0(
      "[", sprintf("%.2f", partial_r_ci_lower),
      ", ", sprintf("%.2f", partial_r_ci_upper), "]"
    )
  ) |>
  dplyr::select(
    predictor,
    b,
    b_95_ci,
    SE,
    t_df,
    p,
    partial_r,
    partial_r_95_ci
  )

write.csv2(
  model_results_table,
  here::here("Results/ndvi_stress_multilevel_model_table.csv"),
  row.names = FALSE
)


# Illustrative model plot ------------------------------------------------
overall_plot <- ggplot2::ggplot(
  analysis_data,
  ggplot2::aes(x = mean_ndvi_100m_day, y = ema_stress_mean)
) +
  ggplot2::geom_point(size = 1.8, alpha = 0.8) +
  ggplot2::geom_smooth(
    method = "lm",
    formula = y ~ x,
    colour = "#3366CC",
    fill = "#3366CC"
  ) +
  ggplot2::labs(
    title = "Overall association",
    x = "Daily mean NDVI (100 m buffer)",
    y = "Daily EMA stress"
  ) +
  ggplot2::theme_bw(base_size = 12)

participant_plot <- ggplot2::ggplot(
  analysis_data,
  ggplot2::aes(
    x = mean_ndvi_100m_day,
    y = ema_stress_mean,
    colour = ID
  )
) +
  ggplot2::geom_point(size = 1.8, alpha = 0.8) +
  ggplot2::geom_smooth(
    ggplot2::aes(group = ID),
    method = "lm",
    formula = y ~ x,
    se = FALSE
  ) +
  ggplot2::scale_colour_viridis_d(end = 0.9) +
  ggplot2::labs(
    title = "Participant-specific associations",
    x = "Daily mean NDVI (100 m buffer)",
    y = "Daily EMA stress",
    colour = "Participant"
  ) +
  ggplot2::theme_bw(base_size = 12) +
  ggplot2::theme(legend.position = "bottom")

plot_grob <- gridExtra::arrangeGrob(
  overall_plot,
  participant_plot,
  ncol = 2,
  top = grid::textGrob(
    "Illustrative example using simulated data – no substantive inference",
    gp = grid::gpar(fontface = "bold", fontsize = 13)
  )
)

grDevices::png(
  here::here("Results/ndvi_stress_daily_association.png"),
  width = 3600,
  height = 1800,
  res = 300
)
grid::grid.draw(plot_grob)
grDevices::dev.off()

print(summary(ndvi_stress_model))
message("Created illustrative NDVI-stress model results and plot")
