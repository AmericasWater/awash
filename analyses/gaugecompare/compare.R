setwd("~/research/water/awash/analyses/gaugecompare")

library(ggplot2)

do.only.hcdn <- F
startmonth <- 673
do.monthly <- T
do.other <- F #"allyear" #"10year"

source("../../../network4/discharges.R", chdir=T)
if (do.monthly) {
    df <- read.csv("optimizes-monthly.csv")
} else {
    if (do.other == "allyear") {
        df <- read.csv("optimizes-allyear.csv")
        startmonth <- 1
    } else if (do.other == "10year") {
        df <- read.csv("optimizes-10year.csv")
        startmonth <- startmonth - 60
    } else
        df <- read.csv("optimizes.csv")
}
df$observed <- NA

if (do.only.hcdn) {
    info <- read.csv("../../../scaling/conterm_basinid.txt")
    allids <- unique(as.character(df$gauge))
    collection <- sapply(strsplit(allids, "\\."), function(x) x[1])
    colid <- sapply(strsplit(allids, "\\."), function(x) x[2])
    include <- collection == "usgs"
    for (ii in which(include)) {
        infoii <- which(info$STAID == as.numeric(colid[ii]))
        if (length(infoii) != 1)
            include[ii] <- F
        else if (info$HCDN.2009[infoii] != "yes")
            include[ii] <- F
    }

    df <- df[df$gauge %in% allids[include],]
}

numdone <- 0
for (gauge in unique(df$gauge)) {
    numdone <- numdone + 1
    print(numdone / 22559)
    dfrows <- which(df$gauge == gauge)
    parts <- strsplit(as.character(gauge), "\\.")[[1]]
    if (parts[1] %in% c("rivdis", "usgs")) {
        values <- get.flow.data(parts[1], parts[2])
        if (class(values) == "logical")
            next
        starttime <- (1950 - 1960) * 12 - 3 + startmonth - 1
        maxtime <- max(values$time)
        if (do.monthly) {
            if (starttime >= maxtime)
                next
            for (time in 1:60) {
                df$observed[dfrows[time]] <- values$flow[values$time == starttime]
                starttime <- starttime + 1
                if (starttime > maxtime)
                    break
            }
        } else {
            if (starttime >= maxtime - 11)
                next
            for (year in 1:length(dfrows)) {
                df$observed[dfrows[year]] <- mean(values$flow[values$time >= starttime & values$time < starttime + 12])
                starttime <- starttime + 12
                if (starttime > maxtime)
                    break
            }
        }
    }
}

df$observed <- df$observed * 60 * 60 * 24 * 365 / 1000 # 1000 m^3
if (do.monthly)
    df$observed <- df$observed / 12
if (do.only.hcdn) {
    quantile(df$flows_nw / df$observed, probs=c(0, .1, .25, .5, .75, .9, 1), na.rm=T)

    ggplot(df, aes(flows_nw / observed)) +
        geom_density() +
        scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
        theme_minimal() + xlab("Ratio of simulated to observed")
}

df2 <- df[, c('gauge', 'time', 'observed')]
write.csv(df2, "evapdata.csv", row.names=F)

## Check lineup
## allccf = rep(0, 25)
## for (gauge in unique(df$gauge)) {
##     xx = tryCatch({
##         ccf(df$flows_nw[df$gauge == gauge], df$observed[df$gauge == gauge], 12, na.action=na.pass, plot=F, type='correlation')$acf[,,1]
##     }, error=function(e) {
##         rep(0, 25)
##     })
##     xx[is.na(xx)] <- 0
##     allccf <- allccf + xx
## }

## plot(-12:12, allccf)

df$modified <- df$flows_nw - df$flows_nrnr > mean(df$flows_nw - df$flows_nrnr) # more than average mod
df$nonzero <- df$observed > 0 & df$flows_nw > 0 & df$flows_nrnr > 1e-3 & df$flows_rfnr > 1e-3 & df$flows_rfwr > 1e-3
if (do.monthly) {
    df$largish <- df$observed > 1e3 / 12
} else {
    df$largish <- df$observed > 1e3
}

ava <- df$nonzero & df$modified
aval <- df$nonzero & df$modified & df$largish

## summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_nw[ava]), x=log(df$observed[ava]))))
## summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_nrnr[ava]), x=log(df$observed[ava]))))
## summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_rfnr[ava]), x=log(df$observed[ava]))))
## summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_rfwr[ava]), x=log(df$observed[ava]))))

## quantile(df$flows_nw[aval] / df$observed[aval], na.rm=T)
## quantile(df$flows_nrnr[aval] / df$observed[aval], na.rm=T)
## quantile(df$flows_rfnr[aval] / df$observed[aval], na.rm=T)
## quantile(df$flows_rfwr[aval] / df$observed[aval], na.rm=T)

