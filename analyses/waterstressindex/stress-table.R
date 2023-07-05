setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)

## abstract-results

df.nores <- read.csv("byfips-monthly-excess-nores.csv")
mean(df.nores$failurefrac.excess.worstmedian > 0, na.rm=T)
mean(df.nores$failurefrac.excess.worst > 0, na.rm=T)
mean(df.nores$failurefrac.excess.median > 0, na.rm=T)

df.local <- read.csv("byfips-monthly-excess-local.csv")
mean(df.local$failurefrac.excess.worstmedian > 0, na.rm=T)
mean(df.local$failurefrac.excess.worst > 0, na.rm=T)
mean(df.local$failurefrac.excess.median > 0, na.rm=T)

df.wires <- read.csv("byfips-monthly-excess-withres.csv")
mean(df.wires$failurefrac.excess.worstmedian > 0, na.rm=T)
mean(df.wires$failurefrac.excess.worst > 0, na.rm=T)
mean(df.wires$failurefrac.excess.median > 0, na.rm=T)

1 - mean(df.wires$failurefrac.excess.worstmedian > 0, na.rm=T) / mean(df.nores$failurefrac.excess.worstmedian > 0, na.rm=T)

mean(df.nores$failfrac.median.nores != 0, na.rm=T)

## highlights-results

all(df.local$fips == df.wires$fips)

mean(df.wires$failurefrac.excess.median[!is.na(df.local$failurefrac.excess.median) & df.local$failurefrac.excess.median > 0] == 0, na.rm=T)
mean(df.local$failurefrac.excess.median[!is.na(df.wires$failurefrac.excess.median) & df.wires$failurefrac.excess.median > 0] == 0, na.rm=T)

mean(df.wires$failurefrac.excess.worstmedian > 0, na.rm=T)

df.nores <- read.csv("byfips-monthly-excess-nores.csv")

mean(df.wires$failurefrac.excess.median[!is.na(df.nores$failurefrac.excess.median) & df.nores$failurefrac.excess.median > 0] == 0, na.rm=T)
mean(df.wires$failurefrac.excess.worstmedian[!is.na(df.nores$failurefrac.excess.worstmedian) & df.nores$failurefrac.excess.worstmedian > 0] == 0, na.rm=T)

mean(df.local$failurefrac.excess.worst > 0, na.rm=T)
mean(df.wires$failurefrac.excess.worst > 0, na.rm=T)
mean(df.wires$failurefrac.excess.worstmedian > 0, na.rm=T)


preptbl <- function(byfips, suffix) {
    df <- read.csv(byfips)
    tbl <- data.frame(fips=df$fips)
    tbl[, paste0('reliability.', suffix)] <- round(100 * df$reliability)
    tbl[, paste0('failfrac.median.', suffix)] <- round(100 * df$failurefrac.excess.median)
    ## This is the range of worst months in each year
    tbl[, paste0('failfrac.range.', suffix)] <- paste(round(100 * df$failurefrac.excess.worstbest), "-", round(100 * df$failurefrac.excess.worst))
    tbl[, paste0('natflowa.median.', suffix)] <- round(100 * df$natflowav.excess)
    tbl[, paste0('natflowa.range.', suffix)] <- paste(round(100 * df$natflowav.excess.worstbest), "-", round(100 * df$natflowav.excess.worst))
    tbl
}

tbl.local <- preptbl("byfips-monthly-excess-local.csv", 'local')
## tbl.nocan <- preptbl("byfips-monthly-excess-nores-nocanal.csv", 'nocan')
tbl.canal <- preptbl("byfips-monthly-excess-nores.csv", 'canal')
tbl.wires <- preptbl("byfips-monthly-excess-withres.csv", 'wires')

tbl <- tbl.local %>% left_join(tbl.canal) %>% left_join(tbl.wires) # left_join(tbl.nocan) %>%

