## setwd("~/research/water/awash/prepare/agriculture")

calendars <- read.csv("countycalendars.csv")

source("load_all2010.R")

calcropmap <- list('COTTON'='Cotton', 'HAY'=NA, 'PEANUTS'='Groundnuts', 'SOYBEANS'='Soybeans', 'CORN'=c('Maize', 'Maize.2'),
                   'SWEET POTATOES'=c('Sweet.Potatoes', 'Yams'), 'BARLEY'=c('Barley.Winter', 'Barley'), 'WHEAT'=c('Wheat.Winter', 'Wheat'),
                   'RICE'=c('Rice', 'Rice.2'), 'SORGHUM'=c('Sorghum', 'Sorghum.2'), 'TOMATOES'=NA, 'SUGARBEETS'='Sugarbeets',
                   'BEANS'='Pulses', 'SUNFLOWER'='Sunflower', 'POTATOES'='Potatoes', 'SUGARCANE'=NA, 'TOBACCO'=NA,
                   'OATS'=c('Oats', 'Oats.Winter'), 'PEAS'='Pulses', 'SWEET CORN'=c('Maize', 'Maize.2'), 'LENTILS'='Pulses',
                   'CANOLA'='Rapeseed.Winter', 'FLAXSEED'=NA, 'MUSTARD'=NA, 'SAFFLOWER'=NA, 'APPLES'=NA, 'PEACHES'=NA)

library(dplyr)

cleandf2 <- cleandf %>% group_by(commodity, fips) %>% summarize(area=sum(area))

cleandf2$calcrop1 <- NA
cleandf2$calcrop2 <- NA
for (crop in unique(cleandf2$commodity)) {
    cleandf2$calcrop1[cleandf2$commodity == crop] <- calcropmap[[crop]][1]
    cleandf2$calcrop2[cleandf2$commodity == crop] <- calcropmap[[crop]][2]
}

cleandf3 <- cleandf2 %>% left_join(calendars, by=c('calcrop1'='crop', 'fips'), suffix=c('', '.cc1')) %>%
    left_join(calendars, by=c('calcrop2'='crop', 'fips'), suffix=c('', '.cc2'))

daypermonth <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
monthstarts <- c(1, 1 + cumsum(daypermonth))

finals <- matrix(NA, 0, 12)
finals.daily <- matrix(NA, 0, 365)
for (fips in unique(cleandf3$fips)) {
    print(fips)
    subdata <- cleandf3[cleandf3$fips == fips,]
    byday <- rep(0, 365)
    for (ii in 1:nrow(subdata)) {
        fraccrop <- subdata$area[ii] / sum(subdata$area)
        if (is.na(subdata$plant[ii]))
            weighting <- rep(1 / 365, 365)
        else {
            weighting <- rep(0, 365)
            if (subdata$plant[ii] < 0) {
                weighting[(365 + subdata$plant[ii]):365] <- 1
                weighting[1:subdata$harvest[ii]] <- 1
            } else
                weighting[subdata$plant[ii]:subdata$harvest[ii]] <- 1
            if (!is.na(subdata$plant.cc2[ii])) {
                weighting <- weighting * 2/3
                if (subdata$plant[ii] < 0) {
                    weighting[(365 + subdata$plant[ii]):365] <- weighting[(365 + subdata$plant[ii]):365] + 1/3
                    weighting[1:subdata$harvest[ii]] <- weighting[1:subdata$harvest[ii]] + 1/3
                } else
                    weighting[subdata$plant[ii]:subdata$harvest[ii]] <- weighting[subdata$plant[ii]:subdata$harvest[ii]] + 1/3
            }
            weighting <- weighting / sum(weighting)
        }

        byday <- byday + weighting * fraccrop
    }

    finals.daily <- rbind(finals.daily, byday)

    bymonth <- rep(NA, 12)
    for (mm in 1:12)
        bymonth[mm] <- sum(byday[monthstarts[mm]:(monthstarts[mm+1]-1)])
    finals <- rbind(finals, bymonth)
}

image(y=1:365, x=1:nrow(finals), z=finals.daily, xlab="County (unordered)", ylab="Day of the year", main="Shares of irrigation demand by day")

library(ggplot2)
library(reshape2)
##rownames(finals.daily) <- 1:length(unique(cleandf3$fips))
myorder <- 1:length(unique(cleandf3$fips))
myorder[order(unique(cleandf3$fips))] <- 1:length(unique(cleandf3$fips))
rownames(finals.daily) <- myorder

library(maps)
fipsstates <- c()
for (ord in 1:length(unique(cleandf3$fips))) {
    fips <- unique(cleandf3$fips)[myorder == ord]
    statefips <- floor(fips / 1000)
    fipsstates <- c(fipsstates, state.fips$abb[state.fips$fips == statefips][1])
}
fipsbreaks <- which(!duplicated(fipsstates))
fipslabels <- fipsstates[fipsbreaks]

ggplot(melt(finals.daily), aes(Var1,Var2, fill=value)) + geom_raster() +
    scale_x_continuous(expand=c(0, 0), breaks=fipsbreaks, labels=fipslabels) + scale_y_continuous(expand=c(0, 0)) +
    ylab("Day of the year") + scale_fill_continuous(name="Daily share") + xlab(NULL)

plot(colSums(finals) / nrow(finals), type='l', xlab="Month", ylab="Share of irrigation demand")

plotdf <- data.frame(month=month.abb, share=colSums(finals) / nrow(finals))
plotdf$month <- factor(plotdf$month, levels=month.abb)

ggplot(plotdf, aes(month, share)) +
    geom_bar(stat="identity") + theme_bw() + xlab(NULL) + ylab("Average monthly share")

finaldf <- as.data.frame(finals)
finaldf$fips <- unique(cleandf3$fips)
names(finaldf) <- c(month.abb, 'fips')

write.csv(finaldf, "../../data/counties/demand/agmonthshares.csv", row.names=F)
