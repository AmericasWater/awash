setwd("~/research/water/awash6/analyses/uncinvest")

load("~/research/water/awash/data/counties/waternet/waternet.RData")
source("../../rlib/load_display.R")
library(maps)

suffix <- "-50.0"

captures <- read.csv(paste0("captures-monthly", suffix, ".csv"))

pdf(paste0("captures-monthly", suffix, ".pdf"), width=8, height=5)
par(mar=rep(0, 4))
map("state")
drawNetwork(network, col="#00008040")
points(captures$lon, captures$lat, cex=sqrt(captures$maxcap / 1e10))
points(captures$lon, captures$lat, cex=sqrt(1000 * captures$capmaxs / 1e10), col='red')
points(captures$lon, captures$lat, cex=sqrt(1000 * captures$capmaxs / 1e10), pch=16, col='red')
points(captures$lon[captures$capmaxs > 0], captures$lat[captures$capmaxs > 0], cex=1 + sqrt(captures$maxcap[captures$capmaxs > 0] / 1e10), col='#008000')
points(captures$lon[captures$capmaxs > 0], captures$lat[captures$capmaxs > 0], cex=1.2 + sqrt(captures$maxcap[captures$capmaxs > 0] / 1e10), col='#008000')
dev.off()

gwextracts <- read.csv(paste0("groundwater-monthly", suffix, ".csv"))
source("~/projects/research-common/R/ggmap.R")

usgsdata <- read.csv("../../data/counties/extraction/USGS-2010.csv")

gg.usmap(usgsdata$TO_GW * 1383, usgsdata$FIPS) + scale_fill_gradient(trans="log", name="GW Extracts", breaks=c(10, 100, 1000, 1e4, 1e5, 1e6, 1e7), limits=range(gwextracts$maxsums[gwextracts$maxsums > 0]))

gg.usmap(gwextracts$maxsums, gwextracts$fips) + scale_fill_gradient(trans="log", name="GW Extracts", breaks=c(10, 100, 1000, 1e4, 1e5, 1e6, 1e7))

plotsmd1 <- log(gwextracts$summaxdiff)
plotsmd1[is.nan(plotsmd1) | !is.finite(plotsmd1)] <- 0
plotsmd2 <- log(-gwextracts$summindiff)
plotsmd2[is.nan(plotsmd2) | !is.finite(plotsmd2)] <- 0

gg.usmap(plotsmd1 - plotsmd2, gwextracts$fips) + scale_fill_distiller(palette = "Spectral", name="Log GW Change\n without res.")


optimum <- read.csv("optimum-1449.csv")

library(ggplot2)

ggplot(subset(optimum, scenario %in% 2:5), aes(month)) +
    facet_grid(scenario ~ .) + geom_hline(yintercept=0) +
    geom_line(aes(y=precip / 10), col='blue') +
    geom_line(aes(y=inflows / 100e3), col='green') + geom_line(aes(y=demands / 1e3), col='red') +
    geom_bar(aes(y=captures / 1e3), stat="identity") +
    theme_bw() + xlab("Month") + ylab(NULL) + scale_x_continuous(expand=c(0, 0))