sum(tbl$reliability.local == 100, na.rm=T) / sum(!is.na(tbl$reliability.local))
## sum(tbl$reliability.nocan == 100, na.rm=T) / sum(!is.na(tbl$reliability.nocan))
sum(tbl$reliability.canal == 100, na.rm=T) / sum(!is.na(tbl$reliability.canal))
sum(tbl$reliability.wires == 100, na.rm=T) / sum(!is.na(tbl$reliability.wires))

tbl.out <- tbl[, -grep("reliability", names(tbl))]

write.csv(tbl.out, "summary.csv", row.names=F)

## Summary statistics for maps

tbl.local <- read.csv("fipstime-monthly-excess-local.csv")
tbl.canal <- read.csv("fipstime-monthly-excess-nores.csv")
tbl.wires <- read.csv("fipstime-monthly-excess-withres.csv")
tbl.local$suffix <- 'local'
tbl.canal$suffix <- 'canal'
tbl.wires$suffix <- 'wires'

tbl <- rbind(tbl.local, tbl.canal, tbl.wires)

tbl.maps <- tbl %>% group_by(fips, suffix) %>% summarize(reliability.model=sum(supersource.sw == 0, na.rm=T) / sum(!is.na(supersource.sw)), reliability.excess=sum(failurefrac.excess == 0, na.rm=T) / sum(!is.na(failurefrac.excess)), failurefrac.excess.median=median(failurefrac.excess, na.rm=T), failurefrac.excess.worst=max(failurefrac.excess, na.rm=T), natflowav.excess.median=median(natflowav.excess, na.rm=T), natflowav.excess.worst=min(natflowav.excess, na.rm=T))

tbl$yearoct <- floor(tbl$timestep / 12) + 1949
tbl.drymonth <- tbl %>% group_by(suffix, yearoct, fips) %>% summarize(failurefrac.excess.worst=max(failurefrac.excess), natflowav.excess.worst=min(natflowav.excess))

tbl.maps.drymonth <- tbl.drymonth %>% group_by(fips, suffix) %>% summarize(failurefrac.excess.worstworst=max(failurefrac.excess.worst, na.rm=T), natflowav.excess.worstworst=min(natflowav.excess.worst, na.rm=T), failurefrac.excess.worstmedian=median(failurefrac.excess.worst, na.rm=T), natflowav.excess.worstmedian=median(natflowav.excess.worst, na.rm=T))

suffix.label <- list('local'="Local Runoff", 'canal'="River Network", 'wires'="Including Reservoirs")

tbl.out <- data.frame()
for (measure in c('failurefrac.excess', 'natflowav.excess')) {
    for (suffix in c('local', 'canal', 'wires')) {
        median.metric <- mean(tbl.maps[tbl.maps$suffix == suffix, paste0(measure, '.median'), drop=T], na.rm=T)
        worst.metric <- mean(pmin(1, pmax(0, tbl.maps[tbl.maps$suffix == suffix, paste0(measure, '.worst'), drop=T])), na.rm=T)

        median.metric.drymonth <- mean(tbl.maps.drymonth[tbl.maps.drymonth$suffix == suffix, paste0(measure, '.worstmedian'), drop=T], na.rm=T)
        ## worst.metric.drymonth <- mean(pmin(1, pmax(0, tbl.maps.drymonth[tbl.maps.drymonth$suffix == suffix, paste0(measure, '.worstworst'), drop=T])), na.rm=T)

        if (measure == 'failurefrac.excess') {
            median.portion <- mean(tbl.maps[tbl.maps$suffix == suffix, paste0(measure, '.median'), drop=T] > 0, na.rm=T)
            worst.portion <- mean(tbl.maps[tbl.maps$suffix == suffix, paste0(measure, '.worst'), drop=T] > 0, na.rm=T)
            median.portion.drymonth <- mean(tbl.maps.drymonth[tbl.maps.drymonth$suffix == suffix, paste0(measure, '.worstmedian'), drop=T] > 0, na.rm=T)
            ## worst.portion.drymonth <- mean(tbl.maps.drymonth[tbl.maps.drymonth$suffix == suffix, paste0(measure, '.worstworst'), drop=T] > 0, na.rm=T)
        } else {
            median.portion <- mean(tbl.maps[tbl.maps$suffix == suffix, paste0(measure, '.median'), drop=T] < .97, na.rm=T)
            worst.portion <- mean(tbl.maps[tbl.maps$suffix == suffix, paste0(measure, '.worst'), drop=T] < .97, na.rm=T)
            median.portion.drymonth <- mean(tbl.maps.drymonth[tbl.maps.drymonth$suffix == suffix, paste0(measure, '.worstmedian'), drop=T] < .97, na.rm=T)
            ## worst.portion.drymonth <- mean(tbl.maps.drymonth[tbl.maps.drymonth$suffix == suffix, paste0(measure, '.worstworst'), drop=T] < .97, na.rm=T)
        }

        tbl.out <- rbind(tbl.out, data.frame(Assumption=suffix.label[[suffix]],
                                             `Median Annual`=paste0(round(100 * median.metric, 1), "%"),
                                             `Median Dry Month`=paste0(round(100 * median.metric.drymonth, 1), "%"),
                                             `Driest Month`=paste0(round(100 * worst.metric, 1), "%"),
                                             `Median Annual`=paste0(round(100 * median.portion, 1), "%"),
                                             `Median Dry Month`=paste0(round(100 * median.portion.drymonth, 1), "%"),
                                             `Driest Month`=paste0(round(100 * worst.portion, 1), "%")))
    }
}

