setwd("~/research/awash/analyses/waterstressindex")

suffix <- "withres-nocanal"

source("vsenv-lib.R")

df <- read.csv(paste0("stress-annual-", suffix, ".csv"))

supersources <- split.fipsyears(df$supersource, max)
minefps <- split.fipsyears(df$minefp, min)

demand <- read.csv("../../data/counties/extraction/USGS-2010.csv")
demand$allsw <- demand$TO_SW * 1383

demand$allsw[demand$allsw == 0] <- 1

plot.failavail(df$fips[1:3109], supersources$median / demand$allsw, supersources$worst / demand$allsw, minefps$median / 100, minefps$worst / 100, paste0("annual-", suffix))
