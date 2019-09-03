setwd("~/research/water/awash/analyses/addeds")
load("../../data/counties/waternet/waternet.RData")

library(ncdf4)

ncin <- nc_open("../../data/cache/counties/contributing_runoff_by_gage.nc")
gages <- ncvar_get(ncin, "gage_id")
flows <- ncvar_get(ncin, "totalflow")
areas <- ncvar_get(ncin, "contributing_area")

## Construct gage names
gage.names <- rep("", 22587)
for (ii in 2:length(gages))
    gage.names <- paste(gage.names, strsplit(gages[ii], "")[[1]], sep="")
gage.names <- gsub("\" *", "", gage.names)

## Determine area for each node
basin.areas <- rep(NA, nrow(network))

get.basin.area <- function(ii, ignore=c()) {
    ## if (!is.na(basin.areas[ii]))
    ##     return(basin.areas[ii])

    above <- 0
    for (jj in which(network$nextpt == ii)) {
        if (jj %in% ignore)
            next
        above <- above + get.basin.area(jj, ignore=c(ignore, ii))
    }

    name <- paste(network$collection[ii], network$colid[ii], sep='.')
    gg <- which(gage.names == name)
    if (length(gg) > 0)
        return(above + areas[gg])
    else
        return(above)
}

for (ii in 1:nrow(network)) {
    print(ii)
    basin.areas[ii] <- get.basin.area(ii)
}

write.csv(data.frame(network$collection, network$colid, basin.areas), "basinareas.csv", row.names=F)

manning.time <- function(dist, drop, flow) {
    n <- .035 # Major natural rivers from http://www.engineeringtoolbox.com/mannings-roughness-d_799.html
    slope <- drop / dist
    radius <- (flow / ((1/n)*(1/2)^(2/3)*sqrt(slope)*(pi/2)))^(1/(2+2/3))

    velocity <- (1 / n) * radius^(2/3) * slope^(1/2)
    velocity * dist / (24*60*60*30)
}

add.delay <- function(flow.time, flow.data, dist.m, drop.m, out.time) {
    if (sum(!is.na(flow.data)) < 2)
        return(rep(NA, length(out.time)))

    apxfun <- approxfun(flow.time, flow.data)
    flow.average <- mean(flow.data, na.rm=T)
    if (is.na(drop.m) || drop.m < 0)
        dt <- 0
    else
        dt <- manning.time(dist.m, drop.m, flow.average)
    apxfun(out.time - dt)
}

total.flows <- matrix(NA, nrow(network), dim(flows)[2])

get.total.flows <- function(ii) {
    if (!is.na(total.flows[ii, 700]))
        return(total.flows[ii,])

    total.flows[ii,] <<- 0 # fill 0 in case recurse

    alltime <- 1:dim(flows)[2]

    incoming <- rep(0, dim(flows)[2])
    for (jj in which(network$nextpt == ii))
        incoming <- incoming + add.delay(alltime, get.total.flows(jj), network$dist[jj], network$elev[jj] - network$elev[ii], alltime)

    name <- paste(network$collection[ii], network$colid[ii], sep='.')
    gg <- which(gage.names == name)
    if (length(gg) != 1) {
        print(c(name, gg))
        contribs <- rep(0, dim(flows)[2])
    } else {
        contribs <- flows[gg,] * areas[gg] * 1000 / (24*60*60*30)
        contribs[is.nan(contribs)] <- 0 # it happens
    }

    total.flows[ii,] <<- contribs + incoming
    return(total.flows[ii,])
}

for (ii in 1:nrow(network)) {
    if (is.na(total.flows[ii, 700])) {
        print(c(ii, mean(!is.na(total.flows[, 700]))))
        get.total.flows(ii)
    }
}

save(total.flows, file="victotal.RData")
