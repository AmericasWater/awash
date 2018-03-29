setwd("~/research/awash/prepare/agriculture")

all2010 = read.csv("all2010.csv")

## Split crop name from value
chunks <- strsplit(as.character(all2010$Data.Item), " - ")

all2010$fullcrop <- NA
all2010$valuedef <- NA
for (ii in 1:nrow(all2010)) {
    all2010$fullcrop[ii] <- chunks[[ii]][1]
    all2010$valuedef[ii] <- chunks[[ii]][2]
}

## Label with FIPS
all2010$fips <- sprintf("%02d%003d", all2010$State.ANSI, all2010$County.ANSI)
all2010$fips[is.na(all2010$County.ANSI)] <- NA

## Turn value into numeric
all2010$value <- as.numeric(gsub(",", "", as.character(all2010$Value)))

## Add up all areas by crop
df <- data.frame(fips=c(), crop=c(), area=c())

for (fips in unique(all2010$fips)) {
    if (is.na(fips))
        next
    print(fips)
    subdata <- all2010[!is.na(all2010$fips) & all2010$fips == fips,]
    subdf <- data.frame(crop=c(), area=c())
    for (crop in unique(subdata$fullcrop)) {
        area <- subdata$value[subdata$valuedef == "ACRES PLANTED" & subdata$fullcrop == crop]
        if (length(area) == 0)
            area <- subdata$value[subdata$valuedef == "ACRES HARVESTED" & subdata$fullcrop == crop]
        if (length(area) == 0)
            next

        subdf <- rbind(subdf, data.frame(crop, area))
    }
    subdf$fips <- as.numeric(fips)
    df <- rbind(df, subdf)
}

## Drop subsets
cleandf <- df[grep("IRRIGATED", df$crop, invert=T),]
cleandf <- cleandf[!(cleandf$crop %in% c("CORN, GRAIN", "SORGHUM, GRAIN", "CORN, SILAGE", "SWEET CORN, PROCESSING", "BEANS, DRY EDIBLE, PINTO")),]

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
