setwd("~/research/water/awash/analyses/waterstressindex")

library(ncdf4)
library(dplyr)

df <- read.csv("../../data/counties/extraction/USGS-2010.csv")
df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"))

ncin <- nc_open("../../data/cache/counties/VIC_WB.nc")
ncfips <- ncvar_get(ncin, "state_fips") * 1000 + ncvar_get(ncin, "county_fips")
ncflow <- ncvar_get(ncin, "runoff") + ncvar_get(ncin, "baseflow")

totalflow <- matrix(0, 61, nrow(df))
for (ii in 1:nrow(df)) {
    print(ii)
    ncii <- which(ncfips == df$FIPS[ii])
    if (length(ncii) == 0)
        next
    ## mm * mi2 * k km2 / mi2 * (1000 m / km)^2 * m / 1000 mm = m^3
    flow <- ncflow[, ncii] * df$TotalArea.sqmi[ii] * 2.58999 # 1000 m^3
    for (tt in 1:61)
        totalflow[tt, ii] <- sum(flow[(tt-1)*12 + (1:12)], na.rm=T)
}

# 1e6 Gal / day * (0.00378541 m^3 / Gal) * (365.25 day / year)
df$swdemand <- df$TO_SW * 1383
df$demand <- df$TO_To * 1383

df$minflow <- apply(totalflow, 2, min)
df$minflow[df$minflow == 0] <- NA

envpossible <- 1 - df$swdemand / df$minflow
envpossible[envpossible < 0] <- 0

source("~/projects/research-common/R/ggmap.R")

gg.usmap(envpossible, df$FIPS) +
    scale_fill_gradient2(name="Minimum\nEnv. Flow\nRemaining", low="#d7191c", mid="#ffffbf", high="#2c7bb6", midpoint=.5, labels = scales::percent) + coord_map("albers", lat0=39, lat1=45) +
theme(legend.justification=c(1,0), legend.position=c(1,0))
ggsave("vsenv-local.pdf", width=7, height=4)

