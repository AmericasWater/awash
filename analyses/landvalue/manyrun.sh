#!/bin/bash

for i in $(seq 1 $2); do
    nohup julia $1 >& log$i.txt &
    sleep 5
done
