#!/bin/bash

for i in $(seq 1 $2); do
    nohup ~/added/julia-1.3.1/bin/julia $1 >& log$i.txt &
    sleep 5
done
