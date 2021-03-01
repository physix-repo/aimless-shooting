# In-house scripts for aimless shooting with GROMACS/Plumed

Each script fills a "simple" task:

"extractConfig.sh" allows you to divide an initial trajectory into a set of pdb files, depending on the delta t and maximum length chosen for the algorithm. In this script I merge together two different trajectory shooted from the same point, you will need to adapt it a bit if you have a single trajectory that connect your two states (in fact it should be simpler as you won't need to invert order of the frames to mimic time inversion)

"launchJob.sh" allows you to launch several TPS runs in parallel, each in its dedicated folder with the relevant initial file needed. Here for instance the script will generate two sets of 10 independent TPS runs, with 0.1 ns or 0.2 ns as the time step. It take care to generate all needed external files

"job\_TPS\_restart" is the script in itself for aimless shooting. It's a bit messy but I tried to comment it properly. Technically you only need to modify its line 43 and 44 to define your states (if you change the name of the states, be careful to change it coherently in all the script with %s/Liquid/YourState/g for instance). This script requires several external files:
* `currentFrame.txt` that need to contains the number of the initial configuration of shooting (so a frame near your transition state)
* `currentRun.txt` that need to contains the last run performed (so 0 for initialization)
* A directory that contains pdb files that are frames of your initial transition trajectories
* `tps.mdp` that contains your gromacs parameter. Note that the number of steps should correspond to 5 ns and that the gen\_seed need to be set to 1312 as the script change this number later on with sed to generate .tpr files
* `tps.dat` that contains your plumed parameter (you need to adapt a bit the script if you use something else than plumed) and in which the output file is names `cv_name_holder`
And it will generate the following files:
* One directory for each step (1/, 2/, etc.) that will contain all files generated by gromacs. In it you will have file that end by `_fw` for forward and `_bw` for backward trajectories
* A `colvar/` directory that will contains all the colvar of each step n with format cv\_n\_fw or cv\_n\_bw for forward/backward trajectories
* A `traj/` directory that will contains all the accepted trajectories files (in fact only the xtc, edr and cv, but you can add more if you want)
* A `status_shooting_*.txt` file that contain information about each step: what states it has connected to, if it was accepted, the current step and the length of the longest trajectory backward or forward in time

The script does several things while running: first it will compute from currentFrame.txt and currentRun.txt the last accepted configuration frame number i and at which step of the run we are. Then it will pick at random configuration i+1 or i-1, and generate the two .tpr with inverse velocities. To do this you need to modify gromacs so that it generates velocities in the reverse (and so sadly to reinstall it on Irene...) Precisely you need to put a minus in line 78 of src/gromacs/gmxpreprocess/gen\_maxwell\_velocities.cpp
```
v[i][m] = sd\*normalDist(\*rng);   ------->   v[i][m] = -sd\*normalDist(\*rng);
```
From this two tpr the script will propagate the trajectories by step of 5 ns, until both of them reach states basins or simulation have reached its maximum length. In the current script if a backward or forward trajectory reaches a basin, we stop to update it to gain some computational time. If you want that your two trajectories have the same length, you just need to remove some test on lines 184-201. 

## Procedure example for aimless shooting

1. Select two trajectories shot from the same transition point that connect the two states (so for me one that connect liquid and one that connect ice), and use extractConfig.sh to cut the trajectories into pdb frames with predefined dt and max length for the trajectories.
2. Then upload the generated directories on JeanZay, update launchJob.sh to have the correct name and dt, and just run launchJob.sh, commenting the part in where the jobs are submitted.
3. Double check some of the generated TPS directories to see if all the required files are present and if they are well formatted, checking that all placeholder name have been changed.
4. Run launchJob.sh uncommenting part where I submit the jobs and that's all.

It's generally a good idea to check regularly the status\_shooting\_\*.txt file to see if everything seems fine. Normally you should aim to have 10 to 20% of acceptance rates.

## Contributors

* Alexandre Jedrecy: alexandre.jedrecy@gmail.com

