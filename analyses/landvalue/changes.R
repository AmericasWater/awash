setwd("~/research/awash/analyses/landvalue")

##   Baseline
## Check

##   L0 C0 L5 C5 L7 C7
## L0 1
## C0 y  1
## L5 y  X  1
## C5 y  y  y  1
## L7 y  X  z  X  1
## C7 y  y  z  y  y  1

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


baseline <- read.csv("maxbayesian-pfixed-lybymc.csv")
baseline$maxnow <- baseline$crop
current <- read.csv("constopt-currentprofits-pfixed-lybymc.csv")
current$topnow <- current$topcrop
lo2050 <- read.csv("max2050-pfixed-notime-histco-lybymc.csv")
lo2050$max2050 <- lo2050$crop
in2050 <- read.csv("constopt-all2050profits-pfixed-notime-histco-lybymc.csv")
in2050$top2050 <- in2050$topcrop
lo2070 <- read.csv("max2070-pfixed-notime-histco-lybymc.csv")
lo2070$max2070 <- lo2070$crop
in2070 <- read.csv("constopt-all2070profits-pfixed-notime-histco-lybymc.csv")
in2070$top2070 <- in2070$topcrop

library(dplyr)

df <- baseline %>% left_join(current, by="fips") %>% left_join(in2050, by="fips") %>% left_join(in2070, by="fips") %>% left_join(lo2050, by="fips") %>% left_join(lo2070, by="fips")

optims <- c("Local Current", "Local 2050", "Local 2070", "Constr. Current", "Constr. 2050", "Constr. 2070")
columns <- c("maxnow", "max2050", "max2070", "topnow", "top2050", "top2070")

results <- matrix(NA, 6, 6)
row.names(results) <- optims
colnames(results) <- optims

for (ii in 1:6)
    for (jj in 1:6) {
        if (jj > ii)
            next
        results[ii, jj] <- sum((is.na(df[, columns[ii]]) & is.na(df[, columns[jj]])) | df[, columns[ii]] == df[, columns[jj]], na.rm=T) / nrow(df)
    }

library(xtable)

print(xtable((1 - results[, 1:3]) * 100, digits=1))

xtable((1 - results[4:6, 4:6]) * 100, digits=1)
