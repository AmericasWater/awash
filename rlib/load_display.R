drawNetwork <- function(network, xlim=NA, ylim=NA, col="#000000", labels=F, include=c()) {
    if (length(include) == 0)
        include <- 1:nrow(network)

    for (ii in include) {
        if (!is.na(network$nextpt[ii])) {
            downstream <- network[network$nextpt[ii],]
            if (!is.na(xlim) && ((network$lon[ii] < xlim[1] && downstream$lon < xlim[1]) ||
                                     (network$lon[ii] > xlim[2] && downstream$lon > xlim[2])))
                next
            if (!is.na(ylim) && ((network$lat[ii] < ylim[1] && downstream$lat < ylim[1]) ||
                                     (network$lat[ii] > ylim[2] && downstream$lat > ylim[2])))
                next

            lines(c(network$lon[ii], downstream$lon), c(network$lat[ii], downstream$lat), col=col)
        }
        if (labels) {
            if (!is.na(xlim) && (network$lon[ii] < xlim[1] || network$lon[ii] > xlim[2]))
                next
            if (!is.na(ylim) && (network$lat[ii] < ylim[1] || network$lat[ii] > ylim[2]))
                next

            text(network$lon[ii], network$lat[ii], ii, cex=.5)
        }
    }
}

drawStations <- function(stations, pch=16, cex=.2, collev=NA) {
    if (length(collev) == 1 && is.na(collev))
        col <- as.numeric(factor(stations$collection))+1
    else
        col <- collev[as.numeric(factor(stations$collection))]

    points(stations$lon, stations$lat, col=col, pch=pch, cex=cex)
}