library(xtable)

print(xtable(tbl.out), include.rownames=F)

## Report by state <-- NOTE: Not using this, using the code in barcharts.R

preptbl <- function(byfips, suffix) {
    df <- read.csv(byfips)
    df$statefips <- floor(df$fips / 1000)
    df2 <- df %>% group_by(statefips) %>% summarize(failfrac.median=round(100 * median(failurefrac.excess.median, na.rm=T)),
                                             failfrac.range=paste(round(100 * median(failurefrac.excess.worstbest, na.rm=T)), "-", round(100 * median(failurefrac.excess.worst, na.rm=T))),
                                             natflowa.median=round(100 * median(natflowav.excess, na.rm=T)),
                                             natflowa.range=paste(round(100 * median(natflowav.excess.worstbest, na.rm=T)), "-", round(100 * median(natflowav.excess.worst, na.rm=T))))
    names(df2)[-1] <- paste0(names(df2)[-1], ".", suffix)
    df2
}

tbl.local <- preptbl("byfips-monthly-excess-local.csv", 'local')
## tbl.nocan <- preptbl("byfips-monthly-excess-nores-nocanal.csv", 'nocan')
tbl.canal <- preptbl("byfips-monthly-excess-nores.csv", 'canal')
tbl.wires <- preptbl("byfips-monthly-excess-withres.csv", 'wires')

tbl <- tbl.local %>% left_join(tbl.canal) %>% left_join(tbl.wires) # left_join(tbl.nocan) %>%

statefips <- read.csv("statefips.csv")

tbl2 <- tbl %>% left_join(statefips, by=c('statefips'='fips'))

tbl3 <- tbl2[!is.na(tbl2$State), c('State', 'failfrac.range.local', 'natflowa.range.local', 'failfrac.range.wires', 'natflowa.range.wires')] # 'failfrac.range.nocan', 'natflowa.range.nocan',

library(xtable)

print(xtable(tbl3), include.rownames=F)

## Plot over time
setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)
library(ggplot2)

df <- read.csv("demands.csv")
df <- subset(df, scale == "monthly")

tbl.local <- read.csv("fipstime-monthly-excess-local.csv")
tbl.nocan <- read.csv("fipstime-monthly-excess-nores-nocanal.csv")
tbl.canal <- read.csv("fipstime-monthly-excess-nores.csv")
tbl.wires <- read.csv("fipstime-monthly-excess-withres.csv")
tbl.local$suffix <- 'local'
tbl.nocan$suffix <- 'nocan'
tbl.canal$suffix <- 'canal'
tbl.wires$suffix <- 'wires'

