setwd("~/research/water/awash/analyses/gaugecompare")

library(ggplot2)

do.only.hcdn <- F

source("../../../network4/discharges.R", chdir=T)
df <- read.csv("optimizes.csv")
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
    parts <- strsplit(gauge, "\\.")[[1]]
    if (parts[1] %in% c("rivdis", "usgs")) {
        values <- get.flow.data(parts[1], parts[2])
        if (class(values) == "logical")
            next
        starttime <- (1950 - 1960) * 12 - 2
        maxtime <- max(values$time)
        for (year in 1:61) {
            df$observed[dfrows[year]] <- mean(values$flow[values$time >= starttime & values$time < starttime + 12])
            starttime <- starttime + 12
            if (starttime > maxtime)
                break
        }
    }
}

df$observed <- df$observed * 60 * 60 * 24 * 365 / 1000
if (do.only.hcdn) {
    quantile(df$flows_nw / df$observed, probs=c(0, .1, .25, .5, .75, .9, 1), na.rm=T)

    ggplot(df, aes(flows_nw / observed)) +
        geom_density() +
        scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
        theme_minimal() + xlab("Ratio of simulated to observed")
}

df$modified <- df$flows_nw - df$flows_nrnr > mean(df$flows_nw - df$flows_nrnr)

ava0 <- df$observed > 0 & df$flows_nw > 0 & df$flows_nrnr > 1e-3 & df$flows_rfnr > 1e-3 & df$flows_rfwr > 1e-3
ava <- df$observed > 0 & df$flows_nw > 0 & df$flows_nrnr > 1e-3 & df$flows_rfnr > 1e-3 & df$flows_rfwr > 1e-3 & df$modified

summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_nw[ava]), x=log(df$observed[ava]))))
summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_nrnr[ava]), x=log(df$observed[ava]))))
summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_rfnr[ava]), x=log(df$observed[ava]))))
summary(lm(y ~ 0 + x, data.frame(y=log(df$flows_rfwr[ava]), x=log(df$observed[ava]))))

quantile(df$flows_nw[ava] / df$observed[ava], na.rm=T)
quantile(df$flows_nrnr[ava] / df$observed[ava], na.rm=T)
quantile(df$flows_rfnr[ava] / df$observed[ava], na.rm=T)
quantile(df$flows_rfwr[ava] / df$observed[ava], na.rm=T)

quantile(df$flows_nw[ava] - df$observed[ava], na.rm=T)
quantile(df$flows_nrnr[ava] - df$observed[ava], na.rm=T)
quantile(df$flows_rfnr[ava] - df$observed[ava], na.rm=T)
quantile(df$flows_rfwr[ava] - df$observed[ava], na.rm=T)

ggplot(subset(df, ava), aes(flows_nw / observed)) +
    geom_density() + scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6)) +
    theme_minimal() + xlab("Ratio of simulated to observed")

mm.nw <- format(median(df$flows_nw[ava] / df$observed[ava], na.rm=T), digits=3)
mm.nrnr <- format(median(df$flows_nrnr[ava] / df$observed[ava], na.rm=T), digits=3)
mm.rfnr <- format(median(df$flows_rfnr[ava] / df$observed[ava], na.rm=T), digits=3)
mm.rfwr <- format(median(df$flows_rfwr[ava] / df$observed[ava], na.rm=T), digits=3)

df$flowsize.label <- "Large Flows"
df$flowsize.label[!ava0] <- "Small Flows"
df$modified.label <- "Modified Flows"
df$modified.label[!df$modified] <- "Unmodified Flows"

ggplot(subset(df, ava0)) +
    facet_wrap(. ~ modified.label) + #facet_grid(modified.label ~ modified) +
    geom_density(aes(flows_nw / observed, colour='a')) +
    geom_density(aes(flows_nrnr / observed, colour='b')) +
    geom_density(aes(flows_rfnr / observed, colour='c')) +
    geom_density(aes(flows_rfwr / observed, colour='d')) +
    scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
    scale_colour_discrete(name="Simulation Assumption", breaks=c('a', 'b', 'c', 'd'), labels=c(paste0("Natural flows (MM: ", mm.nw, ")"), paste0("Withdrawals only (MM: ", mm.nrnr, ")"), paste0("Withdrawals & Returns (MM: ", mm.rfnr, ")"), paste0("Withdrawals, Returns & Reservoirs (MM: ", mm.rfwr, ")"))) +
    theme_minimal() + xlab("Ratio of simulated to observed") +
    theme(legend.justification=c(.5,1), legend.position=c(.5,1)) + ylim(0, 2.8)
ggsave("compare.pdf", width=7, height=4)


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