## ggplot(subset(df, aval), aes(flows_nw / observed)) +
##     geom_density() + scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6)) +
##     theme_minimal() + xlab("Ratio of simulated to observed")

mm.nw <- format(median(df$flows_nw[aval] / df$observed[aval], na.rm=T), digits=3)
mm.nrnr <- format(median(df$flows_nrnr[aval] / df$observed[aval], na.rm=T), digits=3)
mm.rfnr <- format(median(df$flows_rfnr[aval] / df$observed[aval], na.rm=T), digits=3)
mm.rfwr <- format(median(df$flows_rfwr[aval] / df$observed[aval], na.rm=T), digits=3)

df$flowsize.label <- "Large Flows"
df$flowsize.label[!df$largish] <- "Small Flows"
df$modified.label <- "Modified Flows"
df$modified.label[!df$modified] <- "Unmodified Flows"
if (do.other == "allyear") {
    df$period.label <- "2000 - 2010"
    df$period.label[df$time <= 50] <- "before 2000"
} else
    df$period.label <- NA

if (do.monthly) {
    ggplot(subset(df, nonzero & largish)) +
        facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
        geom_density(aes(flows_nw / observed, colour='a')) +
        geom_density(aes(flows_nrnr / observed, colour='b')) +
        geom_density(aes(flows_rfnr / observed, colour='c')) +
        geom_density(aes(flows_rfwr / observed, colour='d')) +
        scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
        scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", mm.nw, ")"), paste0(" + Withdrawals (Medium: ", mm.nrnr, ")"), paste0("  + Returns (Medium: ", mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", mm.rfwr, ")"))) +
        theme_minimal() + xlab("Ratio of simulated to observed") +
        theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + ylim(0, 1.2)
    ggsave("compare-monthly.pdf", width=7, height=4)
} else {
    if (do.other %in% c("allyear", "10year")) {
        ggplot(subset(df, nonzero & largish)) +
            facet_grid(period.label ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
            geom_density(aes(flows_nw / observed, colour='a')) +
            geom_density(aes(flows_nrnr / observed, colour='b')) +
            geom_density(aes(flows_rfnr / observed, colour='c')) +
            geom_density(aes(flows_rfwr / observed, colour='d')) +
            scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
            scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", mm.nw, ")"), paste0(" + Withdrawals (Medium: ", mm.nrnr, ")"), paste0("  + Returns (Medium: ", mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", mm.rfwr, ")"))) +
            theme_minimal() + xlab("Ratio of simulated to observed") +
            theme(legend.justification=c(.5,1), legend.position=c(.5,1))
        ggsave(paste0("compare-", do.other, ".pdf"), width=7, height=4)
    } else {
        ggplot(subset(df, nonzero & largish)) +
            facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
            geom_density(aes(flows_nw / observed, colour='a')) +
            geom_density(aes(flows_nrnr / observed, colour='b')) +
            geom_density(aes(flows_rfnr / observed, colour='c')) +
            geom_density(aes(flows_rfwr / observed, colour='d')) +
            scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
            scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", mm.nw, ")"), paste0(" + Withdrawals (Medium: ", mm.nrnr, ")"), paste0("  + Returns (Medium: ", mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", mm.rfwr, ")"))) +
            theme_minimal() + xlab("Ratio of simulated to observed") +
            theme(legend.justification=c(.5,1), legend.position=c(.5,1))
        ggsave("compare.pdf", width=7, height=4)
    }
}

ggplot(subset(df, ava), aes(observed, flows_nw)) +
    geom_point() +
    geom_smooth(method='lm') +
    geom_abline(slope=1, col='green') +
    scale_x_log10() + scale_y_log10() +
    theme_minimal() + xlab("Observed flows (1000 m^3 / year)") +
    ylab("Simulated flows without withdrawals")

ggplot(subset(df, ava), aes(observed, flows_nrnr)) +
    geom_point() +
    geom_smooth(method='lm') +
    geom_abline(slope=1, col='green') +
    scale_x_log10() + scale_y_log10() +
    theme_minimal() + xlab("Observed flows (1000 m^3 / year)") +
    ylab("Simulated flows with withdrawals")

ggplot(subset(df, ava), aes(observed, flows_rfnr)) +
    geom_point() +
    geom_smooth(method='lm') +
    geom_abline(slope=1, col='green') +
    scale_x_log10() + scale_y_log10() +
    theme_minimal() + xlab("Observed flows (1000 m^3 / year)") +
    ylab("Simulated flows with withdrawals + return flows")

