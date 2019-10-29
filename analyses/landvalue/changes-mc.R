setwd("~/research/awash/analyses/landvalue")

do.cornsoy.combo <- T

##   Baseline
## Check

##    OB L0 C0 L5 C5 L7 C7
## OB  1
## L0  y  1
## C0  y  y  1
## L5  y  y  X  1
## C5  y  y  y  y  1
## L7  y  y  X  z  X  1
## C7  y  y  y  z  y  y  1

##   L0 L5 L7
## L0 1
## C0 y
## L5 y  1
## C5 y  y
## L7 y  z  1
## C7 y  z  y

##   C0 C5 C7
## C0 1
## C5 y  1
## C7 y  y  1

actualcrops <- read.csv("../../data/counties/agriculture/knownareas.csv")
names(actualcrops) <- c(names(actualcrops)[1:3], "Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat")
actualcrops$observed <- sapply(1:nrow(actualcrops), function(ii) names(actualcrops)[4:9][which.max(actualcrops[ii, 4:9])])
actualcrops$mytotal <- actualcrops$Barley + actualcrops$Corn + actualcrops$Cotton +
    actualcrops$Rice + actualcrops$Soybean + actualcrops$Wheat
actualcrops$observed[actualcrops$mytotal == 0] <- NA

optims <- c("Local 2010", "Local 2050", "Local 2070", "Constr. 2010", "Constr. 2050", "Constr. 2070")
columns <- c("maxnow", "max2050", "max2070", "topnow", "top2050", "top2070")

biomodels  <- c("ac", "bc", "cc", "cn", "gf", "gs",
                "hd", "he", "hg", "in", "ip", "mc",
                "mg", "mi", "mp", "mr" , "no")

nummc <- 403

results <- array(NA, c(6, 7, nummc))
row.names(results) <- optims
colnames(results) <- c("Observed", optims)

for (mcmc in 1:nummc) {
    if (mcmc %in% c(155))
        next
    
    biomodel <- biomodels[mcmc %% length(biomodels) + 1]

    baseline <- read.csv(paste0("results-mc/maxbayesian-pfixmo-chirr-", mcmc, ".csv"))
    baseline$maxnow <- baseline$crop
    current <- read.csv(paste0("results-mc/constopt-currentprofits-pfixmo-chirr-", mcmc, ".csv"))
    current$topnow <- current$topcrop
    lo2050 <- read.csv(paste0("results-mc/max2050-pfixmo-notime-histco-", biomodel, "-", mcmc, ".csv"))
    lo2050$max2050 <- lo2050$crop
    in2050 <- read.csv(paste0("results-mc/constopt-all2050profits-pfixmo-notime-histco-", biomodel, "-", mcmc, ".csv"))
    in2050$top2050 <- in2050$topcrop
    lo2070 <- read.csv(paste0("results-mc/max2070-pfixmo-notime-histco-", biomodel, "-", mcmc, ".csv"))
    lo2070$max2070 <- lo2070$crop
    in2070 <- read.csv(paste0("results-mc/constopt-all2070profits-pfixmo-notime-histco-", biomodel, "-", mcmc, ".csv"))
    in2070$top2070 <- in2070$topcrop

library(dplyr)

df <- baseline %>% left_join(actualcrops, by="fips") %>% left_join(current, by="fips") %>% left_join(in2050, by="fips") %>% left_join(in2070, by="fips") %>% left_join(lo2050, by="fips") %>% left_join(lo2070, by="fips")

df <- subset(df, !is.na(observed))

if (do.cornsoy.combo) {
    df$observed[df$observed == "Corn"] <- "Soybean"
    df$maxnow[df$maxnow == "Corn"] <- "Soybean"
    df$topnow[df$topnow == "Corn"] <- "Soybean"
    df$max2050[df$max2050 == "Corn"] <- "Soybean"
    df$top2050[df$top2050 == "Corn"] <- "Soybean"
    df$max2070[df$max2070 == "Corn"] <- "Soybean"
    df$top2070[df$top2070 == "Corn"] <- "Soybean"
}

for (ii in 1:6)
    for (jj in 0:6) {
        if (jj > ii)
            next
        if (jj == 0)
            results[ii, 1, mcmc] <- sum((is.na(df[, columns[ii]]) & is.na(df$observed)) | df[, columns[ii]] == df$observed, na.rm=T) / nrow(df)
        else
            results[ii, jj+1, mcmc] <- sum((is.na(df[, columns[ii]]) & is.na(df[, columns[jj]])) | df[, columns[ii]] == df[, columns[jj]], na.rm=T) / nrow(df)
    }

}

results2 <- 1 - results
results3 <- apply(results2, c(1, 2), function(x) ifelse(all(is.na(x)), NA, paste0("(", paste(format(100 * quantile(x, c(.025, .975), na.rm=T), digits=1), collapse=" - "), ")")))

library(xtable)

print(xtable(results3[, 1:4]))

xtable(results3[4:6, c(1, 5:7)])
