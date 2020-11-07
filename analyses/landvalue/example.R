setwd("~/research/water/awash-crops/analyses/landvalue")

df <- read.csv("soydata.csv")

library(ggplot2)
library(maps)
library(dplyr)

cnty <- map_data("county")
data(county.fips)
cnty2 <- cnty %>%
        mutate(polyname = paste(region,subregion,sep=",")) %>%
    left_join(county.fips, by="polyname")
cnty2.df1 <- inner_join(cnty2, df, by="fips")

ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = soy_revenue), colour = rgb(1,1,1,0.2))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("") +
    theme(legend.justification=c(1,0), legend.position=c(1,0)) +
    scale_fill_gradient(name="Revenue\n($/acre)")
ggsave("soy-revenue.png", width=8, height=4)

ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = soy_opcost), colour = rgb(1,1,1,0.2))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("") +
    theme(legend.justification=c(1,0), legend.position=c(1,0)) +
    scale_fill_gradient(name="Op. costs\n($/acre)")
ggsave("soy-opcost.png", width=8, height=4)

ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = soy_opcost_full), colour = rgb(1,1,1,0.2))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("") +
    theme(legend.justification=c(1,0), legend.position=c(1,0)) +
    scale_fill_gradient(name="Op. costs\n($/acre)")
ggsave("soy-opcost-full.png", width=8, height=4)

ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = soy_price_full), colour = rgb(1,1,1,0.2))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("") +
    theme(legend.justification=c(1,0), legend.position=c(1,0)) +
    scale_fill_gradient(name="Price\n($/bushel)")
ggsave("soy-price-full.png", width=8, height=4)


library(dplyr)

## Set up a dataset of "before" and "after" crops, by county

results2 <- read.csv("actualcrops.csv")
optcrops <- read.csv("maxbayesian-pfixed-lybymc.csv")
results3 <- results2 %>% left_join(optcrops)

results3$crop <- as.character(results3$crop)
results3$crop[results3$crop == "Barley"] <- "BARLEY"
results3$crop[results3$crop == "Corn"] <- "CORN"
results3$crop[results3$crop == "Cotton"] <- "COTTON"
results3$crop[results3$crop == "Rice"] <- "RICE"
results3$crop[results3$crop == "Soybean"] <- "SOYBEANS"
results3$crop[results3$crop == "Wheat"] <- "WHEAT"

## Create a dataset of transitions from crop1 to crop2

croplist <- c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT")
sumdf <- data.frame(cropii=c(), cropjj=c(), portion=c())
for (cropii in croplist) {
    for (cropjj in croplist) {
        portion <- sum(results3$crop == cropii & results3$maxcrop == cropjj, na.rm=T) / nrow(results3)
        sumdf <- rbind(sumdf, data.frame(cropii, cropjj, portion))
    }
    portion <- sum(results3$crop == cropii & is.na(results3$maxcrop), na.rm=T) / nrow(results3)
    sumdf <- rbind(sumdf, data.frame(cropii, cropjj="NONE", portion))
}
for (cropjj in croplist) {
    portion <- sum(is.na(results3$crop) & results3$maxcrop == cropjj, na.rm=T) / nrow(results3)
    sumdf <- rbind(sumdf, data.frame(cropii="NONE", cropjj, portion))
}
portion <- sum(is.na(results3$crop) & is.na(results3$maxcrop), na.rm=T) / nrow(results3)
sumdf <- rbind(sumdf, data.frame(cropii="NONE", cropjj="NONE", portion))

## Make the plot

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
    if (sumdf$portion[ii] > .01) { # Adjust if want thinner/thicker threshold for lines drawn
        yii <- 100 - sum(sumdf$portion[-(ii:nrow(sumdf))]) * 100
        yjj <- 100 - sum(sumdf$portion[sumdf$cropjj %in% croplist2[-(which(croplist2 == sumdf$cropjj[ii])[1]:7)] | (sumdf$cropjj == sumdf$cropjj[ii] & sumdf$cropii %in% croplist2[-(which(croplist2 == sumdf$cropii[ii])[1]:7)])]) * 100
        xspline(c(0, .25, .75, 1), c(rep(yii - 50*sumdf$portion[ii], 2), rep(yjj - 50*sumdf$portion[ii], 2)), lwd=4.5 * 100 * sumdf$portion[ii], border=colors[croplist2 == sumdf$cropii[ii]], lend=1, shape=.5)
        xspline(c(1, 1.25), c(rep(yjj - 50*sumdf$portion[ii], 2)), lwd=4.5 * 100 * sumdf$portion[ii], border=colors[croplist2 == sumdf$cropjj[ii]], lend=1)
    }
}
