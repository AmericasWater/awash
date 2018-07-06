setwd("~/research/awash/analyses/landvalue")

periods <- c("Observed", "Optimal\nCurrent", "Unadapted\n2070 CC", "Unadapted\n2070 HC", "Optimal\n2070 CC", "Optimal\n2070 HC")
prefixes <- c("observed", "current", "unadapted", "unadapted-histco", "all2070", "all2070")
## lowersuffixes <- c("pfixed-zeroy", NA, "pfixed-notime-zeroy")
## uppersuffixes <- c("pfixed-limity", NA, "pfixed-notime-limity")
suffixes <- c(NA, "pfixed", NA, NA, "pfixed-notime", "pfixed-notime-histco")

df <- data.frame(period=c(), crop=c(), productionlo=c(), productionhi=c(), profitlo=c(), profithi=c())

for (ii in 1:length(periods)) {
    ## if (periods[ii] == "unadapted") {
    ##     allocationlo.file <- paste0("constopt-currentprofits-", lowersuffixes[1], ".csv")
    ##     yieldslo.file <- paste0("futureyields-", lowersuffixes[3], ".csv")
    ##     profitslo.file <- paste0("futureprofits-", lowersuffixes[3], ".csv")
    ## } else {
    ##     allocationlo.file <- paste0("constopt-", periods[ii], "profits-", lowersuffixes[ii], ".csv")
    ##     yieldslo.file <- paste0(periods[ii], "yields-", lowersuffixes[ii], ".csv")
    ##     profitslo.file <- paste0(periods[ii], "profits-", lowersuffixes[ii], ".csv")
    ## }

    ## allocationlo <- read.csv(allocationlo.file)
    ## yieldslo <- read.csv(yieldslo.file, header=F)
    ## profitslo <- read.csv(profitslo.file, header=F)

    ## productionlo <- colSums(allocationlo[, 3:8] * yieldslo, na.rm=T)
    ## profitlo <- colSums(allocationlo[, 3:8] * profitslo, na.rm=T)

    ## if (periods[ii] == "unadapted") {
    ##     allocationhi.file <- paste0("constopt-currentprofits-", uppersuffixes[1], ".csv")
    ##     yieldshi.file <- paste0("futureyields-", uppersuffixes[3], ".csv")
    ##     profitshi.file <- paste0("futureprofits-", uppersuffixes[3], ".csv")
    ## } else {
    ##     allocationhi.file <- paste0("constopt-", periods[ii], "profits-", uppersuffixes[ii], ".csv")
    ##     yieldshi.file <- paste0(periods[ii], "yields-", uppersuffixes[ii], ".csv")
    ##     profitshi.file <- paste0(periods[ii], "profits-", uppersuffixes[ii], ".csv")
    ## }

    ## allocationhi <- read.csv(allocationhi.file)
    ## yieldshi <- read.csv(yieldshi.file, header=F)
    ## profitshi <- read.csv(profitshi.file, header=F)

    ## productionhi <- colSums(allocationhi[, 3:8] * yieldshi, na.rm=T)
    ## profithi <- colSums(allocationhi[, 3:8] * profitshi, na.rm=T)

    ## df <- rbind(df, data.frame(period=periods[ii], crop=names(allocation)[3:8], productionlo, productionhi, profitlo, profithi))

    if (prefixes[ii] == "observed") {
        allocation.file <- "../../prepare/agriculture/all2010.csv"
        yields.file <- "currentyields-pfixed.csv"
        profits.file <- "currentprofits-pfixed.csv"
    } else if (is.na(suffixes[ii])) {
        allocation.file <- paste0("constopt-currentprofits-", suffixes[2], ".csv")
        yields.file <- paste0(prefixes[ii+2], "yields-", suffixes[ii+2], ".csv")
        profits.file <- paste0(prefixes[ii+2], "profits-", suffixes[ii+2], ".csv")
    } else {
        allocation.file <- paste0("constopt-", prefixes[ii], "profits-", suffixes[ii], ".csv")
        yields.file <- paste0(prefixes[ii], "yields-", suffixes[ii], ".csv")
        profits.file <- paste0(prefixes[ii], "profits-", suffixes[ii], ".csv")
    }

    if (allocation.file == "../../prepare/agriculture/all2010.csv") {
        obsdf <- read.csv("../../prepare/agriculture/all2010.csv")
        obsdf <- subset(obsdf, Commodity %in% c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT"))
        obsdf$value <- as.numeric(gsub(",", "", as.character(obsdf$Value)))
        obsdf$fips <- obsdf$State.ANSI * 1000 + obsdf$County.ANSI
        obsdf$fips[is.na(obsdf$fips)] <- obsdf$State.ANSI[is.na(obsdf$fips)] * 1000
        
        allocation <- read.csv("constopt-currentprofits-pfixed.csv")
        for (jj in 1:nrow(allocation)) {
            subdf <- subset(obsdf, fips == allocation$fips[jj])
            rows <- grep("ACRES", subdf$Data.Item)
            allocation$Barley[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "BARLEY"])
            allocation$Corn[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "CORN"])
            allocation$Cotton[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "COTTON"])
            allocation$Rice[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "RICE"])
            allocation$Soybean[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "SOYBEANS"])
            allocation$Wheat[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "WHEAT"])
        }
    } else {
        allocation <- read.csv(allocation.file)
    }
    yields <- read.csv(yields.file, header=F)
    profits <- read.csv(profits.file, header=F)

    production <- colSums(allocation[, 3:8] * yields, na.rm=T)
    profit <- colSums(allocation[, 3:8] * profits, na.rm=T)

    df <- rbind(df, data.frame(period=periods[ii], crop=names(allocation)[3:8], production, profit))
}

