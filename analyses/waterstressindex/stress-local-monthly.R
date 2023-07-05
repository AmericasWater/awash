setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)
library(ncdf4)
library(reshape2)

do.commonbias <- T

df <- read.csv("demands.csv")
df <- subset(df, scale == "monthly")
df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"), by=c('fips'='FIPS'))

if (do.commonbias) {
    flowdf.sw <- read.csv("results/stress-monthly-withres.csv")
    flowdf.sw$timestep <- (flowdf.sw$startyear - 1949) * 12 + flowdf.sw$time

    ## Plot the bias correction
    df2 <- df %>% left_join(flowdf.sw)

    df$commonbias <- df2$supersource
}

baseflow <- read.csv("~/Dropbox/America's Water/Public Model Data/runoff.v2/baseflow_monthly_county_mm_Maurer.csv")
runoff <- read.csv("~/Dropbox/America's Water/Public Model Data/runoff.v2/runoff_monthly_county_mm_Maurer.csv")

allflow <- baseflow[, -1] + runoff[, -1]
flowdf <- melt(cbind(date=baseflow$X, timestep=1:nrow(allflow), allflow), c('date', 'timestep'))
names(flowdf) <- c('date', 'timestep', 'xfips', 'flowmm')
flowdf$fips <- as.numeric(substring(flowdf$xfips, 2))

## ncin <- nc_open("../../data/cache/counties/VIC_WB.nc")
## ncfips <- ncvar_get(ncin, "state_fips") * 1000 + ncvar_get(ncin, "county_fips")
## ncflow <- ncvar_get(ncin, "runoff") + ncvar_get(ncin, "baseflow")

## flowdf <- melt(ncflow)
## names(flowdf) <- c('timestep', 'cc', 'flowmm')
## flowdf$fips <- ncfips[flowdf$cc]

## Plot map of flows
source("~/projects/research-common/R/ggmap.R")

flowdf2 <- flowdf %>% group_by(fips) %>% summarize(flowmm=mean(flowmm, na.rm=T))
gg.usmap(flowdf2$flowmm, as.numeric(flowdf2$fips))

df$fips <- as.numeric(df$fips)
df2 <- df %>% left_join(flowdf)
## mm * mi2 * k km2 / mi2 * (1000 m / km)^2 * m / 1000 mm = m^3
df2$flow <- df2$flowmm * df2$TotalArea_sqmi * 2.58999 # 1000 m^3

## Calculate stress metrics

df2$supersource.sw <- (df2$swdemand - (1 - .37) * df2$flow)
df2$supersource.sw[df2$supersource.sw < 0] <- 0

valid <- !is.na(df2$supersource.sw) & !is.na(df2$swdemand)
mean(df2$supersource.sw[valid] > 0)
sum(df2$supersource.sw[valid]) / sum(df2$swdemand[valid])

df2$minefp.sw <- 100 * (1 - df2$swdemand / df2$flow)
df2$minefp.sw[df2$minefp.sw < 0] <- 0

df2$supersource.all <- (df2$alldemand - (1 - .37) * df2$flow)
df2$supersource.all[df2$supersource.all < 0] <- 0

df2$minefp.all <- 100 * (1 - df2$alldemand / df2$flow)
df2$minefp.all[df2$minefp.all < 0] <- 0

if (do.commonbias) {
    df2$supersource.excess <- pmax(0, df2$supersource.all - df2$commonbias)
    df2$failurefrac.excess <- df2$supersource.excess / df2$alldemand
    df2$natflowav.excess <- pmax(0, 1 - df2$alldemand / (df2$flow + df2$commonbias))
} else {
    df2$supersource.excess <- pmax(0, df2$supersource.all - df2$supersource.sw)
    df2$failurefrac.excess <- df2$supersource.excess / df2$alldemand
    df2$natflowav.excess <- pmax(0, 1 - df2$alldemand / (df2$flow + df2$supersource.sw))
}

write.csv(df2[, c('timestep', 'fips', 'supersource.sw', 'supersource.excess', 'failurefrac.excess', 'natflowav.excess')], "fipstime-monthly-excess-local.csv", row.names=F)

## Make maps

df3 <- df2 %>% group_by(fips) %>% summarize(reliability.model=sum(supersource.sw == 0) / length(supersource.sw), reliability.excess=sum(failurefrac.excess == 0, na.rm=T) / sum(!is.na(failurefrac.excess)), failurefrac.excess.median=median(failurefrac.excess, na.rm=T), failurefrac.excess.worst=max(failurefrac.excess, na.rm=T), natflowav.excess=median(natflowav.excess, na.rm=T), natflowav.excess.worst=min(natflowav.excess, na.rm=T))

source("vsenv-lib.R")

plot.relity.both(df3$fips, df3$reliability.model, df3$reliability.excess, "monthly-excess-local")
plot.failavail(df3$fips, df3$failurefrac.excess.median, df3$failurefrac.excess.worst, df3$natflowav.excess, df3$natflowav.excess.worst, "monthly-excess-local")

## Record for county descriptions

df2$yearoct <- floor(df2$timestep / 12) + 1949
df4 <- df2 %>% group_by(yearoct, fips) %>% summarize(failurefrac.excess.worst=max(failurefrac.excess), natflowav.excess.worst=min(natflowav.excess))
df5 <- df4 %>% group_by(fips) %>% summarize(failurefrac.excess.worstbest=min(failurefrac.excess.worst, na.rm=T), natflowav.excess.worstbest=max(natflowav.excess.worst, na.rm=T), failurefrac.excess.worstmedian=median(failurefrac.excess.worst, na.rm=T), natflowav.excess.worstmedian=median(natflowav.excess.worst, na.rm=T))

df6 <- df3 %>% left_join(df5)

write.csv(df6, "byfips-monthly-excess-local.csv", row.names=F)
