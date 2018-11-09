setwd("~/research/awash/analyses/landvalue")

library(dplyr)
library(reshape2)
library(xtable)

## Construct a table of area changed and value produced, vs assumptions

baseline <- read.csv("../../data/counties/agriculture/knownareas.csv")
names(baseline) <- c(names(baseline)[1:3], "Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat")
baseline$mytotal <- baseline$Barley + baseline$Corn + baseline$Cotton +
    baseline$Rice + baseline$Soybean + baseline$Wheat
baseline$maxcrop <- sapply(1:nrow(baseline), function(ii) names(baseline)[4:9][which.max(baseline[ii, 4:9])])
baseline$maxarea <- sapply(1:nrow(baseline), function(ii) baseline[ii, baseline$maxcrop[ii]])

profits <- read.csv("actualprofit.csv")

periods <- list('maxbayesian'=2010, 'max2050'=2050, 'max2070'=2070,
                'constopt-currentprofits'=2010, 'constopt-all2050profits'=2050,
                'constopt-all2070profits'=2070)

## Where are the changes?
source("~/projects/research-common/R/ggmap.R")

opt <- read.csv("results/maxbayesian-pfixmo-chirr.csv")
opt <- opt %>% left_join(baseline)
opt$darea <- opt$mytotal - sapply(1:nrow(opt), function(ii) opt[ii, as.character(opt$crop[ii])])

gg.usmap(opt$darea, opt$fips)

opt$dmaxarea <- sapply(1:nrow(opt), function(ii) ifelse(opt$crop[ii] == opt$maxcrop[ii], 0, opt$maxarea[ii]))

gg.usmap(opt$dmaxarea, opt$fips)

## Local optimum
basevalue <- sum(baseline$Barley * profits$barl + baseline$Corn * profits$corn +
                  baseline$Cotton * profits$cott + baseline$Rice * profits$rice +
                  baseline$Soybean * profits$soyb + baseline$Wheat * profits$whea)
df <- data.frame(period=2010, assumptions='Baseline', nooptvalue=NA, totalvalue=basevalue, deltavalue=0, deltaarea=0, deltamaxarea=0)

for (prefix in c('maxbayesian', 'max2050', 'max2070')) {
    for (filename in list.files("results", paste0(prefix, "-.+\\.csv"))) {
        assumptions <- substring(filename, nchar(prefix)+2, nchar(filename)-4)
        if (substring(assumptions, nchar(assumptions)-3, nchar(assumptions)) %in% c('2050', '2070'))
            next

        if (prefix == "maxbayesian")
            profits <- read.csv(file.path("results", paste0("currentprofits-", assumptions, ".csv")), header=F)
        else if (prefix == "max2050")
            profits <- read.csv(file.path("results", paste0("all2050profits-", assumptions, ".csv")), header=F)
        else if (prefix == "max2070")
            profits <- read.csv(file.path("results", paste0("all2070profits-", assumptions, ".csv")), header=F)
        nooptvalue <- sum(profits[,1] * baseline$Barley + profits[,2] * baseline$Corn + profits[,3] * baseline$Cotton +
                          profits[,4] * baseline$Rice + profits[,5] * baseline$Soybean + profits[,6] * baseline$Wheat, na.rm=T)

        opt <- read.csv(file.path("results", filename))            
        opt <- opt %>% left_join(baseline, by="fips")
        
        totalvalue <- sum(opt$profit * opt$mytotal)
        deltavalue <- totalvalue / basevalue - 1
        deltaarea <- sum(opt$mytotal - sapply(1:nrow(opt), function(ii) opt[ii, as.character(opt$crop[ii])])) / sum(opt$mytotal)
        deltamaxarea <- sum(sapply(1:nrow(opt), function(ii) ifelse(opt$crop[ii] == opt$maxcrop[ii], 0, opt$maxarea[ii]))) / sum(opt$maxarea)
        df <- rbind(df, data.frame(period=periods[[prefix]], assumptions, nooptvalue, totalvalue, deltavalue, deltaarea, deltamaxarea))
    }
}

df$lybymc <- F
df$lybymc[grep("lybymc", df$assumptions)] <- T
df$assumptions <- gsub("-lybymc", "", df$assumptions)

df$irrigs <- "By crop"
df$irrigs[grep("allir", df$assumptions)] <- "100%"
df$irrigs[grep("chirr", df$assumptions)] <- "By land"
df$assumptions <- gsub("-allir", "", gsub("-chirr", "", df$assumptions))

df$prices <- NA
df$prices[grep("pfixed", df$assumptions)] <- "ERS"
df$prices[grep("pfixmo", df$assumptions)] <- "Predicted"
df$assumptions <- gsub("pfixed", "", gsub("pfixmo", "", df$assumptions))

df$covars <- NA
df$covars[df$period > 2010] <- "Extrapolated"
df$covars[grep("histco", df$assumptions)] <- "Constant"
df$assumptions <- gsub("-histco", "", df$assumptions)

df$ytrend <- NA
df$ytrend[df$period > 2010] <- "Extrapolated"
df$ytrend[grep("notime", df$assumptions)] <- "Constant"
df$assumptions <- gsub("-notime", "", df$assumptions)

df$period <- as.character(df$period)
df$totalvalue <- df$totalvalue / 1e9
df$deltavalue <- paste0(round(df$deltavalue * 100), "%")
df$deltaarea <- paste0(round(df$deltaarea * 100), "%")
df$deltamaxarea <- paste0(round(df$deltamaxarea * 100), "%")

names(df) <- c("Period", "assumptions", "Value ($B)", "Value change", "Crop changes", "Main crop changes", "MC Limit", "Irrigation", "Prices", "Covariates", "Trends")
print(xtable(df[-1, c(1, 7:11, 3:6)]), include.rownames=F, file="assumptions-current.tex")

## Constranied optimum
basevalue <- sum(baseline$Barley * profits$barl + baseline$Corn * profits$corn +
                  baseline$Cotton * profits$cott + baseline$Rice * profits$rice +
                  baseline$Soybean * profits$soyb + baseline$Wheat * profits$whea)
df <- data.frame(period=2010, assumptions='Baseline', totalvalue=basevalue, deltavalue=0, deltaarea=0)

for (prefix in c('constopt-currentprofits', 'constopt-all2050profits', 'constopt-all2070profits')) {
    for (filename in list.files("results", paste0(prefix, "-.+\\.csv"))) {
        assumptions <- substring(filename, nchar(prefix)+2, nchar(filename)-4)
        if (substring(assumptions, nchar(assumptions)-3, nchar(assumptions)) %in% c('2050', '2070'))
            next

        opt <- read.csv(file.path("results", filename))
        profs <- read.csv(file.path("results", substring(filename, 10)), header=F)
        names(profs) <- c("Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat")

        totalvalue <- sum(profs * opt[, 3:8], na.rm=T)
        deltavalue <- totalvalue / basevalue - 1
        
        opt <- opt %>% left_join(baseline, by="fips")
        deltaarea <- sum(abs(baseline[,4:9] - opt[,3:8])) / sum(baseline$mytotal)
        ## TODO: deltamaxarea-- need to look at max on both sides

        df <- rbind(df, data.frame(period=periods[[prefix]], assumptions, totalvalue, deltavalue, deltaarea))
    }    
}
