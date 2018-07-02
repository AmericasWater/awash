setwd("~/research/water/awash6/analyses/gaugecompare")

source("../../../network4/discharges.R", chdir=T)
df <- read.csv("optimizes.csv")
df$observed <- NA

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
write.csv(df, "optimizes.csv", row.names=F)

df$modified <- df$flows_nw - df$flows_nrnr > mean(df$flows_nw - df$flows_nrnr)

ava <- df$observed > 0 & df$flows_nw > 0 & df$flows_nrnr > 1e-3 & df$flows_rfnr > 1e-3 & df$flows_rfwr > 1e-3 & df$modified

library(ggplot2)

ggplot(subset(df, ava), aes(flows_nw / observed)) +
    geom_density() + scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6)) +
    theme_minimal() + xlab("Ratio of simulated to observed")

ggplot(subset(df, ava)) +
    geom_density(aes(flows_nw / observed, colour='a')) +
    geom_density(aes(flows_nrnr / observed, colour='b')) +
    geom_density(aes(flows_rfnr / observed, colour='c')) +
    geom_density(aes(flows_rfwr / observed, colour='d')) +
    scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
    scale_colour_discrete(name="Simulation\nAssumption", breaks=c('a', 'b', 'c', 'd'), labels=c("Natural flows", "Withdrawals only", "Withdrawals & Returns", "Withdrawals, Returns, & Reservoirs")) +
    theme_minimal() + xlab("Ratio of simulated to observed")

ggplot(subset(df, ava)) +
    geom_density(aes(flows_nw / observed, weight=observed, colour='a')) +
    geom_density(aes(flows_nrnr / observed, weight=observed, colour='b')) +
    geom_density(aes(flows_rfnr / observed, weight=observed, colour='c')) +
    geom_density(aes(flows_rfwr / observed, weight=observed, colour='d')) +
    scale_x_log10(breaks=c(1e-3, 1e-2, .1, 1, 10, 1e2, 1e3, 1e4, 1e5, 1e6), limits=c(1e-1, 1e1)) +
    scale_colour_discrete(name="Simulation\nAssumption", breaks=c('a', 'b', 'c', 'd'), labels=c("Natural flows", "Withdrawals only", "Withdrawals & Returns", "Withdrawals, Returns, & Reservoirs")) +
    theme_minimal() + xlab("Ratio of simulated to observed")

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

