setwd("~/research/awash/analyses/landvalue")

do.generate.actualcrops <- F
comparefile <- "maxbayesian-pfixed.csv" #"constopt-currentprofits-pfixed.csv"
comparecol <- "crop" #"topcrop"

if (do.generate.actualcrops) {
    
do.cropdrop <- T

df <- read.csv("../../prepare/agriculture/all2010.csv")
if (do.cropdrop)
    df <- subset(df, Commodity %in% c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT"))

df$value <- as.numeric(gsub(",", "", as.character(df$Value)))
df$fips <- df$State.ANSI * 1000 + df$County.ANSI
df$fips[is.na(df$fips)] <- df$State.ANSI[is.na(df$fips)] * 1000

results <- data.frame(fips=c(), maxcrop=c())
for (fipsii in unique(df$fips)) {
    subdf <- subset(df, fips == fipsii)
    rows <- grep("ACRES", subdf$Data.Item)
    best <- rows[subdf$value[rows] == max(subdf$value[rows])][1]
    results <- rbind(results, data.frame(fips=fipsii, maxcrop=subdf$Commodity[best]))
}

library(dplyr)
library(maps)

data(county.fips)

results2 <- county.fips %>% left_join(results)
results2$maxcrop <- as.character(results2$maxcrop)
results2$maxcrop.before <- results2$maxcrop

for (stateii in floor(results2$fips / 1000)) {
    maxcrop <- as.character(results$maxcrop[results$fips == 1000 * stateii])
    if (length(maxcrop) > 0)
        results2$maxcrop[is.na(results2$maxcrop) & floor(results2$fips / 1000) == stateii] <- maxcrop
}

write.csv(results2, "actualcrops.csv", row.names=F)

cnty <- map_data("county")

cnty2 <- cnty %>%
    mutate(polyname = paste(region,subregion,sep=",")) %>%
    left_join(results2, by="polyname")

library(ggplot2)

ggplot(cnty2, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = maxcrop))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("")
if (do.cropdrop) {
    ggsave("maxcrop-limited.png", width=10, height=5)
} else {
    ggsave("maxcrop.png", width=10, height=5)
}

} else
    results2 <- read.csv("actualcrops.csv")
    
## Compare to optimal current crops

results2 <- subset(results2, !is.na(maxcrop.before))
optcrops <- read.csv(comparefile)
results3 <- results2 %>% left_join(optcrops)

results3$crop <- as.character(results3[, comparecol])
results3$crop[results3$crop == "Barley"] <- "BARLEY"
results3$crop[results3$crop == "Corn"] <- "CORN"
results3$crop[results3$crop == "Cotton"] <- "COTTON"
results3$crop[results3$crop == "Rice"] <- "RICE"
results3$crop[results3$crop == "Soybean"] <- "SOYBEANS"
results3$crop[results3$crop == "Wheat"] <- "WHEAT"

sum(results3$crop == results3$maxcrop.before, na.rm=T) / nrow(results3)

croplist <- c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT")
sumdf <- data.frame(cropii=c(), cropjj=c(), portion=c())
for (cropii in croplist) {
    for (cropjj in croplist) {
        portion <- sum(results3$maxcrop.before == cropii & results3$crop == cropjj, na.rm=T) / nrow(results3)
        sumdf <- rbind(sumdf, data.frame(cropii, cropjj, portion))
    }
    portion <- sum(results3$maxcrop.before == cropii & is.na(results3$crop), na.rm=T) / nrow(results3)
    sumdf <- rbind(sumdf, data.frame(cropii, cropjj="NONE", portion))
}
for (cropjj in croplist) {
    portion <- sum(is.na(results3$maxcrop.before) & results3$crop == cropjj, na.rm=T) / nrow(results3)
    sumdf <- rbind(sumdf, data.frame(cropii="NONE", cropjj, portion))
}
portion <- sum(is.na(results3$maxcrop.before) & is.na(results3$crop), na.rm=T) / nrow(results3)
sumdf <- rbind(sumdf, data.frame(cropii="NONE", cropjj="NONE", portion))

croplist2 <- c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT", "NONE")
colors <- c('#f8766d', '#b79f00', '#00ba38', '#00bfc4', '#619cff', '#f564e3', '#808080')

plot.new()
par(mar=c(0,0,0,0)+.1)
plot.window(xlim=c(0,1.25), ylim=c(0,105))
xspline(c(0, 1.25, .75, 1), rep(0, 4), lwd=1, border="#000000", lend=1)
xspline(c(0, 1.25, .75, 1), rep(100, 4), lwd=1, border="#000000", lend=1)
text(0, 102, "Observed crop", pos=4)
text(1, 102, "Optimal crop", pos=4)
for (ii in rev(order(sumdf$portion))) {
    if (sumdf$portion[ii] > 0) {#.01) {
        yii <- 100 - sum(sumdf$portion[-(ii:nrow(sumdf))]) * 100
        yjj <- 100 - sum(sumdf$portion[sumdf$cropjj %in% croplist2[-(which(croplist2 == sumdf$cropjj[ii])[1]:7)] | (sumdf$cropjj == sumdf$cropjj[ii] & sumdf$cropii %in% croplist2[-(which(croplist2 == sumdf$cropii[ii])[1]:7)])]) * 100
        xspline(c(0, .25, .75, 1), c(rep(yii - 50*sumdf$portion[ii], 2), rep(yjj - 50*sumdf$portion[ii], 2)), lwd=4.5 * 100 * sumdf$portion[ii], border=colors[croplist2 == sumdf$cropii[ii]], lend=1, shape=.5)
        xspline(c(1, 1.25), c(rep(yjj - 50*sumdf$portion[ii], 2)), lwd=4.5 * 100 * sumdf$portion[ii], border=colors[croplist2 == sumdf$cropjj[ii]], lend=1)
    }
}
