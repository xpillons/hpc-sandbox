#!/bin/bash
set -o errexit
set -o pipefail

# setup Intel MPI environment for Infiniband
source /opt/intel/impi/*/bin64/mpivars.sh
export I_MPI_DEBUG=6
export I_MPI_STATS=ipm
export I_MPI_DYNAMIC_CONNECTION=0
export I_MPI_FALLBACK_DEVICE=0
export I_MPI_EAGER_THRESHOLD=1048576
export I_MPI_FABRICS=shm:dapl
export I_MPI_DAPL_PROVIDER=ofa-v2-ib0

mpirun -np 2 -ppn 1 -hosts $MPI_HOSTLIST IMB-MPI1 PingPong
