setwd("~/research/water/awash/analyses/landvalue")

do.notime <- T

if (do.notime) {
    periods <- c("Observed", "Optimal\nCurrent", "Unadapted\n2050", "Optimal\n2050", "Unadapted\n2070", "Optimal\n2070")
    prefixes <- c("observed", "current", "unadapted-histco", "all2050", "unadapted-histco", "all2070")
    ## lowersuffixes <- c("pfixmo-zeroy", NA, "pfixmo-notime-zeroy")
    ## uppersuffixes <- c("pfixmo-limity", NA, "pfixmo-notime-limity")
    suffixes <- c(NA, "pfixmo-chirr", NA, "pfixmo-notime-histco", NA, "pfixmo-notime-histco")
} else {
    periods <- c("No C.C.\n2050", "With C.C.\n2050", "No C.C.\n2070", "With C.C.\n2070")
    prefixes <- c("pfixmo-2050", "all2050", "pfixmo-2070", "all2070")
    suffixes <- c(NA, "pfixmo-histco", NA, "pfixmo-histco")
}

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
        yields.file <- "currentyields-pfixmo-chirr.csv"
        profits.file <- "currentprofits-pfixmo-chirr.csv"
    } else if (is.na(suffixes[ii])) {
        if (do.notime) {
            allocation.file <- paste0("constopt-currentprofits-", suffixes[2], ".csv")
            yields.file <- paste0(prefixes[ii+1], "yields-", suffixes[ii+1], ".csv")
            profits.file <- paste0(prefixes[ii+1], "profits-", suffixes[ii+1], ".csv")
        } else {
            allocation.file <- paste0("constopt-currentprofits-", prefixes[ii], ".csv")
            yields.file <- paste0("currentyields-", prefixes[ii], ".csv")
            profits.file <- paste0("currentprofits-", prefixes[ii], ".csv")
        }
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

        allocation <- read.csv("results/constopt-currentprofits-pfixmo-chirr.csv")
        for (jj in 1:nrow(allocation)) {
            subdf <- subset(obsdf, fips == allocation$fips[jj])
            rows <- grep("ACRES", subdf$Data.Item)
            allocation$Barley[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "BARLEY"] * 0.404686)
            allocation$Corn[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "CORN"] * 0.404686)
            allocation$Cotton[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "COTTON"] * 0.404686)
            allocation$Rice[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "RICE"] * 0.404686)
            allocation$Soybean[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "SOYBEANS"] * 0.404686)
            allocation$Wheat[jj] <- max(0, subdf$value[rows][subdf$Commodity[rows] == "WHEAT"] * 0.404686)
        }
    } else {
        allocation <- read.csv(file.path("results", allocation.file))
    }
    yields <- read.csv(file.path("results", yields.file), header=F)
    profits <- read.csv(file.path("results", profits.file), header=F)

    allocation[, 3:8][profits == -Inf] <- 0 # Just affects observed

    production <- colSums(allocation[, 3:8] * yields, na.rm=T)
    profit <- colSums(allocation[, 3:8] * profits, na.rm=T)

    df <- rbind(df, data.frame(period=periods[ii], crop=names(allocation)[3:8], production, profit))
}

library(ggplot2)
library(reshape2)
library(xtable)

## ggplot(df, aes(crop, (productionlo + productionhi) / 2, fill=period)) +
##     geom_bar(stat="identity", position=position_dodge()) +
##     geom_errorbar(aes(ymin=productionlo, ymax=productionhi), width=.4, position=position_dodge(.9)) +
##     theme_bw() + xlab(NULL) + ylab("Production")

## ggplot(data.frame(period=rep(df$period, 2), profit=c(df$profitlo, df$profithi), crop=rep(df$crop, 2), assump=rep(c('zero', 'limit'), each=nrow(df))), aes(factor(paste(period, assump), levels=c("current zero", "current limit", "unadapted zero", "unadapted limit", "future zero", "future limit")), profit, fill=crop)) +
##     geom_bar(stat="identity") +
##     theme_bw() + xlab(NULL) + ylab("Profit (USD)")

