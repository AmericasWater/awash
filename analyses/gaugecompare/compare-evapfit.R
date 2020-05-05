setwd("~/research/water/awash/analyses/gaugecompare")

library(dplyr)

params <- read.csv("evapfit-params.csv")
params$lognse <- NA
params$logkge <- NA
params$logrmse <- NA
params$nse <- NA
params$kge <- NA
params$rmse <- NA
params$lognse.yearly <- NA
params$logkge.yearly <- NA
params$logrmse.yearly <- NA
params$nse.yearly <- NA
params$kge.yearly <- NA
params$rmse.yearly <- NA

otherdf <- read.csv("evapdata.csv")
otherdf$year <- floor((otherdf$time - 1) / 12) + 1

otherdf.yearly <- otherdf %>% group_by(gauge, year) %>% summarize(observed=sum(observed))

mylog <- function(xx) {
    yy <- log(xx)
    yy[!is.finite(yy)] <- NA
    yy
}

for (ii in 1:nrow(params)) {
    modeldf <- read.csv(paste0("evapfit-", params$iter[ii], ".csv"))
    df <- modeldf %>% left_join(otherdf)

    ## NOTE: Remove `filter` to reproduce existing results
    df2 <- df %>% filter(observed > 1e3 / 12 & flows_rfnr > 1e-3) %>% group_by(gauge) %>% summarize(nse=1 - sum((flows_rfnr - observed)^2, na.rm=T) / sum((observed - mean(observed, na.rm=T))^2, na.rm=T),
                                                lognse=1 - sum((mylog(flows_rfnr) - mylog(observed))^2, na.rm=T) / sum((mylog(observed) - mean(mylog(observed), na.rm=T))^2, na.rm=T),
                                                kge=1 - sqrt((cor(flows_rfnr, observed, use="na.or.complete") - 1)^2 + (var(flows_rfnr, na.rm=T) / var(observed, na.rm=T) - 1)^2 + (mean(flows_rfnr, na.rm=T) / mean(observed, na.rm=T) - 1)^2),
                                                logkge=1 - sqrt((cor(mylog(flows_rfnr), mylog(observed), use="na.or.complete") - 1)^2 + (var(mylog(flows_rfnr), na.rm=T) / var(mylog(observed), na.rm=T) - 1)^2 + (mean(mylog(flows_rfnr), na.rm=T) / mean(mylog(observed), na.rm=T) - 1)^2),
                                                rmse=sqrt(mean((flows_rfnr - observed)^2, na.rm=T)),
                                                logrmse=sqrt(mean((mylog(flows_rfnr) - mylog(observed))^2, na.rm=T)))

    params$lognse[ii] <- median(df2$lognse, na.rm=T)
    params$logkge[ii] <- median(df2$logkge, na.rm=T)
    params$logrmse[ii] <- median(df2$logrmse, na.rm=T)
    params$nse[ii] <- median(df2$nse, na.rm=T)
    params$kge[ii] <- median(df2$kge, na.rm=T)
    params$rmse[ii] <- median(df2$rmse, na.rm=T)

    modeldf$year <- floor((modeldf$time - 1) / 12) + 1
    modeldf.yearly <- modeldf %>% group_by(gauge, year) %>% summarize(flows_rfnr=sum(flows_rfnr))
    df.yearly <- modeldf.yearly %>% left_join(otherdf.yearly)

    df2.yearly <- df.yearly %>% filter(observed > 1e3 & flows_rfnr > 1e-3) %>% group_by(gauge) %>% summarize(nse=1 - sum((flows_rfnr - observed)^2, na.rm=T) / sum((observed - mean(observed, na.rm=T))^2, na.rm=T),
                                                lognse=1 - sum((mylog(flows_rfnr) - mylog(observed))^2, na.rm=T) / sum((mylog(observed) - mean(mylog(observed), na.rm=T))^2, na.rm=T),
                                                kge=1 - sqrt((cor(flows_rfnr, observed, use="na.or.complete") - 1)^2 + (var(flows_rfnr, na.rm=T) / var(observed, na.rm=T) - 1)^2 + (mean(flows_rfnr, na.rm=T) / mean(observed, na.rm=T) - 1)^2),
                                                logkge=1 - sqrt((cor(mylog(flows_rfnr), mylog(observed), use="na.or.complete") - 1)^2 + (var(mylog(flows_rfnr), na.rm=T) / var(mylog(observed), na.rm=T) - 1)^2 + (mean(mylog(flows_rfnr), na.rm=T) / mean(mylog(observed), na.rm=T) - 1)^2),
                                                rmse=sqrt(mean((flows_rfnr - observed)^2, na.rm=T)),
                                                logrmse=sqrt(mean((mylog(flows_rfnr) - mylog(observed))^2, na.rm=T)))

    params$lognse.yearly[ii] <- median(df2.yearly$lognse, na.rm=T)
    params$logkge.yearly[ii] <- median(df2.yearly$logkge, na.rm=T)
    params$logrmse.yearly[ii] <- median(df2.yearly$logrmse, na.rm=T)
    params$nse.yearly[ii] <- median(df2.yearly$nse, na.rm=T)
    params$kge.yearly[ii] <- median(df2.yearly$kge, na.rm=T)
    params$rmse.yearly[ii] <- median(df2.yearly$rmse, na.rm=T)

    print(params[ii,])
}