tbl <- rbind(tbl.local, tbl.nocan, tbl.canal, tbl.wires)
tbl2 <- tbl %>% left_join(df)
tbl3 <- tbl2 %>% group_by(timestep, suffix) %>% summarize(supersource.sw=sum(supersource.sw, na.rm=T), supersource.excess=sum(failurefrac.excess * alldemand, na.rm=T))
range(tbl3$timestep[tbl3$suffix == 'wires' & tbl3$supersource.sw > 0])

tbl4 <- subset(tbl3, timestep >= 25 & timestep <= 720)

ggplot(tbl4, aes(timestep, supersource.sw, colour=suffix)) +
    geom_line() + scale_x_continuous(expand=c(0, 0))

ggplot(tbl4, aes(timestep, supersource.excess, colour=suffix)) +
    geom_line() + scale_x_continuous(expand=c(0, 0))

ggplot(tbl4, aes(timestep, supersource.sw + supersource.excess, colour=suffix)) +
    geom_line() + scale_x_continuous(expand=c(0, 0))


## TODO from scratch

scenarios <- c('local', 'nores', 'withres') # 'nores-nocanal',
scenario.names <- c("Local Runoff", "River network", "Canals and Reservoirs") # "With Canals",

demanddf <- read.csv("../../data/counties/extraction/USGS-2010.csv")
save.demandsw <- demanddf$TO_SW * 1383 + .001
save.demand <- demanddf$TO_To * 1383 + .001

## Big table of county results

