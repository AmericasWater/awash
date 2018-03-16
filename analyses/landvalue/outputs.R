setwd("~/research/water/awash/analyses/landvalue")

periods <- c("current", "unadapted", "future")
lowersuffixes <- c("pfixed-zeroy", NA, "pfixed-notime-zeroy")
uppersuffixes <- c("pfixed-limity", NA, "pfixed-notime-limity")

df <- data.frame(period=c(), crop=c(), productionlo=c(), productionhi=c(), profitlo=c(), profithi=c())

for (ii in 1:length(periods)) {
    if (periods[ii] == "unadapted") {
        allocationlo.file <- paste0("constopt-currentprofits-", lowersuffixes[1], ".csv")
        yieldslo.file <- paste0("futureyields-", lowersuffixes[3], ".csv")
        profitslo.file <- paste0("futureprofits-", lowersuffixes[3], ".csv")
    } else {
        allocationlo.file <- paste0("constopt-", periods[ii], "profits-", lowersuffixes[ii], ".csv")
        yieldslo.file <- paste0(periods[ii], "yields-", lowersuffixes[ii], ".csv")
        profitslo.file <- paste0(periods[ii], "profits-", lowersuffixes[ii], ".csv")
    }

    allocationlo <- read.csv(allocationlo.file)
    yieldslo <- read.csv(yieldslo.file, header=F)
    profitslo <- read.csv(profitslo.file, header=F)

    productionlo <- colSums(allocationlo[, 3:8] * yieldslo, na.rm=T)
    profitlo <- colSums(allocationlo[, 3:8] * profitslo, na.rm=T)

    if (periods[ii] == "unadapted") {
        allocationhi.file <- paste0("constopt-currentprofits-", uppersuffixes[1], ".csv")
        yieldshi.file <- paste0("futureyields-", uppersuffixes[3], ".csv")
        profitshi.file <- paste0("futureprofits-", uppersuffixes[3], ".csv")
    } else {
        allocationhi.file <- paste0("constopt-", periods[ii], "profits-", uppersuffixes[ii], ".csv")
        yieldshi.file <- paste0(periods[ii], "yields-", uppersuffixes[ii], ".csv")
        profitshi.file <- paste0(periods[ii], "profits-", uppersuffixes[ii], ".csv")
    }

    allocationhi <- read.csv(allocationhi.file)
    yieldshi <- read.csv(yieldshi.file, header=F)
    profitshi <- read.csv(profitshi.file, header=F)

    productionhi <- colSums(allocationhi[, 3:8] * yieldshi, na.rm=T)
    profithi <- colSums(allocationhi[, 3:8] * profitshi, na.rm=T)

    df <- rbind(df, data.frame(period=periods[ii], crop=names(allocation)[3:8], productionlo, productionhi, profitlo, profithi))
}

library(ggplot2)

ggplot(df, aes(crop, (productionlo + productionhi) / 2, fill=period)) +
    geom_bar(stat="identity", position=position_dodge()) +
    geom_errorbar(aes(ymin=productionlo, ymax=productionhi), width=.4, position=position_dodge(.9)) +
    theme_bw() + xlab(NULL) + ylab("Production")

ggplot(data.frame(period=rep(df$period, 2), profit=c(df$profitlo, df$profithi), crop=rep(df$crop, 2), assump=rep(c('zero', 'limit'), each=nrow(df))), aes(factor(paste(period, assump), levels=c("current zero", "current limit", "unadapted zero", "unadapted limit", "future zero", "future limit")), profit, fill=crop)) +
    geom_bar(stat="identity") +
    theme_bw() + xlab(NULL) + ylab("Profit (USD)")