## Do a Newton method

params2 <- params
params2$DOWNSTREAM_FACTOR2 <- params2$DOWNSTREAM_FACTOR^2
params2$LOSSFACTOR_DIST2 <- params2$LOSSFACTOR_DIST^2
params2$LOSSFACTOR_DISTTAS2 <- params2$LOSSFACTOR_DISTTAS^2
params2$CANAL_FACTOR2 <- params2$CANAL_FACTOR^2

mod <- lm(lognse ~ DOWNSTREAM_FACTOR + DOWNSTREAM_FACTOR2 + LOSSFACTOR_DIST + LOSSFACTOR_DIST2 + LOSSFACTOR_DISTTAS + LOSSFACTOR_DISTTAS2 + CANAL_FACTOR + CANAL_FACTOR2, data=params2)
summary(mod)

DOWNSTREAM_FACTOR <- ifelse(mod$coeff[3] < 0, -mod$coeff[2] / (2 * mod$coeff[3]), NA)
LOSSFACTOR_DIST <- ifelse(mod$coeff[5] < 0, -mod$coeff[4] / (2 * mod$coeff[5]), NA)
LOSSFACTOR_DISTTAS <- ifelse(mod$coeff[7] < 0, -mod$coeff[6] / (2 * mod$coeff[7]), NA)
CANAL_FACTOR <- ifelse(mod$coeff[9] < 0, -mod$coeff[8] / (2 * mod$coeff[9]), NA)

c(DOWNSTREAM_FACTOR, LOSSFACTOR_DIST, LOSSFACTOR_DISTTAS, CANAL_FACTOR)


mod <- lm(logkge ~ DOWNSTREAM_FACTOR + DOWNSTREAM_FACTOR2 + LOSSFACTOR_DIST + LOSSFACTOR_DIST2 + LOSSFACTOR_DISTTAS + LOSSFACTOR_DISTTAS2 + CANAL_FACTOR + CANAL_FACTOR2, data=params2)
summary(mod)

DOWNSTREAM_FACTOR <- ifelse(mod$coeff[3] < 0, -mod$coeff[2] / (2 * mod$coeff[3]), NA)
LOSSFACTOR_DIST <- ifelse(mod$coeff[5] < 0, -mod$coeff[4] / (2 * mod$coeff[5]), NA)
LOSSFACTOR_DISTTAS <- ifelse(mod$coeff[7] < 0, -mod$coeff[6] / (2 * mod$coeff[7]), NA)
CANAL_FACTOR <- ifelse(mod$coeff[9] < 0, -mod$coeff[8] / (2 * mod$coeff[9]), NA)

c(DOWNSTREAM_FACTOR, LOSSFACTOR_DIST, LOSSFACTOR_DISTTAS, CANAL_FACTOR)

params[which.max(params$lognse),]

params[which.max(params$logkge),]

write.csv(params, "evapfit-results.csv", row.names=F)