tbl.export <- bycounty %>% group_by(fips) %>% summarize(failfrac.local=round(100 * failfrac.excess[1]), failfrac.local.range=ifelse(round(100 * failfrac.excess.best[1]) == round(100 * failfrac.excess.worst[1]), "", paste(round(100 * failfrac.excess.best[1]), "-", round(100 * failfrac.excess.worst[1]))),
                                                        failfrac.local.worst=round(100 * failfrac.excess[2]), failfrac.local.worst.range=ifelse(round(100 * failfrac.excess.best[2]) == round(100 * failfrac.excess.worst[2]), "", paste(round(100 * failfrac.excess.best[2]), "-", round(100 * failfrac.excess.worst[2]))),
                                                        failfrac.network=round(100 * failfrac.excess[3]), failfrac.network.range=ifelse(round(100 * failfrac.excess.best[3]) == round(100 * failfrac.excess.worst[3]), "", paste(round(100 * failfrac.excess.best[3]), "-", round(100 * failfrac.excess.worst[3]))),
                                                        failfrac.network.worst=round(100 * failfrac.excess[4]), failfrac.network.worst.range=ifelse(round(100 * failfrac.excess.best[4]) == round(100 * failfrac.excess.worst[4]), "", paste(round(100 * failfrac.excess.best[4]), "-", round(100 * failfrac.excess.worst[4]))),
                                                        #failfrac.canals=round(100 * failfrac.excess[5]), failfrac.canals.range=ifelse(round(100 * failfrac.excess.best[5]) == round(100 * failfrac.excess.worst[5]), "", paste(round(100 * failfrac.excess.best[5]), "-", round(100 * failfrac.excess.worst[5]))),
                                                        #failfrac.canals.worst=round(100 * failfrac.excess[6]), failfrac.canals.worst.range=ifelse(round(100 * failfrac.excess.best[6]) == round(100 * failfrac.excess.worst[6]), "", paste(round(100 * failfrac.excess.best[6]), "-", round(100 * failfrac.excess.worst[6]))),
                                                          failfrac.reservoirs=round(100 * failfrac.excess[7]), failfrac.reservoirs.range=ifelse(round(100 * failfrac.excess.best[7]) == round(100 * failfrac.excess.worst[7]), "", paste(round(100 * failfrac.excess.best[7]), "-", round(100 * failfrac.excess.worst[7]))),
                                                          failfrac.reservoirs.worst=round(100 * failfrac.excess[8]), failfrac.reservoirs.worst.range=ifelse(round(100 * failfrac.excess.best[8]) == round(100 * failfrac.excess.worst[8]), "", paste(round(100 * failfrac.excess.best[8]), "-", round(100 * failfrac.excess.worst[8]))),

                                                          natflowa.local=round(100 * natflowa.excess[1]), natflowa.local.range=ifelse(round(100 * natflowa.excess.best[1]) == round(100 * natflowa.excess.worst[1]), "", paste(round(100 * natflowa.excess.best[1]), "-", round(100 * natflowa.excess.worst[1]))),
                                                          natflowa.local.worst=round(100 * natflowa.excess[2]), natflowa.local.worst.range=ifelse(round(100 * natflowa.excess.best[2]) == round(100 * natflowa.excess.worst[2]), "", paste(round(100 * natflowa.excess.best[2]), "-", round(100 * natflowa.excess.worst[2]))),
                                                          natflowa.network=round(100 * natflowa.excess[3]), natflowa.network.range=ifelse(round(100 * natflowa.excess.best[3]) == round(100 * natflowa.excess.worst[3]), "", paste(round(100 * natflowa.excess.best[3]), "-", round(100 * natflowa.excess.worst[3]))),
                                                          natflowa.network.worst=round(100 * natflowa.excess[4]), natflowa.network.worst.range=ifelse(round(100 * natflowa.excess.best[4]) == round(100 * natflowa.excess.worst[4]), "", paste(round(100 * natflowa.excess.best[4]), "-", round(100 * natflowa.excess.worst[4]))),
                                                        #natflowa.canals=round(100 * natflowa.excess[5]), natflowa.canals.range=ifelse(round(100 * natflowa.excess.best[5]) == round(100 * natflowa.excess.worst[5]), "", paste(round(100 * natflowa.excess.best[5]), "-", round(100 * natflowa.excess.worst[5]))),
                                                        #natflowa.canals.worst=round(100 * natflowa.excess[6]), natflowa.canals.worst.range=ifelse(round(100 * natflowa.excess.best[6]) == round(100 * natflowa.excess.worst[6]), "", paste(round(100 * natflowa.excess.best[6]), "-", round(100 * natflowa.excess.worst[6]))),
                                                          natflowa.reservoirs=round(100 * natflowa.excess[7]), natflowa.reservoirs.range=ifelse(round(100 * natflowa.excess.best[7]) == round(100 * natflowa.excess.worst[7]), "", paste(round(100 * natflowa.excess.best[7]), "-", round(100 * natflowa.excess.worst[7]))),
                                                        natflowa.reservoirs.worst=round(100 * natflowa.excess[8]), natflowa.reservoirs.worst.range=ifelse(round(100 * natflowa.excess.best[8]) == round(100 * natflowa.excess.worst[8]), "", paste(round(100 * natflowa.excess.best[8]), "-", round(100 * natflowa.excess.worst[8]))))
tbl.export2 <- demanddf[, c('STATE', 'COUNTY', 'FIPS')] %>% left_join(tbl.export, by=c('FIPS'='fips'))

write.csv(tbl.export2, "bycounty.csv", row.names=F)

## Bars with averages across US

library(reshape2)
results2 <- melt(results, id.vars=c('scenario', 'context'))
results2$metric <- "Failure fraction"
results2$metric[grep("nf", results2$variable)] <- "Natural flow available"
results2$report <- "Median year"
results2$report[grep("driest", results2$variable)] <- "Driest year"
results2$var2 <- gsub("driest.", "", gsub("median.", "", gsub("nf.", "", gsub("ff.", "", results2$variable))))
results2$var3 <- "Mean"
results2$var3[results2$var2 != "mean"] <- "Extremes"

ggplot(results2, aes(var3, value, colour=scenario, fill=scenario)) +
    facet_grid(context ~ metric) +
    geom_bar(data=subset(results2, report == 'Median year'), stat='identity', position='dodge') +
    geom_errorbar(data=subset(results2, report == 'Driest year'), aes(ymin=0, ymax=value), position=position_dodge(width=1))

