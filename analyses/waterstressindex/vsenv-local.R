setwd("~/research/awash/analyses/waterstressindex")

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

df$envpossible <- NA
df$envpossible.worst <- NA
df$failurefrac <- NA
df$failurefrac.worst <- NA
for (ii in 1:nrow(df)) {
    envpossible <- 1 - df$swdemand[ii] / totalflow[, ii]
    envpossible[envpossible < 0] <- 0
    df$envpossible[ii] <- mean(envpossible)
    df$envpossible.worst[ii] <- min(envpossible)

    failurefrac <- (df$swdemand[ii] - (1 - .37) * totalflow[, ii]) / totalflow[, ii]
    failurefrac[failurefrac > 1] <- 1
    failurefrac[failurefrac < 0] <- 0
    df$failurefrac[ii] <- mean(failurefrac)
    df$failurefrac.worst[ii] <- max(failurefrac)
}

source("~/projects/research-common/R/ggmap.R")

gg.usmap(df$envpossible, df$FIPS) +
    scale_fill_gradient2(name="Maximum\nSupportable\nEnv. Flow", low="#d7191c", mid="#ffffbf", high="#2c7bb6", midpoint=.5, labels = scales::percent) + coord_map("albers", lat0=39, lat1=45) +
theme(legend.justification=c(1,0), legend.position=c(1,0))
ggsave("vsenv-local-mean.pdf", width=7, height=4)

gg.usmap(df$envpossible.worst, df$FIPS) +
    scale_fill_gradient2(name="Maximum\nSupportable\nEnv. Flow", low="#d7191c", mid="#ffffbf", high="#2c7bb6", midpoint=.5, labels = scales::percent) + coord_map("albers", lat0=39, lat1=45) +
theme(legend.justification=c(1,0), legend.position=c(1,0))
ggsave("vsenv-local-min.pdf", width=7, height=4)

gg.usmap(df$failurefrac, df$FIPS, df$failurefrac.worst) +
    geom_polygon(aes(size=borders)) +
    scale_fill_gradientn(name="Failure\nFraction", colours=c("#e0f3f8", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
coord_map("albers", lat0=39, lat1=45) +
    scale_colour_gradientn(name="Failure\nFraction", colours=c("#e0f3f8", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
coord_map("albers", lat0=39, lat1=45) +
    scale_size(range=c(0, .5)) + guides(size=F) +
    theme(legend.justification=c(1,0), legend.position=c(1,0))
ggsave("failfrac-local.pdf", width=7, height=4)

## CHANGES:
## 1. Add white state outlines.
## 2. Define env flow metric as "additional flow available", where 0 is in a de-emphasizing colour.
## Then can put next to each other.
