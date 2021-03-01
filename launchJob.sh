#!/bin/bash/

dir=$(pwd)

# if you want to test several delta_t
maxLength=160000
for dt in 100 200
do
  numFrames=$(( maxLength / dt ))
  # if you want to launch several TPS run in different folder
  tpsRun=$(awk "BEGIN { for (i = 1; i < 11; i++) print i; }")
  for run in $tpsRun
  do
    # set-up run folder
    cd $dir
    runDir=TPS_${dt}_${run}
    mkdir -p $runDir

    # set-up job, $frames represent the folder where you put your initial trajectory
    # divided into N configuration, depending on delta_t value
    frames=config_${dt}
    jobName=$runDir/job_TPS_restart
    cp job_TPS_restart $jobName
    sed -i s/jobNameInQueue/AS_${run}/g $jobName
    sed -i s/12348/1${dt}3${run}12/g $jobName
    sed -i s/deltaValue/${dt}/g $jobName
    sed -i s/confDirName/$frames/g $jobName
    sed -i s/maxLengthValue/$maxLength/g $jobName
    sed -i s/shooting_TPS.txt/shooting_TPS_${run}.txt/g $jobName

    # set-up external files needed by the algorithm
    half=$(awk "BEGIN { print int (($dt / 2.) + 1); }")
    echo $half > ${runDir}/currentFrame.txt
    echo 0 > ${runDir}/currentRun.txt
    cp tps.dat ${runDir}/
    cp tps.mdp ${runDir}/

    # launch job, I generally comment this and check that all generated are ok
    # (all place holder name have been replaced and all external files are there)
    cd ${runDir}/
    sbatch job_TPS_restart
  done
done
