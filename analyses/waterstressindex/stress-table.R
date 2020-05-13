setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)
source("vsenv-lib.R")

scenarios <- c('local', 'nores-nocanal', 'nores', 'withres')
scenario.names <- c("Local Runoff", "River network", "With Canals", "Canals and Reservoirs")

demanddf <- read.csv("../../data/counties/extraction/USGS-2010.csv")
save.demandsw <- demanddf$TO_SW * 1383 + .001
save.demand <- demanddf$TO_To * 1383 + .001

get.terms <- function(df, demand, order=T) {
    demand[demand == 0] <- 1

    if (order) {
        supersources <- split.fipsyears(df$supersource, max)
        minefps <- split.fipsyears(df$minefp, min)
        supersources.best <- split.fipsyears(df$supersource, min)
        minefps.best <- split.fipsyears(df$minefp, max)
        fips <- df$fips[1:3109]
    } else {
        supersources <- split.fipsyears.xorder(df$supersource, df$fips, max)
        minefps <- split.fipsyears.xorder(df$minefp, df$fips, min)
        supersources.best <- split.fipsyears.xorder(df$supersource, df$fips, min)
        minefps.best <- split.fipsyears.xorder(df$minefp, df$fips, max)
        fips <- supersources$fips
    }

    list(fips=fips, failfrac=pmin(supersources$median / demand, 1),
         failfrac.worst=pmin(supersources$worst / demand, 1),
         failfrac.best=pmin(supersources.best$worst / demand, 1),
         natflowa=minefps$median / 100,
         natflowa.worst=minefps$worst / 100,
         natflowa.best=minefps.best$worst / 100)
}

## forcor <- NULL

results <- data.frame()
bycounty <- data.frame()
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
            terms1 <- get.terms(df.all, save.demand, order=F)
            failfrac.excess <- terms1$failfrac
            natflowa.excess <- terms1$natflowa
            failfrac.excess.worst <- terms1$failfrac.worst
            natflowa.excess.worst <- terms1$natflowa.worst
            failfrac.excess.best <- terms1$failfrac.best
            natflowa.excess.best <- terms1$natflowa.best
        } else {
            terms0 <- get.terms(df.sw, save.demandsw)
            terms1 <- get.terms(df.all, save.demand)

            ## Calculate excess stress
            failfrac.excess <- pmax(0, (save.demand * terms1$failfrac - save.demandsw * terms0$failfrac) / save.demand)
            natflowa.excess <- terms1$natflowa + (1 - terms0$natflowa)
            failfrac.excess.worst <- pmax(0, (save.demand * terms1$failfrac.worst - save.demandsw * terms0$failfrac.worst) / save.demand)
            natflowa.excess.worst <- terms1$natflowa.worst + (1 - terms0$natflowa.worst)
            failfrac.excess.best <- pmax(0, (save.demand * terms1$failfrac.best - save.demandsw * terms0$failfrac.best) / save.demand)
            natflowa.excess.best <- terms1$natflowa.best + (1 - terms0$natflowa.best)
        }

        ## if (is.null(forcor))
        ##     forcor <- df[, 1:2]

        ## forcor[, paste0('supersource-', context, '-', scenario)] <- df$supersource
        ## forcor[, paste0('minefp-', context, '-', scenario)] <- df$minefp

        ## ff.median.mean <- mean(failfrac.excess)
        ## ff.median.po25 <- mean(failfrac.excess > .25)
        ## ff.median.po50 <- mean(failfrac.excess > .5)
        ## ff.median.po75 <- mean(failfrac.excess > .75)
        ## ff.median.qu25 <- quantile(failfrac.excess, .25)
        ## ff.median.qu50 <- quantile(failfrac.excess, .50)
        ## ff.median.qu75 <- quantile(failfrac.excess, .75)
        ## nf.median.mean <- mean(natflowa.excess)
        ## nf.median.pb37 <- mean(natflowa.excess < .375)
        ## nf.median.pb62 <- mean(natflowa.excess < .625)
        ## nf.median.pb87 <- mean(natflowa.excess < .875)

        ff.median.mean <- mean(failfrac.excess)
        ff.median.high <- mean(failfrac.excess > .5)
        nf.median.mean <- mean(natflowa.excess)
        nf.median.vlow <- mean(natflowa.excess < .5)
        ff.driest.mean <- mean(failfrac.excess.worst)
        ff.driest.high <- mean(failfrac.excess.worst > .5)
        nf.driest.mean <- mean(natflowa.excess.worst)
        nf.driest.vlow <- mean(natflowa.excess.worst < .5)

        row <- data.frame(scenario=scenario.names[scenarios == scenario], context, ff.median.mean, ff.median.high, nf.median.mean, nf.median.vlow, ff.driest.mean, ff.driest.high, nf.driest.mean, nf.driest.vlow)
        print(row)

        bycounty <- rbind(bycounty, data.frame(scenario=scenario.names[scenarios == scenario], context, fips=terms1$fips, failfrac.excess, natflowa.excess, failfrac.excess.worst, natflowa.excess.worst, failfrac.excess.best, natflowa.excess.best))

        results <- rbind(results, row)
    }
}

