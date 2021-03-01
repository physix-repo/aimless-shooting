#!/bin/bash

exeGRMX=gmx

maxLength=160000
frameCount=$(awk "BEGIN { print ($maxLength / $delta_t); }")
halfFrames=$(awk "BEGIN { print ($frameCount / 2); }")
echo "$maxLength (ps), $frameCount, $halfFrames"

for delta_t in 100 200
do
  # the initial trajectory that you need to cut into configuration
  seedDir=/home/aljed/Files/nucleation/seeding/4K/seeding_237K
  traj=$seedDir/$seed
  trajBwd=$traj/s_i2
  trajFwd=$traj/s_i7

  confDir=config_$delta_t
  mkdir -p $confDir
  frames=$(awk "BEGIN {for (i = 0; i < $halfFrames; i += 1) print i;}")
  for frame in $frames
  do
    conf=$(awk "BEGIN {print int (($frame + 1) * $delta_t)}")
    fwd=$(awk "BEGIN {print $halfFrames - $frame}")
    bwd=$(awk "BEGIN {print $halfFrames + $frame + 1}")
    echo "frame : $fwd + $bwd"
    echo "2" | $exeGRMX trjconv -f ${trajBwd}.xtc -s ${trajBwd}.tpr \
               -o $confDir/${bwd}.pdb -b $conf -e $conf
    echo "2" | $exeGRMX trjconv -f ${trajFwd}.xtc -s ${trajFwd}.tpr \
               -o $confDir/${fwd}.pdb -b $conf -e $conf
  done
  rm -f $confDir/\#*
done
