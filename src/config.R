suppressPackageStartupMessages(library(config))

#' Load pipeline configuration from config.yml
#'
#' Respects R_CONFIG_ACTIVE environment variable (defaults to "default").
load_config <- function() {
  config::get(file = here::here("config.yml"))
}

#' Flatten the grouped resamplings list into a character vector
all_resamplings <- function(cfg) {
  unlist(cfg$resamplings, use.names = FALSE)
}
