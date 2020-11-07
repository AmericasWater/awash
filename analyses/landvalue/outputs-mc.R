## setwd("~/research/water/awash-crops/analyses/landvalue")

do.notime <- T
nummc <- 1000

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

biomodels = c("ac", "bc", "cc", "cn", "gf", "gs",
              "hd", "he", "hg", "in", "ip", "mc",
              "mg", "mi", "mp", "mr" , "no")

mcpath <- function(filename, mcmc) {
    if (length(grep("all20", filename)) > 0)
        file.path("results-mc", gsub(".csv", paste0("-", biomodels[mcmc %% length(biomodels) + 1], "-", mcmc, ".csv"), filename))
    else
        file.path("results-mc", gsub(".csv", paste0("-", mcmc, ".csv"), filename))
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
    }

    for (mcmc in 1:nummc) {
        print(c(periods[ii], mcmc))
        if (allocation.file == "../../prepare/agriculture/all2010.csv") {
            allocation <- read.csv(paste0("results-mc/constopt-currentprofits-pfixmo-chirr-", mcmc, ".csv"))
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
            allocation <- read.csv(mcpath(allocation.file, mcmc))
        }
        yields <- read.csv(mcpath(yields.file, mcmc), header=F)
        profits <- read.csv(mcpath(profits.file, mcmc), header=F)

        allocation[, 3:8][profits == -Inf] <- 0 # Just affects observed

        production <- colSums(allocation[, 3:8] * yields, na.rm=T)
        profit <- colSums(allocation[, 3:8] * profits, na.rm=T)

        df <- rbind(df, data.frame(period=periods[ii], mcmc, crop=names(allocation)[3:8], production, profit))
    }
}

