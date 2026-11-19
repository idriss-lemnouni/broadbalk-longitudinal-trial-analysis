source("analysis.R")

args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args) == 2L && args[1] == "--output") args[2] else "figures/results"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
trial <- read_trial("data/raw/broadbalk.wheat.tsv")
contrasts <- read.csv("runs/benchmark/contrasts.csv")
scores <- read.csv("runs/benchmark/scores.csv")
navy <- "#182c49"
teal <- "#00786e"
blue <- "#2f5698"
ochre <- "#a95523"
grid_color <- "#dce5ef"

start_figure <- function(name, height = 690) {
  png(file.path(output, name), width = 1320, height = height, res = 145, bg = "#f7f9fc")
  par(mar = c(5.9, 5.1, 4, 1.5), col = navy, col.axis = navy, col.lab = navy,
      col.main = navy, fg = grid_color, bty = "n", cex.main = 1.25)
}

start_figure("grain-trajectories.png")
selected <- c("P02", "P07", "P03")
colors <- c(teal, blue, ochre)
part <- trial[trial$plot %in% selected, ]
lim <- range(part$grain, na.rm = TRUE)
plot(NA, xlim = range(part$year), ylim = lim, xlab = "Campagne", ylab = "Rendement en grain (tonnes)",
     main = "Trajectoires du bl\u00e9 sur trois bandes historiques")
rect(1915, par("usr")[3], 1927, par("usr")[4], col = "#e7edf6", border = NA)
abline(h = axTicks(2), col = grid_color)
for (i in seq_along(selected)) {
  row <- part[part$plot == selected[i], ]
  lines(row$year, row$grain, col = adjustcolor(colors[i], .25))
  lines(row$year, stats::filter(row$grain, rep(1 / 7, 7)), col = colors[i], lwd = 2.7)
}
legend("topright", legend = c("P02 \u00b7 fumier", "P07 \u00b7 fertilisation min\u00e9rale", "P03 \u00b7 sans apport"),
       col = colors, lty = 1, lwd = 2.7, bty = "n", text.col = navy, cex = .85)
mtext("Traits \u00e9pais : moyennes mobiles sur sept campagnes. Zone gris\u00e9e : 1915\u20131925.",
      side = 1, line = 4.55, cex = .75, col = navy)
invisible(dev.off())

start_figure("paired-contrasts.png", 790)
par(mar = c(5.9, 10.5, 4, 1.8))
pairs <- contrasts[contrasts$year_last - contrasts$year_first < 50, ]
labels <- paste(ifelse(pairs$outcome == "grain", "Grain", "Paille"),
                pairs$treatment, paste0(pairs$year_first, "\u2013", pairs$year_last), sep = " \u00b7 ")
rows <- rev(seq_len(nrow(pairs)))
cols <- ifelse(pairs$treatment == "P02", teal, blue)
plot(NA, xlim = c(0, max(pairs$upper) + .3), ylim = c(0.5, max(rows) + .6),
     yaxt = "n", xlab = "Diff\u00e9rence par rapport \u00e0 P03 (tonnes)",
     ylab = "", main = "\u00c9carts avec la bande sans fertilisation")
axis(2, at = rows, labels = labels, las = 1, tick = FALSE, cex.axis = .8)
abline(v = axTicks(1), col = grid_color)
arrows(pairs$lower, rows, pairs$upper, rows, angle = 90, code = 3,
       length = .05, col = cols, lwd = 1.8)
points(pairs$gls_mean, rows, col = cols, pch = 19, cex = 1.2)
mtext("Moyenne GLS avec AR(1) et intervalle \u00e0 95 % sur les ann\u00e9es appari\u00e9es.",
      side = 1, line = 4.55, cex = .75, col = navy)
invisible(dev.off())

start_figure("held-out-errors.png")
values <- t(matrix(scores$mae, nrow = 2, byrow = TRUE))
positions <- barplot(values, beside = TRUE, names.arg = c("Grain", "Paille"),
                     col = c(teal, blue), border = NA, ylim = c(0, max(values) * 1.31),
                     ylab = "Erreur absolue moyenne (tonnes)",
                     main = "Erreurs de pr\u00e9vision sur la p\u00e9riode 1915\u20131925")
text(positions, values, labels = format(round(values, 4), nsmall = 4), pos = 3, col = navy)
legend("topleft", legend = c("OLS", "GLS AR(1)"), fill = c(teal, blue),
       bty = "n", border = NA, text.col = navy, horiz = TRUE, cex = .85)
invisible(dev.off())
