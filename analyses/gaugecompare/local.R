setwd("~/research/water/awash/analyses/gaugecompare")

library(dplyr)
library(ncdf4)
library(reshape2)

source("../../../network4/discharges.R", chdir=T)

load("../../data/counties/waternet/countydraws.RData")

startmonth <- 673

alldf <- data.frame()

for (do.scale in c('monthly', 'annual')) {
    df <- read.csv("../waterstressindex/demands.csv")
    if (do.scale == 'monthly')
        df <- subset(df, scale == do.scale & timestep >= startmonth)
    else
        df <- subset(df, scale == do.scale & timestep >= 57)
    df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"), by=c('fips'='FIPS'))

    baseflow <- read.csv("~/Dropbox/America's Water/Public Model Data/runoff.v2/baseflow_monthly_county_mm_Maurer.csv")
    runoff <- read.csv("~/Dropbox/America's Water/Public Model Data/runoff.v2/runoff_monthly_county_mm_Maurer.csv")

    allflow <- baseflow[, -1] + runoff[, -1]
    flowdf <- melt(cbind(date=baseflow$X, timestep=1:nrow(allflow), allflow), c('date', 'timestep'))
    names(flowdf) <- c('date', 'timestep', 'xfips', 'flowmm')
    flowdf$fips <- as.numeric(substring(flowdf$xfips, 2))

    df$fips <- as.numeric(df$fips)
    df2 <- df %>% left_join(flowdf)
    ## mm * mi2 * k km2 / mi2 * (1000 m / km)^2 * m / 1000 mm = m^3
    df2$flow <- df2$flowmm * df2$TotalArea_sqmi * 2.58999 # 1000 m^3

    df2$remaining <- df2$flow - df2$swdemand

    ## Now, I have a bunch of gauges that fall within each county
    ## Take the closest!
    df2$observed <- NA

    numdone <- 0
    for (fips in unique(df2$fips)) {
        numdone <- numdone + 1
        print(numdone / 3109)
        dfrows <- which(df2$fips == fips)

        subnet <- network[draws$source[draws$fips == fips & draws$justif == 'contains'],]
        if (nrow(subnet) == 0)
            next
        for (ii in 1:nrow(subnet)) {
            if (subnet$collection[ii] %in% c("rivdis", "usgs")) {
                values <- get.flow.data(subnet$collection[ii], subnet$colid[ii])
                if (class(values) == "logical")
                    next
                starttime <- (1950 - 1960) * 12 - 3 + startmonth - 1
                maxtime <- max(values$time)

                newobserved <- rep(NA, length(dfrows))
                if (do.scale == 'monthly') {
                    if (starttime >= maxtime)
                        next
                    for (time in 1:60) {
                        newobserved[time] <- values$flow[values$time == starttime]
                        starttime <- starttime + 1
                        if (starttime > maxtime)
                            break
                    }
                } else {
                    if (starttime >= maxtime - 11)
                        next
                    for (year in 1:length(dfrows)) {
                        newobserved[year] <- mean(values$flow[values$time >= starttime & values$time < starttime + 12])
                        starttime <- starttime + 12
                        if (starttime > maxtime)
                            break
                    }
                }
            }
        }

        newobserved <- newobserved * 60 * 60 * 24 * 365 / 1000 # 1000 m^3
        if (do.scale == 'monthly')
            newobserved <- newobserved / 12

        if (all(is.na(df2$observed[dfrows]))) {
            df2$observed[dfrows] <- newobserved
        } else {
            oldratio <- median(df2$remaining[dfrows] / df2$observed[dfrows], na.rm=T)
            newratio <- median(df2$remaining[dfrows] / newobserved, na.rm=T)
            if (abs(log(oldratio)) > abs(log(newratio)))
                df2$observed[dfrows] <- newobserved
        }
    }

    alldf <- rbind(alldf, df2)
}

write.csv(alldf, "local-compare.csv", row.names=F)