library(ggplot2)
library(reshape2)
library(xtable)
library(dplyr)

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

    df2 <- df %>% group_by(period, crop, optimized) %>% summarize(prod=mean(production), prod.025=quantile(production, .025), prod.975=quantile(production, .975), prod.min=min(production), prod.max=max(production), prof=mean(profit), prof.025=quantile(profit, .025), prof.975=quantile(profit, .975), prof.min=min(profit), prof.max=max(profit))

    df2$period <- as.character(df2$period)
    df2$period[df2$period %in% c("Observed", "Optimal\nCurrent")] <- "2010"
    df2$period[df2$period %in% c("Unadapted\n2050", "Optimal\n2050")] <- "2050"
    df2$period[df2$period %in% c("Unadapted\n2070", "Optimal\n2070")] <- "2070"
    df2$period <- factor(df2$period, levels=c("2010", "2050", "2070"))

    ggplot(df2, aes(period, prod / 1e9, fill=optimized)) +
        facet_wrap(~ crop, scales="free") +
        geom_bar(stat="identity", position=position_dodge()) +
        geom_linerange(aes(ymin=prod.min / 1e9, ymax=prod.max / 1e9), position=position_dodge(.9), alpha=.5) +
        geom_errorbar(aes(ymin=prod.025 / 1e9, ymax=prod.975 / 1e9), position=position_dodge(.9), width=.7) +
        scale_fill_discrete(name="") +
        theme_bw() + xlab(NULL) + ylab("Production (Bbu. and Blb)")
    ggsave("figures/barprod-mc.pdf", width=10, height=3)

    ## Total profits under various scenarios
    df3 <- df %>% group_by(mcmc, period, optimized) %>% summarize(profit=sum(profit)) %>%
      group_by(period, optimized) %>% summarize(prof=mean(profit), prof.025=quantile(profit, .025), prof.975=quantile(profit, .975))
    print("Profit by scenario")
    print(df3)

    df2$prode9 <- df2$prod / 1e9

    printdf <- dcast(df2, crop ~ period + optimized, value.var='prode9')
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

    df2.total <- df %>% group_by(period, optimized, mcmc) %>% summarize(production=sum(production), profit=sum(profit)) %>% group_by(period, optimized) %>% summarize(prod=mean(production), prod.025=quantile(production, .025), prod.975=quantile(production, .975), prof=mean(profit), prof.025=quantile(profit, .025), prof.975=quantile(profit, .975))

    df2.total$period <- as.character(df2.total$period)
    df2.total$period[df2.total$period %in% c("Observed", "Optimal\nCurrent")] <- "2010"
    df2.total$period[df2.total$period %in% c("Unadapted\n2050", "Optimal\n2050")] <- "2050"
    df2.total$period[df2.total$period %in% c("Unadapted\n2070", "Optimal\n2070")] <- "2070"
    df2.total$period <- factor(df2.total$period, levels=c("2010", "2050", "2070"))

    ggplot(df2, aes(optimized, prof / 1e9)) +
        facet_grid(. ~ period) +
        geom_bar(stat="identity", aes(fill=crop)) +
        geom_errorbar(data=df2.total, aes(ymin=prof.025 / 1e9, ymax=prof.975 / 1e9), width=.5) +
        scale_fill_discrete(name="") +
        theme_bw() + xlab(NULL) + ylab("Profit (billion USD)")
    ggsave("figures/barprofit-mc.pdf", width=9, height=3)

    ## Production changes
    sum(df$profit[df$period == 2010 & df$optimized == 'Observed']) / 1e9
    sum(df$profit[df$period == 2010 & df$optimized == 'Optimized']) / 1e9
    sum(df$profit[df$period == 2050 & df$optimized == 'Observed']) / 1e9
    sum(df$profit[df$period == 2050 & df$optimized == 'Optimized']) / 1e9
    sum(df$profit[df$period == 2070 & df$optimized == 'Observed']) / 1e9
    sum(df$profit[df$period == 2070 & df$optimized == 'Optimized']) / 1e9

    1 - sum(df$profit[df$period == 2070 & df$optimized == 'Observed']) / sum(df$profit[df$period == 2010 & df$optimized == 'Observed'])
    1 - sum(df$profit[df$period == 2070 & df$optimized == 'Optimized']) / sum(df$profit[df$period == 2010 & df$optimized == 'Observed'])

    df$prode9 <- df$production / 1e9
    df$year <- NA
    df$year[df$period %in% c("Observed", "Optimal\nCurrent")] <- 2010
    df$year[df$period %in% c("Unadapted\n2050", "Optimal\n2050")] <- 2050
    df$year[df$period %in% c("Unadapted\n2070", "Optimal\n2070")] <- 2070

    printdf <- data.frame(crop=c(), ch2010obs=c(), ch2070obs=c(), ch2070opt=c())
    for (crop in unique(df$crop)) {
        ch2010obs <- format(mean(df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Optimized'] / df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Observed']), digits=3)
        ch2070obs <- format(mean(df$production[df$crop == crop & df$year == 2070 & df$optimized == 'Optimized'] / df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Observed']), digits=3)
        ch2070opt <- format(mean(df$production[df$crop == crop & df$year == 2070 & df$optimized == 'Optimized'] / df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Optimized']), digits=3)
        printdf <- rbind(printdf, data.frame(crop, ch2010obs, ch2070obs, ch2070opt))
        ch2010obs <- paste(format(quantile(df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Optimized'] / df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Observed'], c(.025, .975)), digits=3), collapse=" - ")
        ch2070obs <- paste(format(quantile(df$production[df$crop == crop & df$year == 2070 & df$optimized == 'Optimized'] / df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Observed'], c(.025, .975)), digits=3), collapse=" - ")
        ch2070opt <- paste(format(quantile(df$production[df$crop == crop & df$year == 2070 & df$optimized == 'Optimized'] / df$production[df$crop == crop & df$year == 2010 & df$optimized == 'Optimized'], c(.025, .975)), digits=3), collapse=" - ")
        printdf <- rbind(printdf, data.frame(crop, ch2010obs, ch2070obs, ch2070opt))
    }

    print("Production by scenario")
    print(xtable(printdf), include.rownames=F)
} else {
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

    ggplot(df2, aes(period, profit, fill=crop)) +
        geom_bar(stat="identity") +
        scale_fill_discrete(name="") +
        theme_bw() + xlab(NULL) + ylab("Profit (USD)")
}
