setwd("~/research/water/awash/analyses/waterstressindex")
library(dplyr)
library(ggplot2)

suffix <- "alldemand-nores"

df <- read.csv(paste0("stress-monthly-", suffix, ".csv"))

ggplot(df, aes(x=startyear + (time - .5) / 12, group=minefp, colour=as.factor(minefp), fill=as.factor(minefp))) +
    geom_bar() + scale_x_continuous(expand=c(0, 0)) +
    scale_y_continuous(expand=c(0, 0)) + coord_cartesian(ylim=c(1000, 3109)) +
    scale_fill_discrete(name=NULL) + scale_colour_discrete(name=NULL) +
    xlab(NULL) + ylab("Counties with available flow")
ggsave(paste0("time-natflowa-monthly-", suffix, ".pdf"), width=7, height=4)

## Comparison timeseries

library(ncdf4)

do.local.excess <- T

df <- read.csv("../../data/counties/extraction/USGS-2010.csv")
df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"))
df$demand <- df$TO_To * 1383
df$swdemand <- df$TO_SW * 1383

ncin <- nc_open("../../data/cache/counties/VIC_WB.nc")
ncfips <- ncvar_get(ncin, "state_fips") * 1000 + ncvar_get(ncin, "county_fips")
ncflow <- ncvar_get(ncin, "runoff") + ncvar_get(ncin, "baseflow")

localdf.all <- data.frame(startyear=c(), fips=c(), time=c(), supersource=c(), minefp=c())
localdf.sw <- data.frame(startyear=c(), fips=c(), time=c(), supersource=c(), minefp=c())
for (ii in 1:nrow(df)) {
    print(ii)
    ncii <- which(ncfips == df$FIPS[ii])
    if (length(ncii) == 0)
        next
    ## mm * mi2 * k km2 / mi2 * (1000 m / km)^2 * m / 1000 mm = m^3
    flow <- ncflow[, ncii] * df$TotalArea.sqmi[ii] * 2.58999 # 1000 m^3

    demand <- df$demand[ii] / 12
    supersource <- (demand - (1 - .37) * flow)
    supersource[supersource < 0] <- 0

    minefp <- 100 * (1 - demand / flow)
    minefp[minefp < 0] <- 0

    localdf.all <- rbind(localdf.all, data.frame(startyear=1949, fips=df$FIPS[ii],
                                                 time=9 + (1:length(flow)), supersource, minefp))

    demand <- df$swdemand[ii] / 12
    supersource <- (demand - (1 - .37) * flow)
    supersource[supersource < 0] <- 0

    minefp <- 100 * (1 - demand / flow)
    minefp[minefp < 0] <- 0

    localdf.sw <- rbind(localdf.sw, data.frame(startyear=1949, fips=df$FIPS[ii],
                                               time=9 + (1:length(flow)), supersource, minefp))
}

get.df <- function(infix, localdf) {
    df <- cbind(data.frame(assump="Default"), read.csv(paste0("results/stress-monthly-", infix, "nores.csv")))
    df <- rbind(df, cbind(data.frame(assump="Storage"), read.csv(paste0("results/stress-monthly-", infix, "withres.csv"))))
    df <- rbind(df, cbind(data.frame(assump="No canals"), read.csv(paste0("results/stress-monthly-", infix, "nores-nocanal.csv"))))
    df$time <- df$time + 9 # Actually starts in October

    df <- rbind(df, cbind(data.frame(assump="Local flow"), localdf))

    df <- subset(df, startyear + (time - 1) / 12 < 2006 & startyear + (time - 1) / 12 > 1951.75)
    df
}

infix <- "" #"alldemand-"
df <- get.df(infix, localdf.sw)

timedf <- df %>% group_by(startyear, time, assump) %>% summarize(supersource=sum(supersource, na.rm=T), minefp=mean(minefp, na.rm=T))

yeardf <- timedf %>% group_by(year=round(startyear + (time - .5) / 12), assump) %>% summarize(peakfail=max(supersource, na.rm=T))

ggplot() +
    geom_line(data=timedf, aes(startyear + (time - .5) / 12, supersource, colour=assump)) +
    geom_smooth(data=yeardf, aes(year, peakfail, colour=assump), method="lm", formula=y ~ 1, se=F) +
    theme_minimal() + scale_colour_discrete(name="Assumption", breaks=c("Local flow", "No canals", "Default", "Storage")) +
    xlab(NULL) + ylab("Demand Failure (1000 m^3)") + scale_x_continuous(expand=c(0, 0))
ggsave(paste0("time-failfrac-monthly-", infix, "compare.pdf"), width=10, height=4)

df0 <- get.df("", localdf.sw)
df1 <- get.df("alldemand-", localdf.all)
df0$mytime <- df0$startyear + (df0$time - .5) / 12
df1$mytime <- df1$startyear + (df1$time - .5) / 12

if (!do.local.excess) {
    df0 <- subset(df0, assump != "Local flow")
    df1 <- subset(df1, assump != "Local flow")
}

df <- df0 %>% left_join(df1, by=c("assump", "mytime", "fips"))
df$supersource <- df$supersource.y - df$supersource.x
df$minefp.y[df$minefp.y == 37] <- 0
df$minefp <- df$minefp.y + (100 - df$minefp.x)

if (!do.local.excess) {
    df <- rbind(df[, c('assump', 'fips', 'mytime', 'supersource', 'minefp')],
                subset(cbind(data.frame(assump="Local flow", mytime=localdf.all$startyear + (localdf.all$time - .5) / 12),
                             localdf.all[, c('fips', 'supersource', 'minefp')]), mytime < 2006 & mytime > 1951.75))
}

timedf <- df %>% group_by(mytime, assump) %>% summarize(supersource=sum(supersource, na.rm=T), minefp=mean(minefp, na.rm=T))

yeardf <- timedf %>% group_by(year=round(mytime), assump) %>% summarize(peakfail=max(supersource, na.rm=T))

ggplot() +
    geom_line(data=timedf, aes(mytime, supersource, colour=assump)) +
    geom_smooth(data=yeardf, aes(year, peakfail, colour=assump), method="lm", formula=y ~ 1, se=F) +
    theme_minimal() + scale_colour_discrete(name="Assumption", breaks=c("Local flow", "No canals", "Default", "Storage")) +
    xlab(NULL) + ylab("Demand Failure (1000 m^3)") + scale_x_continuous(expand=c(0, 0))
if (do.local.excess) {
    ggsave(paste0("time-failfrac-monthly-excess-compare.pdf"), width=10, height=4)
} else {
    ggsave(paste0("time-failfrac-monthly-excess-exclocal-compare.pdf"), width=10, height=4)
}

## Make worst month files, to feed through annual map process

for (filename in list.files(".", ".*?monthly.*?\\.csv")) {
    df <- read.csv(filename)
    yeardf <- df %>% group_by(time=floor(startyear + (time - .5) / 12), fips) %>% summarize(supersource=12*max(supersource), minefp=min(minefp))
    write.csv(yeardf, gsub("monthly", "annual-worst", filename), row.names=F)
}