library(ggplot2)

## ggplot(df, aes(crop, (productionlo + productionhi) / 2, fill=period)) +
##     geom_bar(stat="identity", position=position_dodge()) +
##     geom_errorbar(aes(ymin=productionlo, ymax=productionhi), width=.4, position=position_dodge(.9)) +
##     theme_bw() + xlab(NULL) + ylab("Production")

## ggplot(data.frame(period=rep(df$period, 2), profit=c(df$profitlo, df$profithi), crop=rep(df$crop, 2), assump=rep(c('zero', 'limit'), each=nrow(df))), aes(factor(paste(period, assump), levels=c("current zero", "current limit", "unadapted zero", "unadapted limit", "future zero", "future limit")), profit, fill=crop)) +
##     geom_bar(stat="identity") +
##     theme_bw() + xlab(NULL) + ylab("Profit (USD)")


ggplot(subset(df, period %in% c("Optimal\nCurrent", "Unadapted\n2070 HC", "Optimal\n2070 HC")), aes(crop, production, fill=period)) +
    geom_bar(stat="identity", position=position_dodge()) +
    theme_bw() + xlab(NULL) + ylab("Production")

library(reshape2)
df$prode9 <- df$production / 1e9
printdf <- dcast(subset(df, period %in% c("Optimal\nCurrent", "Unadapted\n2070 HC", "Optimal\n2070 HC")), period ~ crop, value.var='prode9')
printdf$period <- c("Optimal Current", "Unadapted 2070 HC", "Optimal HC")

printdf <- rbind(printdf, cbind(data.frame(period=printdf$period), rbind(printdf[1, -1] / printdf[1, -1],
                                                      printdf[2, -1] / printdf[1, -1],
                                                      printdf[3, -1] / printdf[1, -1])))

library(xtable)
print(xtable(printdf), digits=3, include.rownames=F)

ggplot(df, aes(period, profit, fill=crop)) +
    geom_bar(stat="identity") +
    theme_bw() + xlab(NULL) + ylab("Profit (USD)")
