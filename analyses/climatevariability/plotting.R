library(ggplot2)
library(PBSmapping)
library(maptools)


shapes <- importShapefile("../../data/mapping/US_county_2000-simple")
polydata <- attributes(shapes)$PolyData
polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]
polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]
shapes$id <- polydata$STATE[shapes$PID] * 100 + polydata$COUNTY[shapes$PID] / 10;
names(shapes) <- tolower(names(shapes));

stateshapes <- importShapefile("../../data/mapping/tl_2010_us_state00/tl_2010_us_state00-simple")
statespolydata <- attributes(stateshapes)$PolyData
stateshapes$x <- stateshapes$X
stateshapes$y <- stateshapes$Y
stateshapes$id <- stateshapes$PID


mastercounties <- read.csv("../../data/global/counties.csv")
v_FIPS <- mastercounties$fips



mapdata2 <- function(vartoplot,varname, transtype='identity'){
  df <- data.frame(v_FIPS,vartoplot)
  names(df) = c("fips","value")

if(sum(df$value<0, na.rm = T)>0 & sum(df$value>0, na.rm = T)>0){
print(ggplot(df) +
        geom_map(aes(fill=value, map_id=fips), map=shapes) +
        geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='gray', fill=NA) +
        expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
        theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('') +
        scale_fill_gradient2(name=varname, trans=transtype))
}else{
print(ggplot(df) +
        geom_map(aes(fill=value, map_id=fips), map=shapes) +
        geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
        expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
        theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')+
        scale_fill_gradient(name=varname, trans=transtype))
}}

mapdata <- function(vartoplot,varname, transtype='identity', breaks='auto', limits=c(min(vartoplot),max(vartoplot))){
  df <- data.frame(v_FIPS,vartoplot)
  names(df) = c("fips","value")
  
  if(sum(df$value<0, na.rm = T)>0 & sum(df$value>0, na.rm = T)>0){
    print(ggplot(df) +
            geom_map(aes(fill=value, map_id=fips), map=shapes) +
            geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='gray', fill=NA) +
            expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
            theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('') +
            scale_fill_gradient2(name=varname, trans=transtype))
  }else{
    if(breaks == 'auto'){ if(transtype == 'identity'){
      print(ggplot(df) +
              geom_map(aes(fill=value, map_id=fips), map=shapes) +
              geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
              expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
              theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')+
              scale_fill_gradient(name=varname, trans=transtype, breaks=c(0, signif(max(df$value, na.rm = T)*3/10, digits = 2), signif(max(df$value, na.rm = T)*6/10, digits = 2), signif(max(df$value, na.rm = T)*9/10, digits = 2)), limits=limits))
    }else{
      print(ggplot(df) +
              geom_map(aes(fill=value, map_id=fips), map=shapes) +
              geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
              expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
              theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')+
              scale_fill_gradient(name=varname, trans=transtype, breaks=c(0, signif(exp(log(max(df$value, na.rm = T))*3/10), digits = 2), signif(exp(log(max(df$value, na.rm = T))*6/10), digits = 2), signif(exp(log(max(df$value, na.rm = T))*9/10), digits = 2)), limits=limits))}   
    }else{
    print(ggplot(df) +
            geom_map(aes(fill=value, map_id=fips), map=shapes) +
            geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
            expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
            theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')+
            scale_fill_gradient(name=varname, trans=transtype, breaks=breaks, limits=limits))
  }}}