results3 <- results2
results3$value[results2$metric == 'Natural flow available' & results2$var2 == 'mean'] <- 1 - results2$value[results2$metric == 'Natural flow available' & results2$var2 == 'mean']
results3$metric2 <- results3$metric
results3$metric2[results3$metric == 'Natural flow available'] <- "Natural flow taken"
results3$metric2 <- factor(results3$metric2, c("Failure fraction", "Natural flow taken"))
results3$context2 <- "Annual flow"
results3$context2[results3$context == 'worst'] <- "Worst month"
results3$var4 <- "Mean over counties"
results3$var4[results3$var3 == 'Extremes'] <- "Counties under stress"
results3$var4 <- factor(results3$var4, c("Mean over counties", "Counties under stress"))
results3$scenario <- factor(results3$scenario, scenario.names)

ggplot(results3, aes(metric2, value, colour=scenario, fill=scenario, group=scenario)) +
    facet_grid(var4 ~ context2) + #coord_flip() +
    geom_bar(data=subset(results3, report == 'Median year'), stat='identity', width=.8, position=position_dodge(width=.9)) +
    geom_errorbar(data=subset(results3, report == 'Driest year'), aes(ymin=0, ymax=value), width=.8, position=position_dodge(width=.9)) +
    scale_y_continuous(labels=scales::percent) + xlab(NULL) + ylab(NULL) +
    scale_fill_discrete(name="Scenario") + scale_colour_discrete(name="Scenario")

results.tbl <- results
results.tbl$context <- as.character(results.tbl$context)
results.tbl$context[results.tbl$context == "total"] <- "Annual flow"
results.tbl$context[results.tbl$context == "worst"] <- "Worst month"

names(results.tbl)[1:2] <- c("Scenario", "Flows")
results.tbl[,-1:-2] <- sapply(results.tbl[,-1:-2] * 100, function(x) paste0(round(x, 1), "%"))

library(xtable)
print(xtable(results.tbl[, c(1, 2, 3, 7, 4, 8)]), include.rownames=F)
print(xtable(results.tbl[, c(1, 2, 5, 9, 6, 10)]), include.rownames=F)

## Create distributions across time

get.terms <- function(df, demand, demandsw) {
    demand[demand == 0] <- 1
    demandsw[demandsw == 0] <- 1

    df2 <- df %>% left_join(data.frame(fips=demanddf$FIPS, demand, demandsw))
    df3 <- df2 %>% group_by(time) %>% summarize(failfrac=sum(supersource) / sum(demand), natflowa=sum((1 - minefp / 100) * demand) / sum(demand),
                                                failfrac.excess=sum(pmax(0, supersource - supersource.sw)) / sum(demand),
                                                natflowa.excess=sum((1 - minefp / 100) * demand + supersource.sw) / sum(demand),
                                                failfrac.excess.count=mean(pmax(0, supersource - supersource.sw) / demand > .25),
                                                natflowa.excess.count=mean(((1 - minefp / 100) * demand + supersource.sw) / demand < .5))

    df3
}

results <- data.frame()
for (scenario in scenarios) {
    for (context in c('total', 'worst')) {
        if (context == 'total') {
            df.all <- read.csv(paste0("results/stress-annual-alldemand-", scenario, ".csv"))
            df.sw <- read.csv(paste0("results/stress-annual-", scenario, ".csv"))
        } else {
            df.all <- read.csv(paste0("results/stress-annual-", context, "-alldemand-", scenario, ".csv"))
            df.sw <- read.csv(paste0("results/stress-annual-", context, "-", scenario, ".csv"))
        }

        if (scenario == 'local') {
            df.both <- df.all
            df.both$supersource.sw <- 0
            df.both$minefp.sw <- 100

            terms <- get.terms(df.both, save.demand, 0)
        } else {
            df.sw$minefp <- df.sw$minefp - 3 # Turn into "just before failure"
            df.sw$minefp[df.sw$minefp < 0] <- 0
            df.all$minefp <- df.all$minefp - 3 # Turn into "just before failure"
            df.all$minefp[df.all$minefp < 0] <- 0

            df.both <- df.all %>% left_join(df.sw, by=c('fips', 'time'), suffix=c('', '.sw'))

            terms <- get.terms(df.both, save.demand, save.demandsw)
        }

        row <- data.frame(scenario=scenario.names[scenarios == scenario], context,
                          variable=rep(c('failfrac.excess', 'natflowa.excess', 'failfrac.excess.count', 'natflowa.excess.count'), each=nrow(terms)),
                          value=c(terms$failfrac.excess, terms$natflowa.excess, terms$failfrac.excess.count, terms$natflowa.excess.count))
        results <- rbind(results, row)
    }
}

