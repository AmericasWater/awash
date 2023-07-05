setwd("~/research/awash/prepare/agriculture")

source("load_all2010.R")

## Prepare to add up all knowns
cleandf$is.known <- F
cleandf$is.known[grep("ALFALFA|HAY|BARLEY|CORN|SORGHUM|SOYBEANS|WHEAT", cleandf$crop)] <- T

counties <- read.csv("../../data/global/counties.csv")

byfips <- data.frame(fips=c(), known=c(), total=c())
for (ii in 1:nrow(counties)) {
    fips <- counties$fips[ii]
    subdf <- subset(cleandf, fips == counties$fips[ii])
    newrow <- data.frame(fips, known=sum(subdf$area[subdf$is.known]), total=sum(subdf$area))

    for (crop in c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT"))
        newrow[, crop] <- sum(subdf$area[grep(crop, subdf$crop)])

    byfips <- rbind(byfips, newrow)
}

write.csv(byfips, "../../data/counties/agriculture/knownareas.csv", row.names=F)

library(ggplot2)

ggplot(byfips, aes(x=total, y=known)) +
    geom_point() + scale_x_log10() + scale_y_log10() + xlab("Total Area") + ylab("Known Crops Area")