ggplot(subset(df, ava), aes(observed, flows_rfwr)) +
    geom_point() +
    geom_smooth(method='lm') +
    geom_abline(slope=1, col='green') +
    scale_x_log10() + scale_y_log10() +
    theme_minimal() + xlab("Observed flows (1000 m^3 / year)") +
    ylab("Simulated flows with withdrawals + return flows + reservoirs")

## NSE and KGE metrics

library(dplyr)
df2 <- df %>% group_by(gauge) %>% summarize(nse_rfnr=1 - sum((flows_rfnr - observed)^2, na.rm=T) / sum((observed - mean(observed, na.rm=T))^2, na.rm=T),
                                            nse_nrnr=1 - sum((flows_nrnr - observed)^2, na.rm=T) / sum((observed - mean(observed, na.rm=T))^2, na.rm=T),
                                            nse_rfwr=1 - sum((flows_rfwr - observed)^2, na.rm=T) / sum((observed - mean(observed, na.rm=T))^2, na.rm=T),
                                            nse_nw=1 - sum((flows_nw - observed)^2, na.rm=T) / sum((observed - mean(observed, na.rm=T))^2, na.rm=T),
                                            kge_rfnr=1 - sqrt((cor(flows_rfnr, observed, use="na.or.complete") - 1)^2 + (var(flows_rfnr, na.rm=T) / var(observed, na.rm=T) - 1)^2 + (mean(flows_rfnr, na.rm=T) / mean(observed, na.rm=T) - 1)^2),
                                            kge_nrnr=1 - sqrt((cor(flows_nrnr, observed, use="na.or.complete") - 1)^2 + (var(flows_nrnr, na.rm=T) / var(observed, na.rm=T) - 1)^2 + (mean(flows_nrnr, na.rm=T) / mean(observed, na.rm=T) - 1)^2),
                                            kge_rfwr=1 - sqrt((cor(flows_rfwr, observed, use="na.or.complete") - 1)^2 + (var(flows_rfwr, na.rm=T) / var(observed, na.rm=T) - 1)^2 + (mean(flows_rfwr, na.rm=T) / mean(observed, na.rm=T) - 1)^2),
                                            kge_nw=1 - sqrt((cor(flows_nw, observed, use="na.or.complete") - 1)^2 + (var(flows_nw, na.rm=T) / var(observed, na.rm=T) - 1)^2 + (mean(flows_nw, na.rm=T) / mean(observed, na.rm=T) - 1)^2),
                                            bias_rfwr=1 - mean(flows_rfwr, na.rm=T) / mean(observed, na.rm=T),
                                            modified=median(modified, na.rm=T), nonzero=median(nonzero, na.rm=T), largish=median(largish, na.rm=T))

df2$flowsize.label <- "Large Flows"
df2$flowsize.label[!df2$largish] <- "Small Flows"
df2$modified.label <- "Modified Flows"
df2$modified.label[!df2$modified] <- "Unmodified Flows"

gr.ava <- df2$nonzero & df2$modified
gr.aval <- df2$nonzero & df2$modified & df2$largish

nse.mm.nw <- format(median(df2$nse_nw[gr.aval], na.rm=T), digits=3)
nse.mm.nrnr <- format(median(df2$nse_nrnr[gr.aval], na.rm=T), digits=3)
nse.mm.rfnr <- format(median(df2$nse_rfnr[gr.aval], na.rm=T), digits=3)
nse.mm.rfwr <- format(median(df2$nse_rfwr[gr.aval], na.rm=T), digits=3)

if (do.monthly) {
    ggplot(subset(df2, nonzero & largish)) +
        facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
        geom_density(aes(nse_nw, colour='a')) +
        geom_density(aes(nse_nrnr, colour='b')) +
        geom_density(aes(nse_rfnr, colour='c')) +
        geom_density(aes(nse_rfwr, colour='d')) +
        scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", nse.mm.nw, ")"), paste0(" + Withdrawals (Medium: ", nse.mm.nrnr, ")"), paste0("  + Returns (Medium: ", nse.mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", nse.mm.rfwr, ")"))) +
        theme_minimal() + xlab("NSE") +
        theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + xlim(-1, 1)
    ggsave("nse-monthly.pdf", width=7, height=4)
} else {
    if (do.other %in% c("allyear", "10year")) {
        ggplot(subset(df2, nonzero & largish)) +
            facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
            geom_density(aes(nse_nw, colour='a')) +
            geom_density(aes(nse_nrnr, colour='b')) +
            geom_density(aes(nse_rfnr, colour='c')) +
            geom_density(aes(nse_rfwr, colour='d')) +
            scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", nse.mm.nw, ")"), paste0(" + Withdrawals (Medium: ", nse.mm.nrnr, ")"), paste0("  + Returns (Medium: ", nse.mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", nse.mm.rfwr, ")"))) +
            theme_minimal() + xlab("NSE") +
            theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + xlim(-1, 1)
        ggsave(paste0("nse-", do.other, ".pdf"), width=7, height=4)
    } else {
        ggplot(subset(df2, nonzero & largish)) +
            facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
            geom_density(aes(nse_nw, colour='a')) +
            geom_density(aes(nse_nrnr, colour='b')) +
            geom_density(aes(nse_rfnr, colour='c')) +
            geom_density(aes(nse_rfwr, colour='d')) +
            scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", nse.mm.nw, ")"), paste0(" + Withdrawals (Medium: ", nse.mm.nrnr, ")"), paste0("  + Returns (Medium: ", nse.mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", nse.mm.rfwr, ")"))) +
            theme_minimal() + xlab("NSE") +
            theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + xlim(-1, 1)
        ggsave("nse.pdf", width=7, height=4)
    }
}

