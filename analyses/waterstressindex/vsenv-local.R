setwd("~/research/water/awash/analyses/waterstressindex")

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

df$failurefrac <- NA
df$failurefrac.worst <- NA
df$natflowav <- NA
df$natflowav.worst <- NA
for (ii in 1:nrow(df)) {
    failurefrac <- (df$swdemand[ii] - (1 - .37) * totalflow[, ii]) / df$swdemand[ii]
    failurefrac[failurefrac > 1] <- 1
    failurefrac[failurefrac < 0] <- 0
    df$failurefrac[ii] <- median(failurefrac)
    df$failurefrac.worst[ii] <- max(failurefrac)

    natflowav <- 1 - df$swdemand[ii] / totalflow[, ii]
    natflowav[natflowav < 0] <- 0
    df$natflowav[ii] <- median(natflowav)
    df$natflowav.worst[ii] <- min(natflowav)
}

include("vsenv-lib.R")

plot.failavail(df$fips, df$failurefrac, df$failurefrac.worst, df$natflowav, df$natflowav.worst, "local")
