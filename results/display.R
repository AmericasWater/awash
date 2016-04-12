setwd("~/projects/water/model/operational-problem/results/")

source("~/projects/research-common/R/drawmap.R")

info <- read.csv("../data/county-info.csv")

counties <- read.csv("regionout.csv")
counties$name <- NA
for (ii in 1:nrow(counties)) {
    jj <- which(county.fips$fips == counties$fips[ii])
    if (length(jj) == 1)
        counties$name[ii] <- as.character(county.fips$polyname[jj])
}

drawusa <- function(values, style="quantile") {
    colors <- rev(brewer.pal(9, "RdYlGn"))

    brks <- classIntervals(values, n=9, style=style)
    brks <- brks$brks

    map("state", fill=T, mar=c(1, 2, 3, 0))
    for (ii in 1:length(values)) {
        if (!is.na(counties$name[ii]))
            map("county", counties$name[ii], col=colors[findInterval(values[ii], brks, all.inside=TRUE)], fill=T, mar=c(1, 2, 3, 0), add=T)
    }

    legend("bottomleft", legend=leglabs(round(brks, digits=3)), fill=colors, bty="n", cex=.7)
}

pdf("pumping.pdf", width=10, height=6)
drawusa(counties$pumping)
dev.off()

pdf("swbalance.pdf", width=10, height=6)
drawusa(counties$swbalance)
dev.off()

counties <- read.csv("cropsout.csv")
counties$name <- NA
counties$area <- NA
for (ii in 1:nrow(counties)) {
    jj <- which(county.fips$fips == counties$fips[ii])
    if (length(jj) == 1)
        counties$name[ii] <- as.character(county.fips$polyname[jj])
    jj <- which(info$FIPS == counties$fips[ii])
    if (length(jj) == 1)
        counties$area[ii] <- info$LandArea.sqmi[jj] * 258.999
}

for (crop in unique(counties$crop)) {
    if (sum(counties$rainfedareas[counties$crop == crop] != 0) > 0) {
        pdf(paste0("rainfedareas-", crop, ".pdf"), width=10, height=6)
        drawusa(counties$rainfedareas[counties$crop == crop] / counties$area[counties$crop == crop])
        dev.off()
    }

    if (sum(counties$irrigatedareas[counties$crop == crop] != 0) > 0) {
        pdf(paste0("irrigatedareas-", crop, ".pdf"), width=10, height=6)
        drawusa(counties$irrigatedareas[counties$crop == crop] / counties$area[counties$crop == crop])
        dev.off()
    }

    if (sum(counties$internationalsales[counties$crop == crop] != 0) > 0) {
        pdf(paste0("internationalsales-", crop, ".pdf"), width=10, height=6)
        drawusa(counties$internationalsales[counties$crop == crop])
        dev.off()
    }
}