kge.mm.nw <- format(median(df2$kge_nw[gr.aval], na.rm=T), digits=3)
kge.mm.nrnr <- format(median(df2$kge_nrnr[gr.aval], na.rm=T), digits=3)
kge.mm.rfnr <- format(median(df2$kge_rfnr[gr.aval], na.rm=T), digits=3)
kge.mm.rfwr <- format(median(df2$kge_rfwr[gr.aval], na.rm=T), digits=3)

if (do.monthly) {
    ggplot(subset(df2, nonzero & largish)) +
        facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
        geom_density(aes(kge_nw, colour='a')) +
        geom_density(aes(kge_nrnr, colour='b')) +
        geom_density(aes(kge_rfnr, colour='c')) +
        geom_density(aes(kge_rfwr, colour='d')) +
        scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", kge.mm.nw, ")"), paste0(" + Withdrawals (Medium: ", kge.mm.nrnr, ")"), paste0("  + Returns (Medium: ", kge.mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", kge.mm.rfwr, ")"))) +
        theme_minimal() + xlab("KGE") +
        theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + xlim(-1, 1)
    ggsave("kge-monthly.pdf", width=7, height=4)
} else {
    if (do.other %in% c("allyear", "10year")) {
        ggplot(subset(df2, nonzero & largish)) +
            facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
            geom_density(aes(kge_nw, colour='a')) +
            geom_density(aes(kge_nrnr, colour='b')) +
            geom_density(aes(kge_rfnr, colour='c')) +
            geom_density(aes(kge_rfwr, colour='d')) +
            scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", kge.mm.nw, ")"), paste0(" + Withdrawals (Medium: ", kge.mm.nrnr, ")"), paste0("  + Returns (Medium: ", kge.mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", kge.mm.rfwr, ")"))) +
            theme_minimal() + xlab("KGE") +
            theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + xlim(-1, 1)
        ggsave(paste0("kge-", do.other, ".pdf"), width=7, height=4)
    } else {
        ggplot(subset(df2, nonzero & largish)) +
            facet_grid(. ~ modified.label) + #facet_grid(modified.label ~ flowsize.label) +
            geom_density(aes(kge_nw, colour='a')) +
            geom_density(aes(kge_nrnr, colour='b')) +
            geom_density(aes(kge_rfnr, colour='c')) +
            geom_density(aes(kge_rfwr, colour='d')) +
            scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (Medium: ", kge.mm.nw, ")"), paste0(" + Withdrawals (Medium: ", kge.mm.nrnr, ")"), paste0("  + Returns (Medium: ", kge.mm.rfnr, ")"), paste0("  + Reservoirs (Medium: ", kge.mm.rfwr, ")"))) +
            theme_minimal() + xlab("KGE") +
            theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + xlim(-1, 1)
        ggsave("kge.pdf", width=7, height=4)
    }
}

## Table of metrics
metrics <- data.frame(metric=rep(c("Bias", "NSE", "KGE"), each=2), limit=c('\\pm 20', '\\pm 50', rep(c('\\ge 0.6', '\\ge 0.2'), 2)),
                      value=c(mean(df2$bias_rfwr >= .8 & df2$bias_rfwr <= 1.2, na.rm=T),
                              mean(df2$bias_rfwr >= .5 & df2$bias_rfwr <= 1.5, na.rm=T),
                              mean(df2$nse_rfwr >= .6, na.rm=T), mean(df2$nse_rfwr >= .2, na.rm=T),
                              mean(df2$kge_rfwr >= .6, na.rm=T), mean(df2$kge_rfwr >= .2, na.rm=T)))
library(xtable)
print(xtable(metrics), include.rownames=F, sanitize.text.function=function(x) x)

