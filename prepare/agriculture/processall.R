setwd("~/research/water/model/awash/prepare/agriculture")

all2010 = read.csv("all2010.csv")

chunks <- strsplit(as.character(all2010$Data.Item), " - ")

all2010$fullcrop <- NA
all2010$valuedef <- NA
for (ii in 1:nrow(all2010)) {
    all2010$fullcrop[ii] <- chunks[[ii]][1]
    all2010$valuedef[ii] <- chunks[[ii]][2]
}

all2010$fips <- sprintf("%02d%003d", all2010$State.ANSI, all2010$County.ANSI)
all2010$fips[is.na(all2010$County.ANSI)] <- NA

all2010$value <- as.numeric(gsub(",", "", as.character(all2010$Value)))

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
    subdf$fips <- fips
    df <- rbind(df, subdf)
}

