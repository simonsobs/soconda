#!/bin/bash

# Pixell Tests
#OMP_NUM_THREADS=4 test_pixell.py

# Serial TOAST Tests
OMP_NUM_THREADS=4 MPI_DISABLED=1 python -c 'import toast.tests; toast.tests.run()'

# MPI-enabled tests
OMP_NUM_THREADS=2 mpirun -np 2 python -c 'import toast.tests; toast.tests.run()'
