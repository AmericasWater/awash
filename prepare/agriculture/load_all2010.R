print("Reading data...")
all2010 = read.csv("all2010.csv")

print("Preparing fields...")
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
df <- data.frame(fips=c(), commodity=c(), crop=c(), area=c())

for (fips in unique(all2010$fips)) {
    if (is.na(fips))
        next
    print(fips)
    subdata <- all2010[!is.na(all2010$fips) & all2010$fips == fips,]
    subdf <- data.frame(commodity=c(), crop=c(), area=c())
    for (crop in unique(subdata$fullcrop)) {
        area <- subdata$value[subdata$valuedef == "ACRES PLANTED" & subdata$fullcrop == crop]
        if (length(area) == 0)
            area <- subdata$value[subdata$valuedef == "ACRES HARVESTED" & subdata$fullcrop == crop]
        if (length(area) == 0)
            next

        subdf <- rbind(subdf, data.frame(crop, area, commodity=subdata$Commodity[subdata$fullcrop == crop][1]))
    }
    subdf$fips <- as.numeric(fips)
    df <- rbind(df, subdf)
}

## Drop subsets
cleandf <- df[grep("IRRIGATED", df$crop, invert=T),]
cleandf <- cleandf[!(cleandf$crop %in% c("CORN, GRAIN", "SORGHUM, GRAIN", "CORN, SILAGE", "SWEET CORN, PROCESSING", "BEANS, DRY EDIBLE, PINTO")),]
