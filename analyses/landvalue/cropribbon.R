setwd("~/research/water/awash/analyses/landvalue")

library(dplyr)

comparefiles <- c("constopt-currentprofits-pfixed.csv", "constopt-all2050profits-pfixed-notime-histco.csv", "constopt-all2070profits-pfixed-notime-histco.csv") #"maxbayesian-pfixed.csv"
comparecols <- rep("topcrop", 3) #"crop"
titles <- c("Optimized", "2050", "2070")

## Compare to optimal current crops

results2 <- read.csv("actualcrops.csv")
results3 <- subset(results2, !is.na(maxcrop.before))

areas <- read.csv("../../data/counties/agriculture/knownareas.csv")
areas$mytotal <- areas$BARLEY + areas$CORN + areas$COTTON + areas$RICE + areas$SOYBEANS + areas$WHEAT
results3 <- results3 %>% left_join(areas, by="fips")

for (ff in 1:length(comparefiles)) {
    optcrops <- read.csv(comparefiles[ff])
    newcol <- paste0("crop", ff)
    optcrops[, newcol] <- as.character(optcrops[, comparecols[ff]])
    results3 <- results3 %>% left_join(optcrops, by="fips")

    results3[, newcol][results3[, newcol] == "Barley"] <- "BARLEY"
    results3[, newcol][results3[, newcol] == "Corn"] <- "CORN"
    results3[, newcol][results3[, newcol] == "Cotton"] <- "COTTON"
    results3[, newcol][results3[, newcol] == "Rice"] <- "RICE"
    results3[, newcol][results3[, newcol] == "Soybean"] <- "SOYBEANS"
    results3[, newcol][results3[, newcol] == "Wheat"] <- "WHEAT"
    results3[, newcol][is.na(results3[, newcol])] <- "NONE"
}

allcols <- c("maxcrop.before", paste0("crop", 1:length(comparefiles)))
width <- 1.25 * length(comparefiles)

croplist2 <- c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT", "NONE")
colors <- c('#f8766d', '#b79f00', '#00ba38', '#00bfc4', '#619cff', '#f564e3', '#808080')

plot.new()
par(mar=c(0,0,0,0)+.1)
plot.window(xlim=c(0, width), ylim=c(0,105))
xspline(c(0, width, .75, 1), rep(0, 4), lwd=1, border="#000000", lend=1)
xspline(c(0, width, .75, 1), rep(100, 4), lwd=1, border="#000000", lend=1)
text(0, 102, "Observed", pos=4)

for (ff in 1:length(comparefiles)) {
    xstart <- 1.25 * (ff - 1)
    xend <- 1.25 * ff

    croplist <- c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT")
    sumdf <- data.frame(cropii=c(), cropjj=c(), portion=c())
    for (cropii in croplist) {
        for (cropjj in croplist) {
            if (ff == 1)
                portion <- sum(results3[results3[, allcols[ff+1]] == cropjj, cropii]) / sum(results3$mytotal)
            else
                portion <- sum(results3$mytotal[results3[, allcols[ff]] == cropii & results3[, allcols[ff+1]] == cropjj]) / sum(results3$mytotal)
            sumdf <- rbind(sumdf, data.frame(cropii, cropjj, portion))
        }
        if (ff == 1)
            portion <- sum(results3[results3[, allcols[ff+1]] == "NONE", cropii]) / sum(results3$mytotal)
        else
            portion <- sum(results3$mytotal[results3[, allcols[ff]] == cropii & results3[, allcols[ff+1]] == "NONE"]) / sum(results3$mytotal)
        sumdf <- rbind(sumdf, data.frame(cropii, cropjj="NONE", portion))
    }
    for (cropjj in croplist) {
        portion <- sum(results3$mytotal[results3[, allcols[ff]] == "NONE" & results3[, allcols[ff+1]] == cropjj]) / sum(results3$mytotal)
        sumdf <- rbind(sumdf, data.frame(cropii="NONE", cropjj, portion))
    }
    portion <- sum(results3$mytotal[results3[, allcols[ff]] == "NONE" & results3[, allcols[ff+1]] == "NONE"]) / sum(results3$mytotal)
    sumdf <- rbind(sumdf, data.frame(cropii="NONE", cropjj="NONE", portion))

    text(xend - .25, 102, titles[ff], pos=4)
    for (ii in rev(order(sumdf$portion))) {
        if (sumdf$portion[ii] > 0) {#.01) {
            yii <- 100 - sum(sumdf$portion[-(ii:nrow(sumdf))]) * 100
            yjj <- 100 - sum(sumdf$portion[sumdf$cropjj %in% croplist2[-(which(croplist2 == sumdf$cropjj[ii])[1]:7)] | (sumdf$cropjj == sumdf$cropjj[ii] & sumdf$cropii %in% croplist2[-(which(croplist2 == sumdf$cropii[ii])[1]:7)])]) * 100
            xspline(xstart + c(0, .25, .75, 1), c(rep(yii - 50*sumdf$portion[ii], 2), rep(yjj - 50*sumdf$portion[ii], 2)), lwd=4.5 * 100 * sumdf$portion[ii], border=colors[croplist2 == sumdf$cropii[ii]], lend=1, shape=.5)
            xspline(xstart + c(1, 1.25), c(rep(yjj - 50*sumdf$portion[ii], 2)), lwd=4.5 * 100 * sumdf$portion[ii], border=colors[croplist2 == sumdf$cropjj[ii]], lend=1)
        }
    }

    for (crop in c(croplist, "NONE")) {
        print(paste("% start", crop, "=", sum(sumdf$portion[sumdf$cropii == crop])))
        print(paste("% end", crop, "=", sum(sumdf$portion[sumdf$cropjj == crop])))
    }
}
