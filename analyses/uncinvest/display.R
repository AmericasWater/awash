setwd("~/research/water/awash6/analyses/uncinvest")

decrease <- read.csv("decrease-bycost.csv")

library(ggplot2)

ggplot(decrease, aes(scale, decrease)) +
    geom_line() + scale_y_log10() + scale_x_log10(breaks=c(1e8, 1e9))

decrease$factscale <- factor(decrease$scale, levels=sort(decrease$scale))

alldf <- data.frame(factscale=rep(decrease$factscale, 4), decrease=c(decrease$decrease, -decrease$increase, decrease$numdecs, rep(0, nrow(decrease))), group=rep(c("Decrease", "Increase", "Decrease", "Increase"), each=nrow(decrease)), panel=rep(c("Volume", "Volume", "Count", "Count"), each=nrow(decrease)))

ggplot(alldf, aes(factscale, decrease, fill=group)) +
    facet_grid(panel ~ ., scales="free") +
    geom_bar(stat="identity") +
    #geom_hline(yintercept=1.0399367718069601e9) +
    theme_bw() + ggtitle("Optimal removal vs. removal costs") +
    scale_fill_discrete(name=NULL) +
    xlab("Scaling for removal costs") + ylab("Removal capacity (1000 m^3) or Count")

load("~/research/water/awash/data/counties/waternet/waternet.RData")
source("../../rlib/load_display.R")
library(maps)

decreases <- read.csv("decreases.csv")

##decreases <- decreases[-which(decreases$maxcap == max(decreases$maxcap)),]

pdf("decreases.pdf", width=8, height=5)
par(mar=rep(0, 4))
map("state")
drawNetwork(network, col="#00008040")
points(decreases$lon, decreases$lat, cex=sqrt(decreases$maxcap / 1e10))
points(decreases$lon, decreases$lat, cex=sqrt(1000 * decreases$decrease / 1e10), col='red')
points(decreases$lon, decreases$lat, cex=sqrt(1000 * decreases$decrease / 1e10), pch=16, col='red')
points(decreases$lon[decreases$decrease > 0], decreases$lat[decreases$decrease > 0], cex=1 + sqrt(decreases$maxcap[decreases$decrease > 0] / 1e10), col='#008000')
points(decreases$lon[decreases$decrease > 0], decreases$lat[decreases$decrease > 0], cex=1.2 + sqrt(decreases$maxcap[decreases$decrease > 0] / 1e10), col='#008000')
dev.off()

captures <- read.csv(paste0("captures-monthly-37.0.csv"))

alldf <- cbind(decreases, captures)
alldf$aftermonthly <- alldf$decrease - alldf$capmaxs
