##setwd("~/research/water/model/operational-problem/prepare/world")

library(datasets)

counties <- read.csv("tigercounties.csv")

## Clean up data
allus <- data.frame(fips=counties$STATE * 100 + counties$COUNTY / 10, name=counties$NHGISNAM)
allus$state <- NA
for (statename in unique(counties$STATENAM)) {
    if (statename == "District of Columbia")
        allus$state[counties$STATENAM == statename] = "DC"
    else
        allus$state[counties$STATENAM == statename] = state.abb[state.name == statename]
}

allus$fips <- as.character(allus$fips)
allus$fips[nchar(allus$fips) < 5] <- paste0("0", allus$fips[nchar(allus$fips) < 5])

## Drop Alaska and Hawaii
contus <- allus[!(allus$state %in% c("AK", "HI")), ]

## Order by FIPS
contus <- contus[order(contus$fips),]

write.csv(contus, "../../data/global/counties.csv", row.names=F)
