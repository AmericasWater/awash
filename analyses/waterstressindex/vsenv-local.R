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

source("~/projects/research-common/R/ggmap.R")
library(png)
library(grid)
library(cowplot)

gl <- rasterGrob(readPNG("failfrac-legend.png"), interpolate=TRUE)
gg <- gg.usmap(df$failurefrac, df$FIPS, df$failurefrac.worst, extra.polygon.aes=aes(size=borders)) +
    scale_fill_gradientn(name="Failure\nFraction", colours=c("#91bfdb", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_colour_gradientn(name="Failure\nFraction", colours=c("#91bfdb", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_size(range=c(0, .5)) + guides(size=F) +
    theme(legend.justification=c(1,0), legend.position=c(1,0),
          panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
          axis.text.x=element_blank(), axis.text.y=element_blank(),
          plot.margin=unit(rep(0, 4), "cm")) + scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
hh <- ggdraw(gg)
hh + draw_grob(gl, 0.05, 0.02, 0.22, 0.2)
ggsave("failfrac-local.pdf", width=5.9, height=3.2)

gl <- rasterGrob(readPNG("natflowa-legend.png"), interpolate=TRUE)
gg <- gg.usmap(df$natflowav, df$FIPS, df$natflowav.worst, extra.polygon.aes=aes(size=1 - borders)) +
    scale_fill_gradientn(name="Natural\nFlow\nAvailable", colours=c("#fee090", "#fee090", "#abd9e9", "#74add1", "#313695"), values=c(0, .37, .37001, .685, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_colour_gradientn(name="Natural\nFlow\nAvailable", colours=c("#fee090", "#fee090", "#abd9e9", "#74add1", "#313695"), values=c(0, .37, .37001, .685, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_size(range=c(0, .5)) + guides(size=F) +
    theme(legend.justification=c(1,0), legend.position=c(1,0),
          panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
          axis.text.x=element_blank(), axis.text.y=element_blank(),
          plot.margin=unit(rep(0, 4), "cm")) +
        scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
hh <- ggdraw(gg)
hh + draw_grob(gl, 0.05, 0.02, 0.22, 0.2)
ggsave("natflowa-local.pdf", width=5.9, height=3.2)
