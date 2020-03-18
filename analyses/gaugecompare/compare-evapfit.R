setwd("~/research/awash/analyses/gaugecompare")

library(dplyr)

params <- read.csv("evapfit-params.csv")
params$lognse <- NA
params$logkge <- NA

otherdf <- read.csv("evapdata.csv")

mylog <- function(xx) {
    yy <- log(xx)
    yy[!is.finite(yy)] <- NA
    yy
}

for (ii in 1:nrow(params)) {
    modeldf <- read.csv(paste0("evapfit-", params$iter[ii], ".csv"))
    df <- modeldf %>% left_join(otherdf)

    df2 <- df %>% group_by(gauge) %>% summarize(nse=1 - sum((flows_rfnr - observed)^2, na.rm=T) / sum((observed - mean(observed, na.rm=T))^2, na.rm=T),
                                                lognse=1 - sum((mylog(flows_rfnr) - mylog(observed))^2, na.rm=T) / sum((mylog(observed) - mean(mylog(observed), na.rm=T))^2, na.rm=T),
                                                kge=1 - sqrt((cor(flows_rfnr, observed, use="na.or.complete") - 1)^2 + (var(flows_rfnr, na.rm=T) / var(observed, na.rm=T) - 1)^2 + (mean(flows_rfnr, na.rm=T) / mean(observed, na.rm=T) - 1)^2),
                                                logkge=1 - sqrt((cor(mylog(flows_rfnr), mylog(observed), use="na.or.complete") - 1)^2 + (var(mylog(flows_rfnr), na.rm=T) / var(mylog(observed), na.rm=T) - 1)^2 + (mean(mylog(flows_rfnr), na.rm=T) / mean(mylog(observed), na.rm=T) - 1)^2))

    params$lognse[ii] <- median(df2$lognse, na.rm=T)
    params$logkge[ii] <- median(df2$logkge, na.rm=T)

    ## median(df2$nse, na.rm=T)
    ## median(df2$kge, na.rm=T)
    ## plot(density(df2$nse[df2$nse > -10 & df2$nse < 10], na.rm=T))
    ## plot(density(df2$kge[df2$kge > -10 & df2$kge < 10], na.rm=T))
    ## plot(density(df2$lognse[df2$lognse > -10 & df2$lognse < 10], na.rm=T))
    ## plot(density(df2$logkge[df2$logkge > -10 & df2$logkge < 10], na.rm=T))
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

##

setwd("~/research/water/awash/analyses/gaugecompare")
params <- read.csv("evapfit-results.csv")

library(ggplot2)

ggplot(params, aes(LOSSFACTOR_DIST, LOSSFACTOR_DISTTAS, colour=lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, CANAL_FACTOR, colour=lognse)) +
    geom_point() + theme_bw() + ylim(1, 1.005)

ggplot(params[params$CANAL_FACTOR < 1.01,], aes(LOSSFACTOR_DIST, LOSSFACTOR_DISTTAS, colour=lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DIST, lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(LOSSFACTOR_DISTTAS, logkge)) +
    geom_point() + theme_bw()

ggplot(params, aes(CANAL_FACTOR, lognse)) +
    geom_point() + theme_bw()

ggplot(params, aes(CANAL_FACTOR, logkge)) +
    geom_point() + theme_bw()

library(gg3D)

ggplot(params, aes(x=LOSSFACTOR_DIST, y=LOSSFACTOR_DISTTAS, z=CANAL_FACTOR, colour=lognse)) +
    axes_3D() +
    stat_3D() +
    theme_void()
