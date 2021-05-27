#!/bin/bash -l

# This is the aimless shooting submission script

#========================================
#SBATCH --job-name=AS_LiF_water
#SBATCH --time=20:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH -A bgo@cpu
#SBATCH --output=out
#SBATCH --error=err

module purge
module load lammps/20190807-mpi-plumed

base_dir=$(pwd)

# Aimless shooting parameters

as_step=20
max_iter=5000
lmp_data=/gpfswork/rech/bgo/uam43iy/dev/aimless-shooting/lammps_engine/example_LiF/system.lmp
ini_trj=/gpfswork/rech/bgo/uam43iy/dev/aimless-shooting/lammps_engine/example_LiF/nve.lammpstrj
ini_conf=1000638

echo "Aimless shooting timestep: $delta_t MD steps"

# Returns the basin committment of a run
# Argument: plumed output file

trajectory_status() {
  local status=$(grep 'SET COMMIT' $1 | awk '{print $NF}')
  echo $status
}

# Tests if trajectory connects basins A and B
# Argument: current work dir

is_connected() {
  local bwd_status=$(trajectory_status $1/bwd/plumed.out)
  local fwd_status=$(trajectory_status $1/fwd/plumed.out)
  if [[ "$bwd_status" == "$fwd_status" ]] ; then
    connected="False"
  else
    connected="True"
  fi
  echo $connected
}

# Flips a coin to return a shooting point
# New shooting point is either + or - dt
draw_shooting_point_flip() {
  local coin_flip=$(($RANDOM%2)) 
  if [ $coin_flip -eq 0 ] ; then
    local result="bwd"
  else
    local result="fwd"
  fi
  echo $result
}

# Three outcomes to return a shooting point
# New shooting point is either current or + or - dt
draw_shooting_point() {
  local coin_flip=$(($RANDOM%3)) 
  if [ $coin_flip -eq 0 ] ; then
    local result="bwd"
  elif [ $coin_flip -eq 1 ] ; then
    local result="fwd"
  elif [ $coin_flip -eq 2 ] ; then
    local result="current"
  fi
  echo $result
}

# Begin the aimless shooting loop

mkdir accepted_trj

acc=0
rej=0
tot=0

a=0
last_accepted=$ini_trj
accepted="False"

echo "# iter Nacc Nrej Ntot AcceptanceRatio" >> statistics.txt

while [ $a -lt $max_iter ] ; do

  iter_dir=iter_$(printf "%06d" $a)
  mkdir $iter_dir

  cd ${base_dir}/${iter_dir}

  # In the next steps, edit the lammps submission
  # script according to current state

  mkdir bwd
  mkdir fwd

  cp ${base_dir}/in_bwd.lmp ${base_dir}/${iter_dir}/bwd/in.lmp
  cp ${base_dir}/in_fwd.lmp ${base_dir}/${iter_dir}/fwd/in.lmp

  cp ${base_dir}/plumed.dat ${base_dir}/${iter_dir}/bwd/.
  cp ${base_dir}/plumed.dat ${base_dir}/${iter_dir}/fwd/.

  cp ${base_dir}/path.pdb ${base_dir}/${iter_dir}/bwd/.
  cp ${base_dir}/path.pdb ${base_dir}/${iter_dir}/fwd/.

  # Setup original lammps data file with topology information

  sed -i 's,'"MYDATA"','"$lmp_data"',g' bwd/in.lmp
  sed -i 's,'"MYDATA"','"$lmp_data"',g' fwd/in.lmp

  # Select shooting point

  shot_point=$(draw_shooting_point)

  if [[ $last_accepted == $ini_trj ]] ; then
    # No accepted trj yet: the current configuration
    # is  extracted from the original trj

    sed -i 's,'"MYTRJ"','"$ini_trj"',g' bwd/in.lmp
    sed -i 's,'"MYTRJ"','"$ini_trj"',g' fwd/in.lmp

    if [[ $shot_point == "bwd" ]] ; then
      let "curr_conf=$ini_conf-$as_step"
    elif [[ $shot_point == "fwd" ]] ; then
      let "curr_conf=$ini_conf+$as_step"
    elif [[ $shot_point == "current" ]] ; then
      let "curr_conf=$ini_conf"
    fi
  else
    # The general case where we opt for the first
    # frame of either the backward or forward trj

    if [[ $shot_point == "bwd" ]] || [[ $shot_point == "fwd" ]] ; then
      curr_conf=$as_step
      sed -i 's,'"MYTRJ"','"${base_dir}/${last_accepted}/${shot_point}/nvt.lammpstrj"',g' bwd/in.lmp
      sed -i 's,'"MYTRJ"','"${base_dir}/${last_accepted}/${shot_point}/nvt.lammpstrj"',g' fwd/in.lmp
    elif [[ $shot_point == "current" ]] ; then
      curr_conf=0
      sed -i 's,'"MYTRJ"','"${base_dir}/${last_accepted}/fwd/nvt.lammpstrj"',g' bwd/in.lmp
      sed -i 's,'"MYTRJ"','"${base_dir}/${last_accepted}/fwd/nvt.lammpstrj"',g' fwd/in.lmp
    fi
  fi

  sed -i 's,'"MYCONF"','"$curr_conf"',g' bwd/in.lmp
  sed -i 's,'"MYCONF"','"$curr_conf"',g' fwd/in.lmp

  sed -i 's,'"MYSTEP"','"$as_step"',g' bwd/in.lmp
  sed -i 's,'"MYSTEP"','"$as_step"',g' fwd/in.lmp

  curr_seed=${RANDOM}

  sed -i 's,'"MYSEED"','"$curr_seed"',g' bwd/in.lmp
  sed -i 's,'"MYSEED"','"$curr_seed"',g' fwd/in.lmp

  # Run forward and backward time propagations

  cd ${base_dir}/${iter_dir}/bwd
  srun lmp -i in.lmp -sf opt

  cd ${base_dir}/${iter_dir}/fwd
  srun lmp -i in.lmp -sf opt

  cd ${base_dir}/${iter_dir}

  # Test if the new trajectory connects the two basins

  connectivity=$(is_connected ${base_dir}/${iter_dir})

  if [[ $connectivity == "True" ]] ; then
    # Accept the trajectory, store the data
    last_accepted=$iter_dir

    cp ${base_dir}/${iter_dir}/bwd/nvt.lammpstrj ${base_dir}/accepted_trj/bwd_${iter_dir}.lammpstrj
    cp ${base_dir}/${iter_dir}/fwd/nvt.lammpstrj ${base_dir}/accepted_trj/fwd_${iter_dir}.lammpstrj


    # Store CV values

    sed '2,2!d' ${base_dir}/${iter_dir}/bwd/colvar >> ${base_dir}/accepted.cv

    acc=$((acc+1))
    tot=$((tot+1))
  else
    rej=$((rej+1))
    tot=$((tot+1))

    rm -f ${base_dir}/${iter_dir}/fwd/nvt.lammpstrj
    rm -f ${base_dir}/${iter_dir}/bwd/nvt.lammpstrj
  fi
    
  # Update output with statistics

  perc_acc=$(bc <<< "scale=2; 100.*$acc/$tot")

  echo "$a $acc $rej $tot $perc_acc" >> ${base_dir}/statistics.txt
    
  a=$((a+1))

  cd ${base_dir}

done
