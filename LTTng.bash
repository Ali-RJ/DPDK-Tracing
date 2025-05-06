#! /bin/bash

sudo lttng create testpmd-memif-2way-traffic

sudo lttng enable-channel --userspace --num-subbuf=4 --subbuf-size=64M channel0

sudo lttng enable-event --channel channel0 --userspace --all

lttng add-context --channel channel0 --userspace --type=vpid --type=vtid --type=procname --type=perf:thread:cpu-cycles --type=perf:thread:instructions --type=perf:thread:cache-misses


sudo lttng start
sleep 1
sudo lttng stop
sudo lttng destroy --all