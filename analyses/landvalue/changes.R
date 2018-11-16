setwd("~/research/awash/analyses/landvalue")

do.cornsoy.combo <- F

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

actualcrops <- read.csv("actualcrops.csv")
actualcrops$observed <- as.character(actualcrops$maxcrop)
actualcrops$observed[actualcrops$observed == "BARLEY"] <- "Barley"
actualcrops$observed[actualcrops$observed == "CORN"] <- "Corn"
actualcrops$observed[actualcrops$observed == "COTTON"] <- "Cotton"
actualcrops$observed[actualcrops$observed == "RICE"] <- "Rice"
actualcrops$observed[actualcrops$observed == "SOYBEANS"] <- "Soybean"
actualcrops$observed[actualcrops$observed == "WHEAT"] <- "Wheat"

baseline <- read.csv("results/maxbayesian-pfixmo-chirr.csv")
baseline$maxnow <- baseline$crop
current <- read.csv("results/constopt-currentprofits-pfixmo-chirr.csv")
current$topnow <- current$topcrop
lo2050 <- read.csv("results/max2050-pfixmo-notime-histco.csv")
lo2050$max2050 <- lo2050$crop
in2050 <- read.csv("results/constopt-all2050profits-pfixmo-notime-histco.csv")
in2050$top2050 <- in2050$topcrop
lo2070 <- read.csv("results/max2070-pfixmo-notime-histco.csv")
lo2070$max2070 <- lo2070$crop
in2070 <- read.csv("results/constopt-all2070profits-pfixmo-notime-histco.csv")
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

optims <- c("Local 2010", "Local 2050", "Local 2070", "Constr. 2010", "Constr. 2050", "Constr. 2070")
columns <- c("maxnow", "max2050", "max2070", "topnow", "top2050", "top2070")

results <- matrix(NA, 6, 7)
row.names(results) <- optims
colnames(results) <- c("Observed", optims)

for (ii in 1:6)
    for (jj in 0:6) {
        if (jj > ii)
            next
        if (jj == 0)
            results[ii, 1] <- sum((is.na(df[, columns[ii]]) & is.na(df$observed)) | df[, columns[ii]] == df$observed, na.rm=T) / nrow(df)
        else
            results[ii, jj+1] <- sum((is.na(df[, columns[ii]]) & is.na(df[, columns[jj]])) | df[, columns[ii]] == df[, columns[jj]], na.rm=T) / nrow(df)
    }

library(xtable)

print(xtable((1 - results[, 1:4]) * 100, digits=1))

xtable((1 - results[4:6, c(1, 5:7)]) * 100, digits=1)
