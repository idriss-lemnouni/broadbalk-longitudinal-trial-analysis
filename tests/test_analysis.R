source("analysis.R")
trial <- read_trial("data/raw/broadbalk.wheat.tsv")
stopifnot(nrow(trial) == 1258L, range(trial$year) == c(1852L, 1925L))
pair <- paired_difference(trial, "grain", "P02", "P03")
stopifnot(pair$year[1] == 1852L, isTRUE(all.equal(pair$gap[1], 1.92 - 0.97)))
stopifnot(all(diff(pair$year) > 0), nrow(pair) == nrow(merge(
  subset(trial, plot == "P02" & !is.na(grain), select = year),
  subset(trial, plot == "P03" & !is.na(grain), select = year)
)))
fit <- forecast_errors(trial, "grain", 1915L)
stopifnot(all(fit$first_test == 1915L), all(fit$last_test == 1925L),
          length(unique(fit$test_rows)) == 1L, all(is.finite(fit$rmse)))
duplicated_file <- tempfile(fileext = ".tsv")
write.table(trial[c(1, 1), c("year", "plot", "grain", "straw")], duplicated_file,
            sep = "\t", row.names = FALSE)
stopifnot(inherits(try(read_trial(duplicated_file), silent = TRUE), "try-error"))
cat("4 Broadbalk data and temporal checks passed\n")