## Big table of county results

tbl.export <- bycounty %>% group_by(fips) %>% summarize(failfrac.local=round(100 * failfrac.excess[1]), failfrac.local.range=ifelse(round(100 * failfrac.excess.best[1]) == round(100 * failfrac.excess.worst[1]), "", paste(round(100 * failfrac.excess.best[1]), "-", round(100 * failfrac.excess.worst[1]))),
                                                          failfrac.local.worst=round(100 * failfrac.excess[2]), failfrac.local.worst.range=ifelse(round(100 * failfrac.excess.best[2]) == round(100 * failfrac.excess.worst[2]), "", paste(round(100 * failfrac.excess.best[2]), "-", round(100 * failfrac.excess.worst[2]))),
                                                          failfrac.network=round(100 * failfrac.excess[3]), failfrac.network.range=ifelse(round(100 * failfrac.excess.best[3]) == round(100 * failfrac.excess.worst[3]), "", paste(round(100 * failfrac.excess.best[3]), "-", round(100 * failfrac.excess.worst[3]))),
                                                          failfrac.network.worst=round(100 * failfrac.excess[4]), failfrac.network.worst.range=ifelse(round(100 * failfrac.excess.best[4]) == round(100 * failfrac.excess.worst[4]), "", paste(round(100 * failfrac.excess.best[4]), "-", round(100 * failfrac.excess.worst[4]))),
                                                          failfrac.canals=round(100 * failfrac.excess[5]), failfrac.canals.range=ifelse(round(100 * failfrac.excess.best[5]) == round(100 * failfrac.excess.worst[5]), "", paste(round(100 * failfrac.excess.best[5]), "-", round(100 * failfrac.excess.worst[5]))),
                                                          failfrac.canals.worst=round(100 * failfrac.excess[6]), failfrac.canals.worst.range=ifelse(round(100 * failfrac.excess.best[6]) == round(100 * failfrac.excess.worst[6]), "", paste(round(100 * failfrac.excess.best[6]), "-", round(100 * failfrac.excess.worst[6]))),
                                                          failfrac.reservoirs=round(100 * failfrac.excess[7]), failfrac.reservoirs.range=ifelse(round(100 * failfrac.excess.best[7]) == round(100 * failfrac.excess.worst[7]), "", paste(round(100 * failfrac.excess.best[7]), "-", round(100 * failfrac.excess.worst[7]))),
                                                          failfrac.reservoirs.worst=round(100 * failfrac.excess[8]), failfrac.reservoirs.worst.range=ifelse(round(100 * failfrac.excess.best[8]) == round(100 * failfrac.excess.worst[8]), "", paste(round(100 * failfrac.excess.best[8]), "-", round(100 * failfrac.excess.worst[8]))),

                                                          natflowa.local=round(100 * natflowa.excess[1]), natflowa.local.range=ifelse(round(100 * natflowa.excess.best[1]) == round(100 * natflowa.excess.worst[1]), "", paste(round(100 * natflowa.excess.best[1]), "-", round(100 * natflowa.excess.worst[1]))),
                                                          natflowa.local.worst=round(100 * natflowa.excess[2]), natflowa.local.worst.range=ifelse(round(100 * natflowa.excess.best[2]) == round(100 * natflowa.excess.worst[2]), "", paste(round(100 * natflowa.excess.best[2]), "-", round(100 * natflowa.excess.worst[2]))),
                                                          natflowa.network=round(100 * natflowa.excess[3]), natflowa.network.range=ifelse(round(100 * natflowa.excess.best[3]) == round(100 * natflowa.excess.worst[3]), "", paste(round(100 * natflowa.excess.best[3]), "-", round(100 * natflowa.excess.worst[3]))),
                                                          natflowa.network.worst=round(100 * natflowa.excess[4]), natflowa.network.worst.range=ifelse(round(100 * natflowa.excess.best[4]) == round(100 * natflowa.excess.worst[4]), "", paste(round(100 * natflowa.excess.best[4]), "-", round(100 * natflowa.excess.worst[4]))),
                                                          natflowa.canals=round(100 * natflowa.excess[5]), natflowa.canals.range=ifelse(round(100 * natflowa.excess.best[5]) == round(100 * natflowa.excess.worst[5]), "", paste(round(100 * natflowa.excess.best[5]), "-", round(100 * natflowa.excess.worst[5]))),
                                                          natflowa.canals.worst=round(100 * natflowa.excess[6]), natflowa.canals.worst.range=ifelse(round(100 * natflowa.excess.best[6]) == round(100 * natflowa.excess.worst[6]), "", paste(round(100 * natflowa.excess.best[6]), "-", round(100 * natflowa.excess.worst[6]))),
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
