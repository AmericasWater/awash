deg2rad <- function(deg) return(deg*pi/180)

gcd.slc <- function(long0, lat0, longs, lats) {
    long0 <- deg2rad(long0)
    lat0 <- deg2rad(lat0)
    longs <- deg2rad(longs)
    lats <- deg2rad(lats)

    R <- 6371 # Earth mean radius [km]
    d <- acos(sin(lat0)*sin(lats) + cos(lat0)*cos(lats) * cos(longs-long0)) * R
    return(d) # Distance in km
}