setwd("~/research/water/awash/analyses/gaugecompare")
params <- read.csv("evapfit-results.csv")

params$chosen <- NA
params$chosen[params$iter == 'base'] <- 'baseline'
params$chosen[params$iter == 'base-lim'] <- 'lim-baseline'
params$chosen[which.min(params$logrmse + !is.na(params$chosen))] <- 'monthly'
params$chosen[which.min(params$logrmse.yearly + !is.na(params$chosen))] <- 'yearly'

load("../../data/counties/waternet/waternet.RData")
meandist <- mean(network$dist, na.rm=T)

params$avgloss <- params$LOSSFACTOR_DIST * meandist + params$LOSSFACTOR_DISTTAS * meandist * 10

library(ggplot2)

ggplot(params, aes(LOSSFACTOR_DIST, LOSSFACTOR_DISTTAS, colour=lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, CANAL_FACTOR, colour=lognse)) +
    geom_point() + theme_bw() + ylim(1, 1.005)

ggplot(params[params$CANAL_FACTOR < 1.01,], aes(LOSSFACTOR_DIST, LOSSFACTOR_DISTTAS, colour=lognse)) +
    geom_point() + theme_bw()

## LOOK AT THIS ONE?
ggplot(params, aes(LOSSFACTOR_DIST, logrmse, colour=chosen)) +
    geom_point() + geom_point(data=subset(params, is.na(LOSSFACTOR_DIST)), aes(x=0)) + theme_bw()
ggplot(params, aes(LOSSFACTOR_DISTTAS, rmse, colour=chosen)) +
    geom_point() + geom_point(data=subset(params, is.na(LOSSFACTOR_DISTTAS)), aes(x=0)) + theme_bw()
ggplot(params, aes(CANAL_FACTOR, rmse, colour=chosen)) +
    geom_point() + theme_bw()
ggplot(params, aes(DOWNSTREAM_FACTOR, rmse, colour=chosen)) +
    geom_point() + theme_bw()

ggplot(params, aes(avgloss, lognse, colour=chosen)) + # also works for lognse.yearly
    geom_point() + theme_bw()

## params[!is.na(params$chosen) & params$chosen == 'monthly',] ### 2020-04-29. Test with compare with do_monthly = F
## params[which.min(params$rmse[c(-nrow(params), -nrow(params)+1)]),]
params[which.max(params$lognse[c(-nrow(params), -nrow(params)+1)]),]

ggplot(params, aes(LOSSFACTOR_DIST, logrmse.yearly, colour=chosen)) +
    geom_point() + geom_point(data=subset(params, !is.na(chosen)), aes(x=0)) +
    theme_bw()

ggplot(params, aes(LOSSFACTOR_DIST, lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DIST, logkge)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, logrmse, colour=chosen)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, logrmse.yearly, colour=chosen)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, logkge)) +
    geom_point() + theme_bw()

ggplot(params, aes(CANAL_FACTOR, logrmse, colour=chosen)) +
    geom_point() + theme_bw()

ggplot(params, aes(CANAL_FACTOR, logrmse.yearly, colour=chosen)) +
    geom_point() + theme_bw()

ggplot(params, aes(CANAL_FACTOR, lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(CANAL_FACTOR, logkge)) +
    geom_point() + theme_bw()

ggplot(params, aes(DOWNSTREAM_FACTOR, logrmse, colour=chosen)) +
    geom_point() + theme_bw()

ggplot(params, aes(DOWNSTREAM_FACTOR, logrmse.yearly, colour=chosen)) +
    geom_point() + theme_bw()

ggplot(params, aes(DOWNSTREAM_FACTOR, lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(DOWNSTREAM_FACTOR, logkge)) +
    geom_point() + theme_bw()

params[which.min(params$logrmse),]
params[which.min(params$logrmse.yearly),]
params[which.min(params$rmse),]
params[which.min(params$rmse.yearly),]


library(gg3D)

ggplot(params, aes(x=LOSSFACTOR_DIST, y=LOSSFACTOR_DISTTAS, z=CANAL_FACTOR, colour=lognse)) +
    axes_3D() +
    stat_3D() +
    theme_void()
