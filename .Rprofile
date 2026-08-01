source("renv/activate.R")

# Open the tutorial's first script once for each local clone.
if (interactive() && identical(Sys.getenv("RSTUDIO"), "1")) {
  marker <- file.path(".Rproj.user", "setup-script-opened")

  if (!file.exists(marker)) {
    dir.create(dirname(marker), recursive = TRUE, showWarnings = FALSE)
    utils::file.edit("scripts/01_Setup.R")
    file.create(marker)
  }
}
