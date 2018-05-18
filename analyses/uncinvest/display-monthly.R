setwd("~/research/water/awash6/analyses/uncinvest")

captures <- read.csv("captures-monthly.csv")

library(maps)
map("state")
points(captures$lon, captures$lat, cex=sqrt(captures$maxcap / 1e10))
points(captures$lon, captures$lat, cex=sqrt(1000 * captures$capmaxs / 1e10), col='red')
points(captures$lon, captures$lat, cex=sqrt(1000 * captures$capmaxs / 1e10), pch=16, col='red')
points(captures$lon[captures$capmaxs > 0], captures$lat[captures$capmaxs > 0], cex=1, col='blue')

optimum <- read.csv("optimum-1449.csv")

library(ggplot2)

ggplot(subset(optimum, scenario %in% 2:5), aes(month)) +
    facet_grid(scenario ~ .) + geom_hline(yintercept=0) +
    geom_line(aes(y=precip / 10), col='blue') +
    geom_line(aes(y=inflows / 100e3), col='green') + geom_line(aes(y=demands / 1e3), col='red') +
    geom_bar(aes(y=captures / 1e3), stat="identity") +
    theme_bw() + xlab("Month") + ylab(NULL) + scale_x_continuous(expand=c(0, 0))

gwextracts <- read.csv("groundwater-monthly.csv")

source("~/projects/research-common/R/ggmap.R")

gg.usmap(log(gwextracts$maxsums), gwextracts$fips)

plotsmd1 <- log(gwextracts$summaxdiff)
plotsmd1[is.nan(plotsmd1) | !is.finite(plotsmd1)] <- 0
plotsmd2 <- log(-gwextracts$summindiff)
plotsmd2[is.nan(plotsmd2) | !is.finite(plotsmd2)] <- 0

gg.usmap(plotsmd1 - plotsmd2, gwextracts$fips) + scale_fill_distiller(palette = "Spectral")
