setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)
library(ncdf4)

df <- read.csv("../../data/counties/extraction/USGS-2010.csv")
df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"))

ncin <- nc_open("../../data/cache/counties/VIC_WB.nc")
ncfips <- ncvar_get(ncin, "state_fips") * 1000 + ncvar_get(ncin, "county_fips")
ncflow <- ncvar_get(ncin, "runoff") + ncvar_get(ncin, "baseflow")

totalflow <- matrix(0, 61, nrow(df))
worstflow <- matrix(0, 61, nrow(df))
for (ii in 1:nrow(df)) {
    print(ii)
    ncii <- which(ncfips == df$FIPS[ii])
    if (length(ncii) == 0)
        next
    ## mm * mi2 * k km2 / mi2 * (1000 m / km)^2 * m / 1000 mm = m^3
    flow <- ncflow[, ncii] * df$TotalArea_sqmi[ii] * 2.58999 # 1000 m^3
    for (tt in 1:61) {
        totalflow[tt, ii] <- sum(flow[(tt-1)*12 + (1:12)], na.rm=T)
        worstflow[tt, ii] <- min(flow[(tt-1)*12 + (1:12)], na.rm=T)
    }
}

# 1e6 Gal / day * (0.00378541 m^3 / Gal) * (365.25 day / year)
df$swdemand <- df$TO_SW * 1383
df$demand <- df$TO_To * 1383

## Save stress-annual-worst-*-local.csv files
tosave.all <- data.frame(time=c(), fips=c(), supersource=c(), minefp=c())
tosave.sw <- data.frame(time=c(), fips=c(), supersource=c(), minefp=c())
for (ii in 1:nrow(df)) {
    demand <- df$demand[ii] / 12
    supersource <- (demand - (1 - .37) * worstflow[, ii])
    supersource[supersource < 0] <- 0

    minefp <- 100 * (1 - demand / worstflow[, ii])
    minefp[minefp < 0] <- 0

    tosave.all <- rbind(tosave.all, data.frame(time=1948 + (1:61), fips=df$FIPS[ii], supersource=12*supersource, minefp))

    demand <- df$swdemand[ii] / 12
    supersource <- (demand - (1 - .37) * worstflow[, ii])
    supersource[supersource < 0] <- 0

    minefp <- 100 * (1 - demand / worstflow[, ii])
    minefp[minefp < 0] <- 0

    tosave.sw <- rbind(tosave.sw, data.frame(time=1948 + (1:61), fips=df$FIPS[ii], supersource=12*supersource, minefp))
}

write.csv(tosave.all, "results/stress-annual-worst-alldemand-local.csv", row.names=F)
write.csv(tosave.sw, "results/stress-annual-worst-local.csv", row.names=F)

## Save stress-annual-*-local.csv files
tosave.all <- data.frame(time=c(), fips=c(), supersource=c(), minefp=c())
tosave.sw <- data.frame(time=c(), fips=c(), supersource=c(), minefp=c())
for (ii in 1:nrow(df)) {
    demand <- df$demand[ii]
    supersource <- (demand - (1 - .37) * totalflow[, ii])
    supersource[supersource < 0] <- 0

    minefp <- 100 * (1 - demand / totalflow[, ii])
    minefp[minefp < 0] <- 0

    tosave.all <- rbind(tosave.all, data.frame(time=1948 + (1:61), fips=df$FIPS[ii], supersource=supersource, minefp))

    demand <- df$swdemand[ii]
    supersource <- (demand - (1 - .37) * totalflow[, ii])
    supersource[supersource < 0] <- 0

    minefp <- 100 * (1 - demand / totalflow[, ii])
    minefp[minefp < 0] <- 0

    tosave.sw <- rbind(tosave.sw, data.frame(time=1948 + (1:61), fips=df$FIPS[ii], supersource=supersource, minefp))
}

write.csv(tosave.all, "results/stress-annual-alldemand-local.csv", row.names=F)
write.csv(tosave.sw, "results/stress-annual-local.csv", row.names=F)

## Make maps

get.terms <- function(df, myflow, demand) {
    df$failurefrac <- NA
    df$failurefrac.worst <- NA
    df$natflowav <- NA
    df$natflowav.worst <- NA
    for (ii in 1:nrow(df)) {
        failurefrac <- (demand[ii] - (1 - .37) * myflow[, ii]) / demand[ii]
        failurefrac[failurefrac > 1] <- 1
        failurefrac[failurefrac < 0] <- 0
        df$failurefrac[ii] <- median(failurefrac)
        df$failurefrac.worst[ii] <- max(failurefrac)

        natflowav <- 1 - demand[ii] / myflow[, ii]
        natflowav[natflowav < 0] <- 0
        df$natflowav[ii] <- median(natflowav)
        df$natflowav.worst[ii] <- min(natflowav)
    }

    df
}

source("vsenv-lib.R")

df0 <- get.terms(df, totalflow, df$swdemand)
plot.failavail(df0$FIPS, df0$failurefrac, df0$failurefrac.worst, df0$natflowav, df0$natflowav.worst, "annual-local")

df1 <- get.terms(df, totalflow, df$demand)
plot.failavail(df1$FIPS, df1$failurefrac, df1$failurefrac.worst, df1$natflowav, df1$natflowav.worst, "annual-alldemand-local")

sum(df1$failurefrac > 0, na.rm=T) / nrow(df2)
sum(df1$failurefrac * df1$demand, na.rm=T) / sum(df1$demand, na.rm=T)

df2 <- df1
df2$failurefrac <- (df$demand * df1$failurefrac - df$swdemand * df0$failurefrac) / df$demand
df2$failurefrac.worst <- (df$demand * df1$failurefrac.worst - df$swdemand * df0$failurefrac.worst) / df$demand
df2$natflowav <- df1$natflowav + (1 - df0$natflowav)
df2$natflowav.worst <- df1$natflowav.worst + (1 - df0$natflowav.worst)
plot.failavail(df2$FIPS, df2$failurefrac, df2$failurefrac.worst, df2$natflowav, df2$natflowav.worst, "annual-excess-local")

## Monthly worst maps
df0 <- get.terms(df, worstflow, df$swdemand / 12)
plot.failavail(df0$FIPS, df0$failurefrac, df0$failurefrac.worst, df0$natflowav, df0$natflowav.worst, "monthly-local")

df1 <- get.terms(df, worstflow, df$demand / 12)
plot.failavail(df1$FIPS, df1$failurefrac, df1$failurefrac.worst, df1$natflowav, df1$natflowav.worst, "monthly-alldemand-local")

df2 <- df1
df2$failurefrac <- (df$demand * df1$failurefrac - df$swdemand * df0$failurefrac) / df$demand
df2$failurefrac.worst <- (df$demand * df1$failurefrac.worst - df$swdemand * df0$failurefrac.worst) / df$demand
df2$natflowav <- df1$natflowav + (1 - df0$natflowav)
df2$natflowav.worst <- df1$natflowav.worst + (1 - df0$natflowav.worst)
plot.failavail(df2$FIPS, df2$failurefrac, df2$failurefrac.worst, df2$natflowav, df2$natflowav.worst, "monthly-excess-local")
