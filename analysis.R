library(nlme)

read_trial <- function(path) {
  trial <- read.delim(path, colClasses = c("integer", "character", "numeric", "numeric"))
  required <- c("year", "plot", "grain", "straw")
  if (!identical(names(trial), required) || anyNA(trial[c("year", "plot")]) ||
      !all(grepl("^P[0-9]+$", trial$plot)) || anyDuplicated(trial[c("plot", "year")])) {
    stop("Expected one observation per valid strip and year")
  }
  yields <- unlist(trial[c("grain", "straw")], use.names = FALSE)
  if (any(!is.finite(yields[!is.na(yields)])) || any(yields < 0, na.rm = TRUE)) {
    stop("Yield observations must be finite and nonnegative")
  }
  trial <- trial[order(trial$plot, trial$year), ]
  trial$plot <- factor(trial$plot)
  trial$decades <- (trial$year - 1852) / 10
  trial
}

paired_difference <- function(trial, response, treatment, control) {
  left <- trial[trial$plot == treatment, c("year", response)]
  right <- trial[trial$plot == control, c("year", response)]
  paired <- merge(left, right, by = "year", suffixes = c("_treatment", "_control"))
  paired <- paired[complete.cases(paired), ]
  data.frame(year = paired$year, gap = paired[[2]] - paired[[3]])
}

summarize_gap <- function(paired, from, until) {
  data <- paired[paired$year >= from & paired$year <= until, ]
  fit <- gls(gap ~ 1, data = data, correlation = corAR1(value = 0.1, form = ~ year))
  interval <- intervals(fit, which = "coef")$coef[1, ]
  data.frame(year_first = min(data$year), year_last = max(data$year), paired_years = nrow(data),
             observed_mean = mean(data$gap), gls_mean = unname(coef(fit)[1]),
             lower = interval[1], upper = interval[3],
             rho = unname(coef(fit$modelStruct$corStruct, unconstrained = FALSE)))
}

forecast_errors <- function(trial, response, first_test) {
  keep <- !is.na(trial[[response]])
  train <- droplevels(trial[keep & trial$year < first_test, ])
  test <- trial[keep & trial$year >= first_test & trial$plot %in% levels(train$plot), ]
  stopifnot(nrow(train) > 0, nrow(test) > 0, max(train$year) < min(test$year))
  design <- reformulate("plot * decades", response = response)
  ordinary <- lm(design, data = train)
  autoregressive <- gls(design, data = train, correlation = corAR1(value = 0.1, form = ~ year | plot))
  models <- list(ols = ordinary, ar1 = autoregressive)
  do.call(rbind, lapply(names(models), function(method) {
    err <- as.numeric(predict(models[[method]], newdata = test)) - test[[response]]
    data.frame(outcome = response, model = method, train_rows = nrow(train),
               test_rows = nrow(test), first_test = min(test$year), last_test = max(test$year),
               rmse = sqrt(mean(err^2)), mae = mean(abs(err)),
               rho = if (method == "ar1") unname(coef(autoregressive$modelStruct$corStruct,
                                                      unconstrained = FALSE)) else NA_real_)
  }))
}

run_audit <- function(trial, output, first_test = 1915L) {
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  responses <- c("grain", "straw")
  ranges <- list(c(1852L, 1925L), c(1852L, 1888L), c(1889L, 1925L))
  contrasts <- do.call(rbind, lapply(responses, function(outcome) {
    do.call(rbind, lapply(c("P02", "P07"), function(treatment) {
      gap <- paired_difference(trial, outcome, treatment, "P03")
      do.call(rbind, lapply(ranges, function(period) {
        cbind(outcome = outcome, treatment = treatment, control = "P03",
              summarize_gap(gap, period[1], period[2]))
      }))
    }))
  }))
  scores <- do.call(rbind, lapply(responses, function(outcome) forecast_errors(trial, outcome, first_test)))
  coverage <- data.frame(records = nrow(trial), strips = nlevels(trial$plot),
                         min_year = min(trial$year), max_year = max(trial$year),
                         missing_grain = sum(is.na(trial$grain)), missing_straw = sum(is.na(trial$straw)))
  for (name in c("coverage", "contrasts", "scores")) {
    write.csv(get(name), file.path(output, paste0(name, ".csv")), row.names = FALSE)
  }
  invisible(list(coverage = coverage, contrasts = contrasts, scores = scores))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  input <- if (length(args)) args[1] else "data/raw/broadbalk.wheat.tsv"
  output <- if (length(args) > 1) args[2] else "runs/benchmark"
  run_audit(read_trial(input), output)
}