results$metric <- "Failure fraction"
results$metric[grep("natflowa", results$variable)] <- "Natural flow available"

results2 <- results
## results2$value[results2$metric == 'Natural flow available'] <- 1 - results2$value[results2$metric == 'Natural flow available']
## results2$metric2 <- results2$metric
## results2$metric2[results2$metric == 'Natural flow available'] <- "Natural flow taken"
## results2$metric2 <- factor(results2$metric2, c("Failure fraction", "Natural flow taken"))
results2$context2 <- "Annual flow"
results2$context2[results2$context == 'worst'] <- "Worst month"
results2$varkind <- "Sum over counties"
results2$varkind[grep("count", results$variable)] <- "Counties under stress"
results2$varkind <- factor(results2$varkind, c("Sum over counties", "Counties under stress"))
results2$scenario <- factor(results2$scenario, scenario.names)

ggplot(results2, aes(metric, value, colour=scenario, fill=scenario, group=scenario)) +
    facet_grid(varkind ~ context2) +
    geom_violin(width=.8, position=position_dodge(width=.9)) +
    scale_y_continuous(labels=scales::percent) + xlab(NULL) + ylab(NULL) +
    scale_fill_discrete(name="Scenario") + scale_colour_discrete(name="Scenario")

results3 <- results2 %>% group_by(scenario, context, variable, metric, context2, varkind) %>% summarize(q0=min(value, na.rm=T), q25=quantile(value, .25, na.rm=T), q50=quantile(value, .5, na.rm=T), q75=quantile(value, .75, na.rm=T), q100=max(value, na.rm=T), mu=mean(value, na.rm=T))

ggplot(results3, aes(metric, mu, colour=scenario, fill=scenario, group=scenario)) +
    facet_grid(varkind ~ context2) +
    geom_point(position=position_dodge(width=.9)) +
    geom_errorbar(aes(ymin=q50, ymax=q50), width=.8, position=position_dodge(width=.9)) +
    geom_errorbar(aes(ymin=q25, ymax=q75), width=.4, position=position_dodge(width=.9)) +
    geom_linerange(aes(ymin=q0, ymax=q100), position=position_dodge(width=.9)) +
    scale_y_continuous(labels=scales::percent) + xlab(NULL) + ylab(NULL) +
    scale_fill_discrete(name="Scenario") + scale_colour_discrete(name="Scenario")

## Look at how much reservoirs contribute

setwd("~/research/water/awash/analyses/waterstressindex")

df.sw0 <- read.csv(paste0("results/stress-annual-nores.csv"))
df.sw1 <- read.csv(paste0("results/stress-annual-withres.csv"))
df.all0 <- read.csv(paste0("results/stress-annual-alldemand-nores.csv"))
df.all1 <- read.csv(paste0("results/stress-annual-alldemand-withres.csv"))

library(dplyr)

df0 <- df.all0 %>% left_join(df.sw0, by=c('fips', 'time'), suffix=c('.all', '.sw'))
df1 <- df.all1 %>% left_join(df.sw1, by=c('fips', 'time'), suffix=c('.all', '.sw'))
df <- df0 %>% left_join(df1, by=c('fips', 'time'), suffix=c('.nores', '.withres'))
sum(df$supersource.all.nores - df$supersource.sw.nores)
sum(df$supersource.all.withres - df$supersource.sw.withres)

1 - sum(df$supersource.all.withres - df$supersource.sw.withres) / sum(df$supersource.all.nores - df$supersource.sw.nores)
