setwd("~/research/awash-uncertain/analyses/uncinvest")

library(ncdf4)
library(dplyr)
library(scales)

df <- read.csv("../../data/counties/extraction/USGS-2010.csv")
df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"))

ncin <- nc_open("../../data/cache/counties/VIC_WB.nc")
ncfips <- ncvar_get(ncin, "state_fips") * 1000 + ncvar_get(ncin, "county_fips")
ncflow <- ncvar_get(ncin, "runoff") + ncvar_get(ncin, "baseflow")

scenarioyears <- c(8, 13, 17, 20, 34, 51)

for (ii in 1:nrow(df)) {
    print(ii)
    ncii <- which(ncfips == df$FIPS[ii])
    ## mm * mi2 * k km2 / mi2 * (1000 m / km)^2 * m / 1000 mm = m^3
    flow <- ncflow[, ncii] * df$TotalArea.sqmi[ii] * 2.58999 # 1000 m^3
    for (ss in 1:length(scenarioyears)) {
        janjj <- (scenarioyears[ss] - 1) * 12 + 4
        df[ii, paste0("meanflow", ss)] <- mean(flow[janjj:(janjj+11)])
        df[ii, paste0("minflow", ss)] <- min(flow[janjj:(janjj+11)])
    }
}

# 1e6 Gal / day * (0.00378541 m^3 / Gal) * (365.25 day / year) * (year / 12 month)
df$swdemand <- df$TO_SW * 1383 / 12
df$demand <- df$TO_To * 1383 / 12

for (ss in 1:length(scenarioyears)) {
    df[, paste0("swminratio", ss)] <- df$swdemand / df[, paste0("minflow", ss)]
    df[, paste0("swmeanratio", ss)] <- df$swdemand / df[, paste0("meanflow", ss)]
    df[, paste0("minratio", ss)] <- df$demand / df[, paste0("minflow", ss)]
}
df$swminratio <- pmax(df$swminratio1, df$swminratio2, df$swminratio3,
                     df$swminratio4, df$swminratio5, df$swminratio6)
df$swmeanratio <- pmax(df$swmeanratio1, df$swmeanratio2, df$swmeanratio3,
                     df$swmeanratio4, df$swmeanratio5, df$swmeanratio6)
df$minratio <- pmax(df$minratio1, df$minratio2, df$minratio3,
                     df$minratio4, df$minratio5, df$minratio6)

source("~/projects/research-common/R/ggmap.R")

df$swmeanratio.lim <- df$swmeanratio
df$swmeanratio.lim[df$swmeanratio < .5] <- NA
df$swmeanratio.lim[df$swmeanratio > 100] <- 100

gg.usmap(df$swmeanratio.lim, df$FIPS) +
    scale_fill_gradient2(name="Demand\n / Supply", low="#3288bd", mid="#ffffbf", high="#9e0142", midpoint=0, trans="log", limits=c(0.5, 100), na.value="#3288bd", breaks=c(.5, 1, 2, 5, 10, 20, 50, 100))
ggsave("swmeanratio.pdf", width=8, height=5)

df$swminratio.lim <- df$swminratio
df$swminratio.lim[df$swminratio < .5] <- NA
df$swminratio.lim[df$swminratio > 100] <- 100

gg.usmap(df$swminratio.lim, df$FIPS) +
    scale_fill_gradient2(low="#3288bd", mid="#ffffbf", high="#9e0142", midpoint=0, trans="log", limits=c(0.5, 100), na.value="#3288bd", breaks=c(.5, 1, 2, 5, 10, 20, 50, 100))
ggsave("swminnratio.pdf", width=8, height=5)

df$minratio.lim <- df$minratio
df$minratio.lim[df$minratio < .5] <- NA
df$minratio.lim[df$minratio > 100] <- 100

gg.usmap(df$minratio.lim, df$FIPS) +
    scale_fill_gradient2(low="#3288bd", mid="#ffffbf", high="#9e0142", midpoint=0, trans="log", limits=c(0.5, 100), na.value="#3288bd", breaks=c(.5, 1, 2, 5, 10, 20, 50, 100))
ggsave("minnratio.pdf", width=8, height=5)
