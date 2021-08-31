# LTRANS_microplastics
This is the repository for the modified Larval TRNASport Lagrangian [LTRANS](https://northweb.hpl.umces.edu/LTRANS.htm) model. The modified code contains the implementation of the parameterization including the effects of subsurface currents on buoyant particles ([Liang et al., 2018](https://journals.ametsoc.org/view/journals/phoc/48/9/jpo-d-18-0020.1.xml)). The example is an application of the model on riverborne plastics over the Louisiana/Texas continental shelf (Liang et al., 2021, accepted).

---
## Quick Start

1. Installation

Create a local copy of `LTRANS_microplastics` by

```
git clone https://github.com/lsuocean/LTRANS_microplastics
```
2. Change to the input directory
```
cd LTRANS_microplastics
```
3. Create input and output directory (as an example, choose 0.0005m/s for the rising speed of the buoyant particles, i.e., `sink= 0.0005` in `LTRANS.data`)
```
mkdir input
mkdir input/ROMS_solution
mkdir output
mkdir output/0.0005
```
4. Download the ROMS solution in netcdf (nc) format from http://barataria.tamu.edu:8080/thredds/catalog.html, and rename the downloaded nc file (say the original file name for year 2008 is ROMS_2008.nc) as 20080001.nc, and save the file in directory input/ROMS_solution
```
cd input/ROMS_solution
mv ROMS_2008.nc 20080001.nc
```
5. Create the particle location Initial_part_location.csv.

You can find the example of `Initial_part_location.csv` and user guide on https://github.com/LTRANS/LTRANSv.2b.
- Here we use 1200 particles in total, therefore numpar=1200 in LTRANS.data

6. Revise the setup in LTRANS.data
- The location of nc file
```
NCgridfile='./input/ROMS_solution/20080001.nc'
```

- Setting for the ROMS input files
```
$romsoutput
  prefix='./input/ROMS_solution/2008'   ! NetCDF Input Filename prefix
  suffix='.nc'               ! NetCDF Input Filename suffix
  filenum = 0001             ! Number in first NetCDF input filename
  numdigits = 4              ! Number of digits in number portion of file name (with leading zeros)
  startfile = .FALSE.         
$end
```

- LTRANS output path
```
outpath = './output/0.0005/'      ! Location to write output .csv and/or .nc files
```
- rising speed for the buoyant particles
```
sink= 0.0005 ! in m/s
```
7. compile the model (use the correct PATH and LIBDIR for NETCDF and HDF5, see below as an example for LSU supercomputer)
- Here use ifort as the default Fortran compiler
```
export NETCDF=/usr/local/packages/netcdf/4.1.3/Intel-13.0.0
export PATH=/usr/local/packages/netcdf/4.1.3/Intel-13.0.0/bin:$PATH
export NETCDF_LIBDIR=/usr/local/packages/netcdf/4.1.3/Intel-13.0.0/lib
export LD_LIBRARY_PATH=/usr/local/packages/netcdf/4.1.3/Intel-13.0.0/lib:/usr/local/packages/hdf5/1.8.9/Intel-13.0.0/lib/:${LD_LIBRARY_PATH}
export NETCDF_INCDIR=/usr/local/packages/netcdf/4.1.3/Intel-13.0.0/include
export HDF5_INCDIR=/usr/local/packages/hdf5/1.8.9/Intel-13.0.0/include
export HDF5_LIBDIR=/usr/local/packages/hdf5/1.8.9/Intel-13.0.0/lib
make clean
make
```
8. Run the model (the screen output will be saved in jobout.dat)
```
./LTRANS.exe > jobout.dat
```
The output files will be saved in `'./output/0.0005/'`.
## Parameters in LTRANS.data
- __numpar__: total number of partilces
- __sink__: rising speed (positive value) in m/s --- it is used to replace variable `wb` in the subroutine `find_currents` in `LTRANS.f90`

## Implementation of the effect of subsurface currents on buoyant particles in the LTRANS code
- The effective diffusivity k_{xx} and k_{yy} in equations (6a) and (6b) in Liang et al. (2021) are computed in the new subroutine `find_current` in the new `LTRANS.f90` as `k11` and `k22`, which are used to calculate the subgrid-scale displacement `Xgrd` and `Ygrd` [i.e., x_{sgs} and y_{sgs} in equations (5a) and (5b) in Liang et al. (2021)].
- The weighted-averaged velocities, i.e., ubar and vbar in equations (3a) and (3b) in Liang et al. (2021) are calculated and saved in variable `ubar` and `vbar` in the new subroutine `find_current` in the new `LTRANS.f90`, respectively.


For reference, please cite:

J.-H. Liang, J. Liu, M. C. Benfield, D. Justic, D Holstein, B. Liu, R. Hetland, D. Kobashi, C. Dong, and W. Dong, 2021. Including the Effects of Subsurface Currents on Buoyant Particles in Lagrangian Particle Tracking Models: Model Development and its Application to the Study of Riverborne Plastics over the Louisiana/Texas Shelf. Ocean Modelling. Accepted.

- The original LTRANS code was downloaded from this link: https://northweb.hpl.umces.edu/LTRANS.htm.
- The hindcast solutions for circulations in the Louisiana/Texas continental shelf were downloaded from  http://barataria.tamu.edu:8080/thredds/catalog.html.

If you have any questions regarding the model, please feel free to open an issue or send an email to Dr. Jun-Hong Liang (jliang@lsu.edu) at Louisiana State University.