if (do.notime) {
    df$optimized <- "Observed"
    if ("Optimal\nCurrent" %in% df$period) {
        df$optimized[df$period %in% c("Optimal\nCurrent", "Optimal\n2050", "Optimal\n2070")] <- "Optimized"
    } else {
        df$optimized[7:12] <- "Optimized"
        df$optimized[19:24] <- "Optimized"
        df$optimized[31:36] <- "Optimized"
    }

    df$period <- as.character(df$period)
    df$period[df$period %in% c("Observed", "Optimal\nCurrent")] <- "2010"
    df$period[df$period %in% c("Unadapted\n2050", "Optimal\n2050")] <- "2050"
    df$period[df$period %in% c("Unadapted\n2070", "Optimal\n2070")] <- "2070"
    df$period <- factor(df$period, levels=c("2010", "2050", "2070"))

    ggplot(df, aes(period, production, fill=optimized)) +
        facet_wrap(~ crop, scales="free") +
        geom_bar(stat="identity", position=position_dodge()) +
        scale_fill_discrete(name="") +
        theme_bw() + xlab(NULL) + ylab("Production")

    df$prode9 <- df$production / 1e9

    printdf <- dcast(df, crop ~ period + optimized, value.var='prode9')
    printdf$crop <- c("Barley (Bbu.)", "Corn (Bbu.)", "Cotton (Blb)", "Rice (Blb)", "Soybeans (Bbu.)", "Wheat (Bbu.)")
    print(xtable(printdf), digits=3, include.rownames=F)

    printdf <- cbind(data.frame(crop=printdf$crop),
                 rbind(100 * printdf[1, 2:7] / printdf[1, 2],
                       100 * printdf[2, 2:7] / printdf[2, 2],
                       100 * printdf[3, 2:7] / printdf[3, 2],
                       100 * printdf[4, 2:7] / printdf[4, 2],
                       100 * printdf[5, 2:7] / printdf[5, 2],
                       100 * printdf[6, 2:7] / printdf[6, 2]))
    printdf$crop <- c("Barley (\\%)", "Corn (\\%)", "Cotton (\\%)", "Rice (\\%)", "Soybeans (\\%)", "Wheat (\\%)")
    print(xtable(printdf, digits=0), include.rownames=F)

    ggplot(df, aes(optimized, profit, fill=crop)) +
        facet_grid(. ~ period) +
        geom_bar(stat="identity") +
        scale_fill_discrete(name="") +
        theme_bw() + xlab(NULL) + ylab("Profit (USD)")

    sum(df$profit[df$period == 2010 & df$optimized == 'Observed']) / 1e9
    sum(df$profit[df$period == 2010 & df$optimized == 'Optimized']) / 1e9
    sum(df$profit[df$period == 2050 & df$optimized == 'Observed']) / 1e9
    sum(df$profit[df$period == 2050 & df$optimized == 'Optimized']) / 1e9
    sum(df$profit[df$period == 2070 & df$optimized == 'Observed']) / 1e9
    sum(df$profit[df$period == 2070 & df$optimized == 'Optimized']) / 1e9

    1 - sum(df$profit[df$period == 2070 & df$optimized == 'Observed']) / sum(df$profit[df$period == 2010 & df$optimized == 'Observed'])
    1 - sum(df$profit[df$period == 2070 & df$optimized == 'Optimized']) / sum(df$profit[df$period == 2010 & df$optimized == 'Observed'])
} else {
    df$prode9 <- df$production / 1e9

    printdf <- dcast(df, crop ~ period, value.var='prode9')
    printdf$crop <- c("Barley (Bbu.)", "Corn (Bbu.)", "Cotton (Blb)", "Rice (Blb)", "Soybeans (Bbu.)", "Wheat (Bbu.)")
    print(xtable(printdf), digits=3, include.rownames=F)

    printdf <- cbind(data.frame(crop=printdf$crop),
                     rbind(100 * printdf[1, 2:5] / c(printdf[1, 2], printdf[1, 2], printdf[1, 4], printdf[1, 4]),
                           100 * printdf[2, 2:5] / c(printdf[2, 2], printdf[2, 2], printdf[2, 4], printdf[2, 4]),
                           100 * printdf[3, 2:5] / c(printdf[3, 2], printdf[3, 2], printdf[3, 4], printdf[3, 4]),
                           100 * printdf[4, 2:5] / c(printdf[4, 2], printdf[4, 2], printdf[4, 4], printdf[4, 4]),
                           100 * printdf[5, 2:5] / c(printdf[5, 2], printdf[5, 2], printdf[5, 4], printdf[5, 4]),
                           100 * printdf[6, 2:5] / c(printdf[6, 2], printdf[6, 2], printdf[6, 4], printdf[6, 4])))
    printdf$crop <- c("Barley (\\%)", "Corn (\\%)", "Cotton (\\%)", "Rice (\\%)", "Soybeans (\\%)", "Wheat (\\%)")
    print(xtable(printdf, digits=0), include.rownames=F)

    ggplot(df, aes(period, profit, fill=crop)) +
        geom_bar(stat="identity") +
        scale_fill_discrete(name="") +
        theme_bw() + xlab(NULL) + ylab("Profit (USD)")

}
