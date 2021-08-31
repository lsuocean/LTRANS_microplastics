! LTRANS - Larval TRANSport Lagrangian model v.2b                                
! Date: 23 May 2013
!
! Description: The Lagrangian TRANSport model (LTRANS) is an 
! off-line particle-tracking model that runs with the stored predictions of
! a 3D hydrodynamic model, specifically the Regional Ocean Modeling System 
! (ROMS). Although LTRANS was built to simulate oyster larvae, it can  
! be adapted to simulate passive particles and other planktonic organisms. 
! LTRANS is written in Fortran 90 and is designed to track the trajectories 
! of particles in three dimensions. It includes a 4th order Runge-Kutta scheme 
! for particle advection and a random displacement model for vertical turbulent
! particle motion. Reflective boundary conditions, larval behavior, and 
! settlement routines are also included. Components of LTRANS have been in 
! development since 2002 and are described in the following publications:
! North et al. 2004, North et al. 2006a, North et al. 2006b, 
! North et al. 2008, North et al. 2011, Schlag and North 2012.
!
! Developers:
!   Elizabeth North: enorth@umces.edu
!   Zachary Schlag: zschlag@umces.edu
!   Ian Mitchell: imitchell@umces.edu
!
! Mailing Address:  
!   University of Maryland
!   Center for Envir. Science
!   Horn Point Laboratory
!   Cambridge, MD 21613 USA
!
! Funding was provided by the National Science Foundation Biological 
! and Physical Oceanography Programs, Maryland Department of Natural 
! Resources, NOAA Chesapeake Bay Office, NOAA Maryland Sea Grant College 
! Program, & NOAA-funded UMCP Advanced Study Institute for the Environment. 
! 
! **********************************************************************
! **********************************************************************
! **                      Copyright (c) 2013                          **
! **   The University of Maryland Center for Environmental Science    **
! **********************************************************************
! **                                                                  **
! ** This Software is open-source and licensed under the following    **
! ** conditions as stated by MIT/X License:                           **
! **                                                                  **
! **  (See http://www.opensource.org/licenses/mit-license.php ).      **
! **                                                                  **
! ** Permission is hereby granted, free of charge, to any person      **
! ** obtaining a copy of this Software and associated documentation   **
! ** files (the "Software"), to deal in the Software without          **
! ** restriction, including without limitation the rights to use,     **
! ** copy, modify, merge, publish, distribute, sublicense,            **
! ** and/or sell copies of the Software, and to permit persons        **
! ** to whom the Software is furnished to do so, subject to the       **
! ** following conditions:                                            **
! **                                                                  **
! ** The above copyright notice and this permission notice shall      **
! ** be included in all copies or substantial portions of the         **
! ** Software.                                                        **
! **                                                                  **
! ** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,  **
! ** EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE           **
! ** WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE  **
! ** AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT  **
! ** HOLDERS BE LIABLE FOR ANY CLAIMS, DAMAGES OR OTHER LIABILITIES,  **
! ** WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     **
! ** FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR    **
! ** OTHER DEALINGS IN THE SOFTWARE.                                  **
! **                                                                  **
! ** The most current official versions of this Software and          **
! ** associated tools and documentation are available at:             **
! **                                                                  **
! **  http://northweb.hpl.umces.edu/LTRANS.htm                        **
! **                                                                  **
! ** We ask that users make appropriate acknowledgement of            **
! ** The University of Maryland Center for Environmental Science,     **
! ** individual developers, participating agencies and institutions,  **
! ** and funding agencies. One way to do this is to cite one or       **
! ** more of the relevant publications listed at:                     **
! **                                                                  **
! **  http://northweb.hpl.umces.edu/LTRANS.htm#Description            **
! **                                                                  **
! **********************************************************************
! ********************************************************************** 

PROGRAM main

! LTRANS.f90 contains the main structure of the particle-tracking program. 
! It executes the external time step, internal time step, and particle loops, 
! advects particles, and writes output. It calls modules that read in 
! hydrodynamic model information, move particles due to turbulence and 
! behavior, test if particles are in habitat polygons, and apply boundary 
! conditions to keep particles in the model domain. 
!
! Program created by:   Elizabeth North
! Modified by:          Zachary Schlag
! Created on:           2004
! Last Modified on:     7 Mar 2011

IMPLICIT NONE
!   *************************************************************************
!   *                                                                       *
!   *                       Variable Declarations                           *
!   *                                                                       *
!   *************************************************************************

  INTEGER, PARAMETER :: nAttrib   = 13

  INTEGER, PARAMETER :: pX        =  1  ! Particle X-coordinate
  INTEGER, PARAMETER :: pY        =  2  ! Particle Y-coordinate
  INTEGER, PARAMETER :: pZ        =  3  ! Particle Z-coordinate
  INTEGER, PARAMETER :: pnX       =  4  ! Particle new X-coordinate
  INTEGER, PARAMETER :: pnY       =  5  ! Particle new Y-coordinate
  INTEGER, PARAMETER :: pnZ       =  6  ! Particle new Z-coordinate
  INTEGER, PARAMETER :: ppX       =  7  ! Particle previous X-coordinate
  INTEGER, PARAMETER :: ppY       =  8  ! Particle previous Y-coordinate
  INTEGER, PARAMETER :: ppZ       =  9  ! Particle previous Z-coordinate
  INTEGER, PARAMETER :: pStatus   = 10  ! Status of particle (previously Color)
  INTEGER, PARAMETER :: pDOB      = 11  ! Particle Date Of Birth
  INTEGER, PARAMETER :: pAge      = 12  ! Particle Age (s)
  INTEGER, PARAMETER :: pLifespan = 13  ! Age at which particle settled or died

  DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: par
  DOUBLE PRECISION, ALLOCATABLE, DIMENSION( : ) :: P_Salt,P_Temp
  INTEGER, ALLOCATABLE, DIMENSION(:) :: startpoly,endpoly,hitBottom,hitLand

  DOUBLE PRECISION :: ex(3),ix(3)
  INTEGER :: prcount,printdt,p,it
  REAL :: timeCounts(8),times(9)

!   *************************************************************************
!   *                                                                       *
!   *                             Execution                                 *
!   *                                                                       *
!   *************************************************************************

  call run_LTRANS()

contains
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
function inv(A) result(Ainv)
implicit none
  Double precision, dimension(:,:), intent(in) :: A
  Double precision, dimension(size(A,1),size(A,2)) :: Ainv

  Double precision, dimension(size(A,1)) :: work  ! work array for LAPACK
  integer, dimension(size(A,1)) :: ipiv   ! pivot indices
  integer :: n, info

  ! Store A in Ainv to prevent it from being overwritten by LAPACK
  Ainv = A
  n = size(A,1)

! DGETRF computes an LU factorization of a general M-by-N matrix A
  ! using partial pivoting with row interchanges.
  call DGETRF(n, n, Ainv, n, ipiv, info)

  if (info /= 0) then
     stop 'Matrix is numerically singular!'
  end if

  ! DGETRI computes the inverse of a matrix using the LU factorization
  ! computed by DGETRF.
  call DGETRI(n, Ainv, n, ipiv, work, n, info)

  if (info /= 0) then
     stop 'Matrix inversion failed!'
  end if

end function inv

!the Gaussian white noise

FUNCTION ran2(idum)

         INTEGER idum,IM1,IM2,IMM1,IA1,IA2,IQ1,IQ2,IR1,IR2,NTAB,NDIV
         REAL ran2,AM,EPS,RNMX
         PARAMETER (IM1=2147483563,IM2=2147483399,AM=1./IM1,IMM1=IM1-1,&
                    IA1=40014,IA2=40692,IQ1=53668,IQ2=52774,IR1=12211,IR2=3791,&
                     NTAB=32,NDIV=1+IMM1/NTAB,EPS=1.2e-7,RNMX=1.-EPS)
         INTEGER idum2,j,k,iv(NTAB),iy
         SAVE iv,iy,idum2
         DATA idum2/123456789/, iv/NTAB*0/, iy/0/
         if (idum.le.0) then
          idum=max(-idum,1)
          idum2=idum
          do 11 j=NTAB+8,1,-1
            k=idum/IQ1
            idum=IA1*(idum-k*IQ1)-k*IR1
            if (idum.lt.0) idum=idum+IM1
            if (j.le.NTAB) iv(j)=idum
11        continue
          iy=iv(1)
         endif
         k=idum/IQ1
        idum=IA1*(idum-k*IQ1)-k*IR1
        if (idum.lt.0) idum=idum+IM1
        k=idum2/IQ2
        idum2=IA2*(idum2-k*IQ2)-k*IR2
        if (idum2.lt.0) idum2=idum2+IM2
        j=1+iy/NDIV
        iy=iv(j)-idum2
        iv(j)=idum
        if(iy.lt.1)iy=iy+IMM1
         ran2=min(AM*iy,RNMX)
        return
        END function ran2
!-----------------------------------------------------------------------------!
FUNCTION ROMS_EOS(T,S,Z)
! This function is adapted from roms postprocessing code by Hernan G. Arango
! Set equation of state expansion coefficients.
       DOUBLE PRECISION :: A00,A01,A02,A03,A04,B00,B01,B02,B03,D00,D01, &
                           D02,E00,E01,E02,E03,F00,F01,F02,G00,G01,G02, &
                           G03,H00,H01,H02,Q00,Q01,Q02,Q03,Q04,Q05,U00, &
                           U01,U02,U03,U04,V00,V01,V02,W00,grav, &
                           T_TMP,S_TMP,sqrtS,den1,K0,K1,K2,bulk,rho1, &
                           roms_eos
       PARAMETER( &
A00=+19092.56D0,  A01=+209.8925D0,   A02=-3.041638D0,   A03=-1.852732D-3, &
A04=-1.361629D-5, B00=+104.4077D0,   B01=-6.500517D0,   B02=+0.1553190D0, &
B03=+2.326469D-4, D00=-5.587545D0,   D01=+0.7390729D0,  D02=-1.909078D-2, &
E00=+4.721788D-1, E01=+1.028859D-2,  E02=-2.512549D-4,  E03=-5.939910D-7, &
F00=-1.571896D-2, F01=-2.598241D-4,  F02=+7.267926D-6,  G00=+2.042967D-3, &
G01=+1.045941D-5, G02=-5.782165D-10, G03=+1.296821D-7,  H00=-2.595994D-7, &
H01=-1.248266D-9, H02=-3.508914D-9,  Q00=+999.842594D0, Q01=+6.793952D-2, &
Q02=-9.095290D-3, Q03=+1.001685D-4,  Q04=-1.120083D-6,  Q05=+6.536332D-9, &
U00=+0.824493D0,  U01=-4.08990D-3,   U02=+7.64380D-5,   U03=-8.24670D-7,  &
U04=+5.38750D-9,  V00=-5.72466D-3,   V01=+1.02270D-4,   V02=-1.65460D-6,  &
W00=+4.8314D-4, grav = 9.81)
       DOUBLE PRECISION, INTENT(IN) :: T, S, Z
! Compute density (kg/m3) at standard one atmosphere pressure.
T_TMP=DMAX1(-2.0D0,T)
S_TMP=DMAX1(0.D0,S)

sqrtS = sqrt(S_TMP)

den1 = Q00 + Q01*T + Q02*T**2 + Q03*T**3 + Q04*T**4 + Q05*T**5 &
       + U00*S + U01*S*T + U02*S*T**2 + U03*S*T**3 + U04*S*T**4 &
       + V00*S*sqrtS + V01*S*sqrtS*T + V02*S*sqrtS*T**2 + W00*S**2

! Compute secant bulk modulus (bulk = K0 - K1*z + K2*z*z).

K0 = A00 + A01*T + A02*T**2 + A03*T**3 + A04*T**4 + & 
     B00*S + B01*S*T + B02*S*T**2 + B03*S*T**3 + & 
     D00*S*sqrtS + D01*S*sqrtS*T + D02*S*sqrtS*T**2

K1 = E00 + E01*T + E02*T**2 + E03*T**3 + &
     F00*S + F01*S*T + F02*S*T**2 + &
     G00*S*sqrtS

K2 = G01 + G02*T + G03*T**2 + & 
     H00*S + H01*S*T + H02*S*T**2

bulk = K0 - K1*Z + K2*Z**2

! Compute "in situ" density anomaly (kg/m3).

rho1 = (den1*bulk)/(bulk + 0.1D0*Z)
! density anomaly
roms_eos = rho1 - 1000.D0

return
END FUNCTION ROMS_EOS

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! MODEL IRF SUBROUTINES
  subroutine run_LTRANS()
    ! *************************************************************************
    ! *                                                                       *
    ! *                              Run Model                                *
    ! *                                                                       *
    ! *************************************************************************
    use param_mod, only: days,dt
    integer :: seconds,stepT

    call ini_LTRANS()

      write(*,'(/,A)') '****** BEGIN ITERATIONS *******'

      ! days*24*60*60 = total number of seconds to run the model
      ! divide that by dt to get the number of external time steps
      seconds = int(days*86400.0) !Total seconds to run model
      stepT   = seconds/dt        !number of external time steps

      do p=1,stepT
        call run_External_Timestep()
      enddo

    call fin_LTRANS()

  end subroutine run_LTRANS



  subroutine ini_LTRANS()
    ! *************************************************************************
    ! *                                                                       *
    ! *                           Initialize Model                            *
    ! *                                                                       *
    ! *************************************************************************
    use behavior_mod, only: initBehave,setOut,die
    use boundary_mod, only: createBounds,mbounds,ibounds
    use convert_mod,  only: lon2x,lat2y
    use random_mod,   only: init_genrand
    use hydro_mod,    only: initGrid,initHydro,setEle_all,initNetCDF,       &
                      createNetCDF,writeNetCDF
    use param_mod,    only: numpar,days,dt,idt,seed,parfile,settlementon,   &
                      Behavior,TrackCollisions,SaltTempOn,writeNC,          &
                      WriteHeaders,WriteModelTiming,ErrorFlag,getParams

    integer :: n,ele_err
    double precision, allocatable, dimension(:) :: pLon,pLat

    ! Initial Boundary check
    integer :: in_island,inbounds
    double precision:: island

  
  ! ***************************************************************************
  ! *                          Get Parameter Values                           *
  ! ***************************************************************************

    CALL getParams()

    CALL writeModelInfo()

    write(*,*) ' '
    write(*,*) ' *************** LTRANS INITIALIZATION ************** '

  ! ***************************************************************************
  ! *                       Allocate Dynamic Variables                        *
  ! ***************************************************************************

    ALLOCATE(par(numpar,nAttrib))

    IF(SettlementOn)THEN
      ALLOCATE(startpoly(numpar))
      ALLOCATE(endpoly(numpar))
      endpoly = 0               !initialize end polygon location to zero
    ENDIF

    IF(SaltTempOn)THEN
      ALLOCATE(P_Salt(numpar))
      ALLOCATE(P_Temp(numpar))
      P_Salt = 0.0
      P_Temp = 0.0
    ENDIF

    IF(TrackCollisions)THEN
      ALLOCATE(hitBottom(numpar))
      ALLOCATE(hitLand(numpar))
      hitBottom = 0
      hitLand = 0
    ENDIF

    !Local variables for read-in of Latitude and Longitude
    ALLOCATE(pLon(numpar))
    ALLOCATE(pLat(numpar))

    ! *************************************************************************
    ! *         Initialize print counters and random number generator         *
    ! *************************************************************************

    ! THE FOLLOWING VARIABLE INITIALIZATIONS SHOULD NOT BE CHANGED:
    prcount=0                  !print counter; number of external time steps
    printdt=0                  !print counter
    CALL init_genrand(seed)    !set random number generator Seed Value

  
    ! *************************************************************************
    ! *                   Initialize Particle Attributes                      *
    ! *************************************************************************

    ! Read-in lat/long of particles. If settlement module is on, read in    
    ! the habitat polygon on which the particle start                       
    write(*,*) 'read in particle locations', numpar

    OPEN(1,FILE=TRIM(parfile))

      do n=1,numpar
        if(settlementon)then
          read (1,*) pLon(n),pLat(n),par(n,pZ),par(n,pDOB),startpoly(n)
        else
          read (1,*) pLon(n),pLat(n),par(n,pZ),par(n,pDOB)
        endif
        par(n,pX)  = lon2x(pLon(n),pLat(n))
        par(n,pY)  = lat2y(pLat(n))
        par(n,pnX) = par(n,pX)
        par(n,pnY) = par(n,pY)
        par(n,pnZ) = par(n,pZ)
        par(n,ppX) = 0.0    !initialize to 0.0 to indicate no previous location
        par(n,ppY) = 0.0    !initialize to 0.0 to indicate no previous location
        par(n,ppZ) = 0.0    !initialize to 0.0 to indicate no previous location
        par(n,pStatus)   = Behavior
        par(n,pAge)      = 0.0
        par(n,pLifespan) = 0.0
      enddo

    CLOSE(1)

    write(*,*) '  Particle n=5 Latitude=',pLat(5),'Longitude=',pLon(5)
    write(*,*) '  Particle n=5 Depth=',par(5,pZ)
    write(*,*) '  Particle n=5 X=',par(5,pX),'Y=',par(5,pY)
    if(settlementon) write(*,*) '  Particle n=5 Start Polygon=',startpoly(5)

  
    ! *******************************************************************
    ! *                    Initialize NetCDF Output                     *
    ! *******************************************************************

    !Create NetCDF Output File if Needed
    IF(writeNC) then
      CALL initNetCDF()
      CALL createNetCDF(par(:,pDOB))
    ENDIF

    prcount = 1
    if(writeNC)then !Write to NetCDF Output File
      if (SaltTempOn) then
        if(TrackCollisions)then
          CALL writeNetCDF(0,par(:,pAge),pLon,pLat,par(:,pZ),par(:,pStatus),   &
                          SALT=P_Salt,TEMP=P_Temp,HITB=hitBottom,HITL=hitLand)
        else
          CALL writeNetCDF(0,par(:,pAge),pLon,pLat,par(:,pZ),par(:,pStatus),   &
                          SALT=P_Salt,TEMP=P_Temp)
        endif
      else
        if(TrackCollisions)then
          CALL writeNetCDF(0,par(:,pAge),pLon,pLat,par(:,pZ),par(:,pStatus),   &
                          HITB=hitBottom,HITL=hitLand)
        else
          CALL writeNetCDF(0,par(:,pAge),pLon,pLat,par(:,pZ),par(:,pStatus))
        endif
      endif
    endif

  
    ! *************************************************************************
    ! *                                                                       *
    ! *           Initial Read-In of Hydrodynamic Model Information           *
    ! *                                                                       *
    ! *************************************************************************

    !Initialize Grid / Create Elements
    CALL initGrid()

  
    ! *************************************************************************
    ! *                                                                       *
    ! *                      Prepare for Particle Tracking                    *
    ! *                                                                       *
    ! *************************************************************************

    write(*,*) 'prepare boundary arrays'

    !Create Boundaries
    CALL createBounds()

    !Initialize Behavior
    CALL initBehave()

    !Create file to output information if a problem is encountered
    SELECT CASE(ErrorFlag)
    CASE(1)
      OPEN(210,FILE='ErrorLog.txt',STATUS='REPLACE')
        write(210,*) &
          'The following particles were returned to their previous locations:'
        write(210,*) ' '
      CLOSE(210)
    CASE(2)
      OPEN(210,FILE='ErrorLog.txt',STATUS='REPLACE')
        write(210,*) 'The following particles were killed:'
        write(210,*) ' '
      CLOSE(210)
    CASE(3)
      OPEN(210,FILE='ErrorLog.txt',STATUS='REPLACE')
        write(210,*) 'The following particles were set out of bounds:'
        write(210,*) ' '
      CLOSE(210)
    END SELECT

    !Get Start Elements
    write(*,*) "finding each particle's initial element"
    do n=1,numpar

      inbounds = 0
      !Determine if particle is within model bounadaries
      call mbounds(par(n,pY),par(n,pX),inbounds)
      if (inbounds.EQ.0) then 
        if(ErrorFlag < 1 .OR. ErrorFlag > 3)then
          write(*,*) 'Particle initial location outside main bounds, n=',n
          write(*,*) 'x:   ',par(n,pX),' y:   ',par(n,pY)
          write(*,*) 'lon: ',pLon(n)  ,' lat: ',pLat(n)
          write(*,*) ' '
          write(*,*) 'The Program Cannot Continue and is Terminating'
          stop
        else
          if(ErrorFlag == 2)then
            call die(n)
          else
            call setOut(n)
          endif
          OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
            write(210,"('Particle ',I10,' initially outside main bounds')") n
          CLOSE(210)
          cycle
        endif
      endif

      in_island = 0
      call ibounds(in_island,par(n,pY),par(n,pX),island)
      if (in_island.EQ.1) then
        if(ErrorFlag < 1 .OR. ErrorFlag > 3)then
          write(*,*) 'Particle initial location is within an island, n=',n
          write(*,*) 'x:   ',par(n,pX),' y:   ',par(n,pY)
          write(*,*) 'lon: ',pLon(n)  ,' lat: ',pLat(n)
          write(*,*) ' '
          write(*,*) 'The Program Cannot Continue and is Terminating'
          stop
        else
          if(ErrorFlag == 2)then
            call die(n)
          else
            call setOut(n)
          endif
          OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
            write(210,"('Particle ',I10,' initially inside island bounds')") n
          CLOSE(210)
          cycle
        endif
      endif

    enddo

    !Determine which Rho, U, & V elements the particles are in
    CALL setEle_all(par(:,pX),par(:,pY),ele_err,n)

    !If the particle was not found to be within an element,
    ! write a message to the screen and discontinue the program
    IF(ele_err > 0)THEN
      if(ErrorFlag < 1 .OR. ErrorFlag > 3)then

        write(*,*) " "

        SELECT CASE (ele_err)
          CASE(1)
            write(*,*) n,' start - particle not inside any rho element'
          CASE(2)
            write(*,*) n,' start - particle not inside any u element'
          CASE(3)
            write(*,*) n,' start - particle not inside any v element'
        END SELECT

        write(*,*) ' '
        write(*,*) ' - Now Stopped - '
        write(*,*) ' '
        write(*,*) 'Current Location:'
        write(*,*) '  x:   ',par(n,pX),  ' y:   ',par(n,pY)
        write(*,*) '  lon: ',pLon(n),' lat: ',pLat(n)
        write(*,*) ' '
        write(*,*) 'The Program Cannot Continue and Will Terminate'
        stop
      else
        if(ErrorFlag == 2)then
          call die(n)
        else
          call setOut(n)
        endif
        OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
          SELECT CASE (ele_err)
            CASE(1)
              write(210,"('Particle ',I10,' initially not in rho element')") n
            CASE(2)
              write(210,"('Particle ',I10,' initially not in u element')") n
            CASE(3)
              write(210,"('Particle ',I10,' initially not in v element')") n
          END SELECT
        CLOSE(210)
      endif
    ENDIF

    !Read in initial hydrodynamic model data
    CALL initHydro()

    !Create files to output 'land hits' and 'bottom hits'
    IF(TrackCollisions) then
      OPEN(100,FILE='LandHits.csv',STATUS='REPLACE')
        write(100,*)'numpar,lon,lat,depth,age,time,hitLand'
      CLOSE(100)
      OPEN(101,FILE='BottomHits.csv',STATUS='REPLACE')
        write(101,*)'numpar,lon,lat,depth,age,time,hitBottom'
      CLOSE(101)
    ENDIF

  
    !Create file to track model timing
    IF(WriteModelTiming)then
      OPEN(300,FILE='Timing.csv',STATUS='REPLACE')
        write(300,*)'Daytime,Elapsed,Hydro,Hydro %,Set Up,Set Up %,',     &
        'Advection,Advection %,HTurb,HTurb %,VTurb,VTurb %,Behavior,',    &
        'Behavior %,Update,Update %'
      CLOSE(300)

    ENDIF

    !Create files with Header Information
    IF(WriteHeaders)then
      OPEN(100,FILE='para_Headers.txt',STATUS='REPLACE')
        write(100,*)'column 01: depth   -Depth of particle at end of time ',   &
                    'step (meters)'
        write(100,*)'column 02: color   -integer value to indicate the ',      &
                    'status of the particle'
        write(100,*)'column 03: lon     -Longitude of particle at end of ',    &
                    'time step (decimal �)'
        write(100,*)'column 04: lat     -Latitude  of particle at end of ',    &
                    'time step (decimal �)'
        IF(SaltTempOn)then
          write(100,*)'column 05: salt    -Salinity at particle location at ', &
                    'end of time step'
          write(100,*)'column 06: temp    -Temperature at particle location ', &
                    'at end of time step (�C)'
        ENDIF
      CLOSE(100)

      IF(TrackCollisions)then
        OPEN(100,FILE='LandHits_Headers.txt',STATUS='REPLACE')
          write(100,*)'column 01: numpar  -Particle identification number ',   &
                      '(dimensionless)'
          write(100,*)'column 02: lon     -Longitude of particle at end of ',  &
                      'time step (decimal �)'
          write(100,*)'column 03: lat     -Latitude  of particle at end of ',  &
                      'time step (decimal �)'
          write(100,*)'column 04: depth   -Depth of particle at end of time ', &
                      'step (meters)'
          write(100,*)'column 05: age     -Age of particle (in days since ',   &
                      'released)'
          write(100,*)'column 06: time    -Model time (in days since the ',    &
                      'start of the model)'
          write(100,*)'column 07: hitLand -Number of times the particle ',     &
                      'struck land in the last print interval time step'
        CLOSE(100)

        OPEN(101,FILE='BottomHits_Headers.txt',STATUS='REPLACE')
          write(101,*)'column 01: numpar    -Particle identification number ', &
                      '(dimensionless)'
          write(101,*)'column 02: lon       -Longitude of particle at end ',   &
                      'of time step (decimal �)'
          write(101,*)'column 03: lat       -Latitude  of particle at end ',   &
                      'of time step (decimal �)'
          write(101,*)'column 04: depth     -Depth of particle at end of ',    &
                      'time step (meters)'
          write(101,*)'column 05: age       -Age of particle (in days since ', &
                      'released)'
          write(101,*)'column 06: time      -Model time (in days since the ',  &
                      'start of the model)'
          write(101,*)'column 07: hitBottom -Number of times the particle ',   &
                      'struck bottom in the last print interval time step'
        CLOSE(101)
      ENDIF
    ENDIF

    !Deallocate local variables
    DEALLOCATE(pLon,pLat)

    !Output time spent initializing model
    call CPU_TIME(times(1))
    write(*,'("Time to initialize model = ",f6.3," seconds.")') times(1)
    timeCounts = 0.0      !Initialize time counters to 0.0

  end subroutine ini_LTRANS

  

  subroutine run_External_Timestep()
    use param_mod, only: dt,idt,WriteModelTiming
    use hydro_mod, only: updateHydro
    integer :: stepIT
    real :: before,after

      stepIT  = int(dt/idt)                     !number of internal time steps

      IF(WriteModelTiming) call CPU_TIME(before)

      !Read in hydrodynamic model data 
      IF(p > 2) CALL updateHydro()   !do not start updating until 3rd iteration

      IF(WriteModelTiming) then
        call CPU_TIME(after)
        timeCounts(1) = timeCounts(1) + (after-before)
      ENDIF

      !Prepare external time step values to be used for 
      !  calculating Advection and Turbulence
      ex=0.0
      ex(1) = (p-2)*dt
      ex(2) = (p-1)*dt
      ex(3) = p*dt

      do it=1,stepIT

        call run_Internal_Timestep()

      enddo !ITloop

  end subroutine run_External_Timestep



  subroutine run_Internal_Timestep()
    use param_mod, only: idt,iPrint

    !Prepare internal time step values to be used for 
    !  calculating Advection and Turbulence
    ix(1) = ex(2) + DBLE((it-2)*idt)
    ix(2) = ex(2) + DBLE((it-1)*idt)
    ix(3) = ex(2) + DBLE(it*idt)

    !********************************************************
    !*                    Particle Loop                     *
    !********************************************************

    call update_particles()

    !********************************************************
    !*                 PRINT OUTPUT TO FILE                 *
    !********************************************************

    printdt=printdt+idt

    if(printdt.GE.iprint) then
      write(*,*) 'write output to file, day = ',(DBLE(ix(3))/DBLE(86400))
      !ix(3)/86400 = (current model time in seconds) /
      !              (# of seconds in a day)

      call printOutput()

      printdt=0  !reset print counter
    endif

  end subroutine run_Internal_Timestep  



  subroutine fin_LTRANS()
    use param_mod, only: numpar,writeCSV,outpathGiven,outpath,settlementon
    use behavior_mod, only: finBehave,getStatus
    use convert_mod, only: x2lon,y2lat
    use hydro_mod, only: finHydro

    !OUTPUT ENDFILE NAME CONSTRUCTION VARIABLE
    CHARACTER(LEN=100) :: efile

    integer :: n,d,h,m
    real :: fintime,s
    double precision :: pLon,pLat

    !Write final positions and status to endfile.csv
    IF(writeCSV)THEN

      if(outpathGiven)then
        efile = TRIM(outpath) // 'endfile.csv'
      else
        efile = 'endfile.csv'
      endif 

      write(*,*) 'write endfile.csv'

      open(3,FILE=efile,STATUS='REPLACE')
        3 format(I7,',',I7,',',I7,',', F9.4,",",F9.4,",",I7)
        4 format(I7,',',F9.4,',',F9.4,',',I7)
        do n=1,numpar
          pLon = x2lon(par(n,pX),par(n,pY))
          pLat = y2lat(par(n,pY))
          par(n,pStatus) = getStatus(n)
          if(settlementon)then
            write(3,3) startpoly(n),endpoly(n),int(par(n,pStatus)),pLat,pLon,  &
                       int(par(n,pLifespan))
          else
            write(3,4) int(par(n,pStatus)),pLat,pLon,int(par(n,pLifespan))
          endif
        enddo
      close(3)

    ENDIF

    !DEALLOCATE LOCAL VARIABLES
    DEALLOCATE(par)
    IF(ALLOCATED(hitBottom)) DEALLOCATE(hitBottom)
    IF(ALLOCATED(startpoly)) DEALLOCATE(startpoly)
    IF(ALLOCATED(endpoly  )) DEALLOCATE(endpoly)
    IF(ALLOCATED(hitLand  )) DEALLOCATE(hitLand)
    IF(ALLOCATED(P_Salt   )) DEALLOCATE(P_Salt)
    IF(ALLOCATED(P_Temp   )) DEALLOCATE(P_Temp)

    !DEALLOCATE MODULE VARIABLES
    call finBehave()
    call finHydro()

    !Calculate model run time and output to screen before exiting
    call CPU_TIME(fintime)
    d = int(fintime/86400.0)             !# of full days that the model ran
    h = int((fintime - real(d*86400))/3600.0)       !# of hours   (minus days)
    m = int((fintime - real(d*86400 - h*3600))/60.0)!# of minutes (minus days and hours)
    s =  fintime - REAL(d*86400) - REAL(h*3600) - REAL(m*60) !# of seconds (- days, hrs and mins)

    11 format('Time to run model = ',i2,' days ',i2,' hours ',i2,              &
              ' minutes and ',f6.3,' seconds.')
    12 format('Time to run model = ',i2,' hours ',i2,' minutes and ',f6.3,     &
              ' seconds.')
    13 format('Time to run model = ',i2,' minutes and ',f6.3,' seconds.')
    14 format('Time to run model = ',f6.3,' seconds.')

    if(fintime > 86400.0)then
      write(*,11) d,h,m,s
    elseif(fintime > 3600.0)then
      write(*,12) h,m,s
    elseif(fintime > 60.0)then
      write(*,13) m,s
    else
      write(*,14) fintime
    endif

    write(*,'(/,A)') '****** END LTRANS *******'

  end subroutine fin_LTRANS

  

  

  

  subroutine update_particles()

    USE PARAM_MOD,      ONLY: numpar,us,ws,idt,HTurbOn,VTurbOn,settlementon,   &
                              Behavior,SaltTempOn,OpenOceanBoundary,Swimdepth, &
                              TrackCollisions,WriteModelTiming,mortality,      &
                              ErrorFlag,sink,seed
    USE SETTLEMENT_MOD, ONLY: isSettled,testSettlement
    USE BEHAVIOR_MOD,   ONLY: updateStatus,behave,setOut,isOut,isDead,die
    USE BOUNDARY_MOD,   ONLY: mbounds,ibounds,intersect_reflect
    USE CONVERT_MOD,    ONLY: x2lon,y2lat
    USE HTURB_MOD,      ONLY: HTurb
    USE VTURB_MOD,      ONLY: VTurb
    USE INT_MOD,        ONLY: polintd
    USE HYDRO_MOD,      ONLY: setEle,setInterp,getInterp,getSlevel,getWlevel,  &
                              WCTS_ITPI

    IMPLICIT NONE

    ! Iteration Variables
    INTEGER :: i,deplvl,n

    ! Particle tracking
    DOUBLE PRECISION, ALLOCATABLE, DIMENSION( : ) :: Pwc_zb,Pwc_zc,Pwc_zf
    DOUBLE PRECISION, ALLOCATABLE, DIMENSION( : ) :: Pwc_wzb,Pwc_wzc,Pwc_wzf
    DOUBLE PRECISION :: Xpar,Ypar,Zpar,newXpos,newYpos,newZpos,P_zb,P_zc,P_zf, &
      P_depth,P_angle,P_zeta,P_zetab,P_zetac,P_zetaf,ey(3)
    
    ! Behavior and Turbulence
    DOUBLE PRECISION :: TurbHx,TurbHy,TurbV,Behav,XBehav,YBehav,ZBehav
    LOGICAL :: bott   ! for Behavior 7 along with XBehav,YBehav,ZBehav

    ! Boundaries
    INTEGER :: intersectf,skipbound,in_island,inbounds,reflects,inpoly
    DOUBLE PRECISION :: reflect,fintersectX,fintersectY,freflectX,freflectY,   &
      Xpos,Ypos,nXpos,nYpos,island
    LOGICAL :: isWater,waterFlag

    ! Advection
    DOUBLE PRECISION :: AdvectX,AdvectY,AdvectZ,maxpartdepth,minpartdepth,     &
      kn1_u,kn1_v,kn1_w,kn2_u,kn2_v,kn2_w,kn3_u,kn3_v,kn3_w,kn4_u,kn4_v,kn4_w, &
      P_V,P_U,P_W,UAD,VAD,WAD,x1,x2,x3,y1,y2,y3,z1,z2,z3

!!!!!!!!!!!!!!!!!!!!!!!!!!!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
    ! K effective
    Double Precision , parameter :: pi=3.14159265358979
    DOUBLE PRECISION :: uu(us),vv(us),kv(us+1),zz(us+1),zz1(us),Aks(us+1),Zw(us+1),Zw1(us+1),tt(us),tt1(us)
!    Integer , parameter :: nnz=41
!    Double Precision , parameter :: u10=10,cd=1.2e-3,grav=9.81,c2=0.7
    Integer :: iz,values(8),seedi,ii,j,k,bc
    Double Precision :: dz1,dz2,dz3,AA(us,us),AAi(us,us),F(us),bb(us),wb,ubar,vbar!hbl,hek,c1,u19p5,iwb,ustar,fcor
!    Double Precision :: uu1(us),vv1(us),tm1(us,us),ust(us),vst(us),bb2(us),AA1(us,us),AA2(us,us),bb1(us),gsigma(us+1),omegap,kp
!AA2(nnz,nnz),bb2(nnz) 

    Double Precision :: uu1(us),vv1(us)!,MM(us),NN(us)!,AA3(us+2,us+2),bb3(us+2),AAi3(us+2,us+2),MM(us),NN(us)
    Double Precision :: sum1,sum2,sum3,sum4,k11,k12,k22,kmax,kmin,kdir,Xsgs,Ysgs,Xdis,Ydis,Xgrd,Ygrd
    Double Precision :: tmp3,tmp4,dksi,sumbb,C!apex
!
   Double Precision ::  kn1_Xdis,kn1_Ydis,kn2_Xdis,kn2_Ydis,kn3_Xdis,kn3_Ydis,kn4_Xdis,kn4_Ydis

!    Double precision, parameter :: Keff=5.0
!!!!!!!!!!!!!!!!!!!!!!!!!!!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
    ! Error Handling Variables
    INTEGER :: ele_err

    !Allocate Dynamic Variables
    ALLOCATE(Pwc_zb(us))
    ALLOCATE(Pwc_zc(us))
    ALLOCATE(Pwc_zf(us))
    ALLOCATE(Pwc_wzb(ws))
    ALLOCATE(Pwc_wzc(ws))
    ALLOCATE(Pwc_wzf(ws))

    !Error Handling Formats
    21 FORMAT ('Particle ',I10,' not in rho element after ',I10,' seconds')
    22 FORMAT ('Particle ',I10,' not in u element after '  ,I10,' seconds')
    23 FORMAT ('Particle ',I10,' not in v element after '  ,I10,' seconds')
    24 FORMAT ('Particle ',I10,' out after 3rd reflection after ',I10,         &
               ' seconds')
    25 FORMAT ('Particle ',I10,                                                &
               ' outside main bounds after intersect_reflect after ',I10,      &
               ' seconds')
    26 FORMAT ('Particle ',I10,                                                &
               ' inside island bounds after intersect_reflect after ',I10,     &
               ' seconds')
    27 FORMAT ('Particle ',I10,' jumped over rho element after ',I10,          &
               ' seconds')
    28 FORMAT ('Particle ',I10,' jumped over u element after ',I10,' seconds')
    29 FORMAT ('Particle ',I10,' jumped over v element after ',I10,' seconds')


    DO n=1,numpar

      IF(WriteModelTiming) call CPU_TIME(times(2))

      ! *********************************************************
      ! *                                                       *
      ! *        Update Particle Age and Characteristics        *
      ! *                                                       *
      ! *********************************************************

      !If the particle is not yet released, set new location to 
      !  current location, and cycle to next particle
      if(ix(3) <= par(n,pDOB))then
        par(n,pnX) = par(n,pX)
        par(n,pnY) = par(n,pY)
        par(n,pnZ) = par(n,pZ)
        cycle
      endif

      !Update particle age
      par(n,pAge) = par(n,pAge) + float(idt)

      !Update particle status if settled or dead
      CALL updateStatus(par(n,pAge),n)

      !If particle settled or dead, skip tracking
      if(settlementon)then
        if ( isSettled(n) ) cycle
      endif

      if(mortality)then
        if ( isDead(n) ) cycle
      endif

      !If there are open ocean boundaries and the current
      !  particle has exited the model domain via them, skip it
      if(OpenOceanBoundary)then
        if(isOut(n)) cycle
      endif

      ! *********************************************************
      ! *                                                       *
      ! *          Find Element that Contains Particle          *
      ! *                                                       *
      ! *********************************************************

      !Find rho/u/v elements in which the particle is located.

      Xpar = par(n,pX)
      Ypar = par(n,pY)
      !Determine which Rho, U, & V elements the particle is in
      CALL setEle(Xpar,Ypar,n,ele_err)

      !If the particle was not found to be within an element,
      !  write a message to the screen and discontinue the program
      IF(ele_err > 0)THEN
        if(ErrorFlag < 1 .OR. ErrorFlag > 3)then
          write(*,*) " "
          SELECT CASE (ele_err)
            CASE(4)
              write(*,*) n,' Jumped over a rho element'
            CASE(5)
              write(*,*) n,' Jumped over a u element'
            CASE(6)
              write(*,*) n,' Jumped over a v element'
          END SELECT
          write(*,*) ' '
          write(*,*) 'Previous Location:'
          write(*,*) '  x:   ',par(n,ppX), ' y:   ',par(n,ppY)
          write(*,*) '  lon: ',x2lon(par(n,ppX),par(n,ppY)),         &
                     ' lat: ',y2lat(par(n,ppY))
          write(*,*) ' '
          write(*,*) 'Current Location:'
          write(*,*) '  x:   ',Xpar,            ' y:   ',Ypar
          write(*,*) '  lon: ',x2lon(Xpar,Ypar),' lat: ',y2lat(Ypar)
          write(*,*) ' '
          write(*,*) 'The Program Cannot Continue and Will Terminate'
          stop
        else
          if(ErrorFlag == 1)then
            par(n,pnX) = par(n,pX)
            par(n,pnY) = par(n,pY)
            par(n,pnZ) = par(n,pZ)
          elseif(ErrorFlag == 2)then
            call die(n)
          else
            call setOut(n)
          endif
          OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
            SELECT CASE (ele_err)
              CASE(4)
                write(210,21) n,ix(3)
              CASE(5)
                write(210,22) n,ix(3)
              CASE(6)
                write(210,23) n,ix(3)
            END SELECT
          CLOSE(210)
          cycle
        endif
      ENDIF

      !Set Interpolation Values for the current particle
      CALL setInterp(Xpar,Ypar)

      ! *********************************************************
      ! *                                                       *
      ! *       Ensure Particle is Within Verticle Bounds       *
      ! *                                                       *
      ! *********************************************************

      !Find depth, angle, and sea surface height at particle location

      P_depth = DBLE(-1.0)* getInterp("depth")
      P_angle = getInterp("angle")
      P_zetab = getInterp("zetab")
      P_zetac = getInterp("zetac")
      P_zetaf = getInterp("zetaf")

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!print *,'previous location'
!write(*,*) '  x:   ',par(n,ppX), ' y:   ',par(n,ppY)

!print *,'current location'
!write(*,*) '  lon: ',x2lon(Xpar,Ypar),' lat: ',y2lat(Ypar)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!



      !Check if particle location above or below boundary, If so, place
      !  just within boundary (1 mm)
      if (par(n,pZ).LT.P_depth) then
        par(n,pZ) = P_depth + DBLE(0.001)
        IF(TrackCollisions) hitBottom(n) = hitBottom(n) + 1
      endif
      P_zb = par(n,pZ)
      P_zc = par(n,pZ)
      P_zf = par(n,pZ)
      if (par(n,pZ).GT.P_zetab) P_zb = P_zetab - DBLE(0.001)
      if (par(n,pZ).GT.P_zetac) P_zc = P_zetac - DBLE(0.001)
      if (par(n,pZ).GT.P_zetaf) P_zf = P_zetaf - DBLE(0.001)

      ey(1) = P_zb
      ey(2) = P_zc
      ey(3) = P_zf
      Zpar = polintd(ex,ey,3,ix(2))

      ey(1) = P_zetab
      ey(2) = P_zetac
      ey(3) = P_zetaf
      P_zeta = polintd(ex,ey,3,ix(2))
	  
	  !update particle
      par(n,pZ) = Zpar
	  

  
      ! *********************************************************
      ! *                                                       *
      ! *             Create Matrix of Z-coordinates            *
      ! *                                                       *
      ! *********************************************************

      !Create matrix of z-coordinates at particle and at each node for
      !  back, center, forward times
      do i=1,us

        !Rho-coordinate depths at particle location
        Pwc_zb(i)=getSlevel(P_zetab,P_depth,i)
        Pwc_zc(i)=getSlevel(P_zetac,P_depth,i)
        Pwc_zf(i)=getSlevel(P_zetaf,P_depth,i)

        !W-coordinate depths at particle location
        Pwc_wzb(i)= getWlevel(P_zetab,P_depth,i)
        Pwc_wzc(i)= getWlevel(P_zetac,P_depth,i)
        Pwc_wzf(i)= getWlevel(P_zetaf,P_depth,i)

      enddo
      !W-coordinate depths at particle location (cont.)
      Pwc_wzb(i)= getWlevel(P_zetab,P_depth,ws)
      Pwc_wzc(i)= getWlevel(P_zetac,P_depth,ws)
      Pwc_wzf(i)= getWlevel(P_zetaf,P_depth,ws)

      do i=1,us
        if ((Zpar .LT. Pwc_zb(i)) .OR. &   
            (Zpar .LT. Pwc_zc(i)) .OR. &
            (Zpar .LT. Pwc_zf(i))      ) exit
      enddo

      ! *********************************************************
      ! *                                                       *
      ! *             Prepare for Particle Movement             *
      ! *                                                       *
      ! *********************************************************

      AdvectX = 0.0
      AdvectY = 0.0
      AdvectZ = 0.0
      TurbHx = 0.0
      TurbHy = 0.0
      TurbV = 0.0
      Behav = 0.0

      ! *********************************************************
      ! *                                                       *
      ! *                       ADVECTION                       *
      ! *                                                       *
      ! *********************************************************

      IF(WriteModelTiming) call CPU_TIME(times(3))

      maxpartdepth = Pwc_wzb(1)
      if(Pwc_wzc(1) .GT. maxpartdepth) maxpartdepth = Pwc_wzc(1)
      if(Pwc_wzf(1) .GT. maxpartdepth) maxpartdepth = Pwc_wzf(1)

      minpartdepth = Pwc_wzb(ws)
      if(Pwc_wzc(ws) .LT. minpartdepth) minpartdepth = Pwc_wzc(ws)
      if(Pwc_wzf(ws) .LT. minpartdepth) minpartdepth = Pwc_wzf(ws)

      !Find advection currents at original coordinates
      CALL find_currents(Xpar,Ypar,Zpar,Pwc_zb,Pwc_zc,Pwc_zf,      &
        Pwc_wzb,Pwc_wzc,Pwc_wzf,P_zb,P_zc,P_zf,ex,ix,p,1,Uad,Vad,Wad, &
        sink,ubar,vbar,k11,k12,k22)
     
      call date_and_time(VALUES=values)
      seedi = values(8)+values(7)+values(6)

1      tmp3 = ran2(seedi)
      if (tmp3.lt.1e-6) goto 1
        tmp4 = ran2(seedi)
        dksi = sqrt(-2.*log(tmp3))*sin(2*pi*tmp4) * sqrt(float(idt))

      Xgrd=dksi*(2.0*k11)**(0.5)
      Ygrd=dksi*(2.0*k22)**(0.5)
      kn1_Xdis = Xgrd*cos(P_angle)-Ygrd*sin(P_angle)
      kn1_Ydis = Xgrd*sin(P_angle)+Ygrd*cos(P_angle)


      !Store advection currents at original coordinates
      kn1_u = ubar 
      kn1_v = vbar
      kn1_w = 0 !Wad

      !Estimate new coordinates for next RK position
      x1 = Xpar + (ubar*cos(P_angle) - vbar*sin(P_angle)) * DBLE(idt)/DBLE(2) &
                + kn1_Xdis/sqrt(DBLE(2))
      y1 = Ypar + (ubar*sin(P_angle) + vbar*cos(P_angle)) * DBLE(idt)/DBLE(2) &
                + kn1_Ydis/sqrt(DBLE(2))
      z1 = Zpar !+  Wad * DBLE(idt)/DBLE(2) 
      if(z1 .GT. minpartdepth) z1 = minpartdepth - DBLE(0.000001)
      if(z1 .LT. maxpartdepth) z1 = maxpartdepth + DBLE(0.000001)

      !Find advection currents at estimated next RK position
      CALL find_currents(x1,y1,z1,Pwc_zb,Pwc_zc,Pwc_zf,Pwc_wzb,Pwc_wzc,        &
                         Pwc_wzf,P_zb,P_zc,P_zf,ex,ix,p,2,Uad,Vad,Wad,         &
                         sink,ubar,vbar,k11,k12,k22)

      Xgrd=dksi*(2.0*k11)**(0.5)
      Ygrd=dksi*(2.0*k22)**(0.5)
      kn2_Xdis = Xgrd*cos(P_angle)-Ygrd*sin(P_angle)
      kn2_Ydis = Xgrd*sin(P_angle)+Ygrd*cos(P_angle)

      !Store advection currents at 2nd RK position
      kn2_u = ubar 
      kn2_v = vbar 
      kn2_w = 0

      !Estimate new coordinates for next RK position
      x2 = Xpar + (ubar*cos(P_angle) - vbar*sin(P_angle)) * DBLE(idt)/DBLE(2) &
                + kn2_Xdis/sqrt(DBLE(2))
      y2 = Ypar + (ubar*sin(P_angle) + vbar*cos(P_angle)) * DBLE(idt)/DBLE(2) &
                + kn2_Ydis/sqrt(DBLE(2))
      z2 = Zpar !+  Wad * DBLE(idt)/DBLE(2)
      if(z2 .GT. minpartdepth) z2 = minpartdepth - DBLE(0.000001)
      if(z2 .LT. maxpartdepth) z2 = maxpartdepth + DBLE(0.000001)

      !Find advection currents at estimated next RK position
      CALL find_currents(x2,y2,z2,Pwc_zb,Pwc_zc,Pwc_zf,Pwc_wzb,Pwc_wzc,        &
                         Pwc_wzf,P_zb,P_zc,P_zf,ex,ix,p,2,Uad,Vad,Wad,         &
                         sink,ubar,vbar,k11,k12,k22)
!
      Xgrd=dksi*(2.0*k11)**(0.5)
      Ygrd=dksi*(2.0*k22)**(0.5)
      kn3_Xdis = Xgrd*cos(P_angle)-Ygrd*sin(P_angle)
      kn3_Ydis = Xgrd*sin(P_angle)+Ygrd*cos(P_angle)

      !Store advection currents at 3rd RK position
      kn3_u = ubar
      kn3_v = vbar
      kn3_w = 0

      !Calculate the coordinates at the final position
      x3 = Xpar + (ubar*cos(P_angle) - vbar*sin(P_angle)) * DBLE(idt) &
                + kn3_Xdis
      y3 = Ypar + (ubar*sin(P_angle) + vbar*cos(P_angle)) * DBLE(idt) &
                + kn3_Ydis
      z3 = Zpar !+ Wad * DBLE(idt)
      if(z3 .GT. minpartdepth) z3 = minpartdepth - DBLE(0.000001)
      if(z3 .LT. maxpartdepth) z3 = maxpartdepth + DBLE(0.000001)
!goto 321
      !Find advection currents at the final position
      CALL find_currents(x3,y3,z3,Pwc_zb,Pwc_zc,Pwc_zf,Pwc_wzb,Pwc_wzc,        &
                         Pwc_wzf,P_zb,P_zc,P_zf,ex,ix,p,3,Uad,Vad,Wad,         &
                         sink,ubar,vbar,k11,k12,k22)

      Xgrd=dksi*(2.0*k11)**(0.5)
      Ygrd=dksi*(2.0*k22)**(0.5)
      kn4_Xdis=Xgrd*cos(P_angle)-Ygrd*sin(P_angle)
      kn4_Ydis=Xgrd*sin(P_angle)+Ygrd*cos(P_angle)

      !Store advection currents at final position
      kn4_u = ubar
      kn4_v = vbar 
      kn4_w = 0

      !Use the RK formula to get the final Advection values
      P_U = (kn1_u + DBLE(2.0)*kn2_u + DBLE(2.0)*kn3_u + kn4_u)/DBLE(6.0)
      P_V = (kn1_v + DBLE(2.0)*kn2_v + DBLE(2.0)*kn3_v + kn4_v)/DBLE(6.0)
      P_W = (kn1_w + DBLE(2.0)*kn2_w + DBLE(2.0)*kn3_w + kn4_w)/DBLE(6.0)
      Xdis = (kn1_Xdis + DBLE(2.0)*kn2_Xdis + DBLE(2.0)*kn3_Xdis + kn4_Xdis)/DBLE(6.0)
      Ydis = (kn1_YDis + DBLE(2.0)*kn2_Ydis + DBLE(2.0)*kn3_Ydis + kn4_Ydis)/DBLE(6.0)
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
      AdvectX = idt*(P_U*cos(P_angle) - P_V*sin(P_angle)) + Xdis
      AdvectY = idt*(P_U*sin(P_angle) + P_V*cos(P_angle)) + Ydis
      AdvectZ = 0.0!idt*P_W

!print *,ubar,vbar

!      CALL find_currents(x3,y3,z3,Pwc_zb,Pwc_zc,Pwc_zf,Pwc_wzb,Pwc_wzc,        &
!                         Pwc_wzf,P_zb,P_zc,P_zf,ex,ix,p,3,Uad,Vad,Wad)
!print *,tan(kdir+P_angle)
!print *,AdvectY/AdvectX
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
  
      ! *********************************************************
      ! *                                                       *
      ! *                Salinity and Temperature               *
      ! *                                                       *
      ! *********************************************************

      IF (SaltTempOn) THEN

        !Calculate salinity and temperture at the particle location       
        do i=3,us-2
          if ((Zpar .LT. Pwc_zb(i)) .OR.    &
              (Zpar .LT. Pwc_zc(i)) .OR.    &
              (Zpar .LT. Pwc_zf(i))         ) exit
        enddo
        deplvl = i-2    
        P_Salt(n) = WCTS_ITPI("salt",Xpar,Ypar,deplvl,Pwc_zb,Pwc_zc,Pwc_zf,    &
                              us,P_zb,P_zc,P_zf,ex,ix,p,4)
        P_Temp(n) = WCTS_ITPI("temp",Xpar,Ypar,deplvl,Pwc_zb,Pwc_zc,Pwc_zf,    &
                              us,P_zb,P_zc,P_zf,ex,ix,p,4)

      ENDIF

  
      ! *********************************************************
      ! *                                                       *
      ! *                  Horizontal Turbulence                *
      ! *                                                       *
      ! *********************************************************

      IF (WriteModelTiming) call CPU_TIME(times(4))

      IF (HTurbOn) CALL HTurb(TurbHx,TurbHy)

  
      ! *********************************************************
      ! *                                                       *
      ! *                   Verticle Turbulence                 *
      ! *                                                       *
      ! ********************************************************* 

      IF (WriteModelTiming) call CPU_TIME(times(5))

      IF (VTurbOn) CALL VTurb(P_zc,P_depth,P_zetac,p,ex,ix,Pwc_wzb,Pwc_wzc,    &
                              Pwc_wzf,TurbV)

  
      ! *********************************************************
      ! *                                                       *
      ! *                       Behavior                        *
      ! *                                                       *
      ! *********************************************************

      IF (WriteModelTiming) call CPU_TIME(times(6))

      IF (Behavior.NE.0) CALL behave(Xpar,Ypar,Zpar,Pwc_zb,Pwc_zc,Pwc_zf,      &
              P_zb,P_zc,P_zf,P_zetac,par(n,pAge),P_depth,P_U,P_V,P_angle,      &
              n,it,ex,ix,ix(3)/DBLE(86400),p,bott,XBehav,YBehav,ZBehav)

  
      ! *********************************************************
      ! *                                                       *
      ! *     Update Particle Locations and Check Boundaries    *
      ! *                                                       *
      ! *********************************************************

      IF(WriteModelTiming) call CPU_TIME(times(7))

      newXpos = 0.0
      newYpos = 0.0
      newZpos = 0.0

      !Update due to Advection and Turbulence
      newXpos = par(n,pX) + AdvectX + TurbHx 
      newYpos = par(n,pY) + AdvectY + TurbHy
      newZpos = par(n,pZ) + AdvectZ + TurbV
      !Check vertical boundaries and reflect
      !  if particle above surface, particle reflects off surface
      reflect=0.0
      if (newZpos.GT.P_zetac) then
        reflect = P_zetac - newZpos
        NewZpos = P_zetac + reflect
      endif

      !  if particle deeper than bottom, particle reflects off bottom
      if (newZpos.LT.P_depth) then
        reflect = P_depth - newZpos
        NewZpos = P_depth + reflect
        IF(TrackCollisions) hitBottom(n) = hitBottom(n) + 1
      endif 

      !Update due to Behavior
      newZpos = NewZpos + ZBehav

      if(Behavior == 7)then

        if(bott)then
          !Particle on bottom and doesn't move
          newXpos = par(n,pX)
          newYpos = par(n,pY)
          newZpos = P_depth
        else
          !Update due to Behavior 7
          !Set Z position to swimdepth
          newXpos = NewXpos + XBehav      !ewn, FO
          newYpos = NewYpos + YBehav      !ewn, FO
          newZpos = P_depth + Swimdepth
        endif

      endif

  
      !Check vertical boundares and move back in domain
      !  if particle above surface, particle moves just below surface
      if (newZpos.GT.P_zetac) NewZpos = P_zetac - DBLE(0.000001)

      !  if particle deeper than bottom, particle moves just off bottom
      if (newZpos.LT.P_depth) then
        NewZpos = P_depth + DBLE(0.000001)
        IF(TrackCollisions) hitBottom(n) = hitBottom(n) + 1
      endif

      !Horizontal boundary tests. Ensure particle still within domain
      !If not, reflect particle off main boundary or island walls 
      Xpos = par(n,pX)
      Ypos = par(n,pY)
      nXpos = newXpos
      nYpos = newYpos
      skipbound = -1
      reflects = 0
      waterFlag = .FALSE.
      do
        call intersect_reflect(Xpos,Ypos,nXpos,nYpos,fintersectX,fintersectY,  &
               freflectX,freflectY,intersectf,skipbound,isWater)
        if(intersectf == 0)exit
        IF(TrackCollisions) hitLand(n) = hitLand(n) + 1
        if(OpenOceanBoundary)then
          par(n,pnX) = fintersectX
          par(n,pnY) = fintersectY
          par(n,pnZ) = newZpos
          call setOut(n)
          waterFlag = .TRUE.
          exit
        endif

        reflects = reflects + 1

        if(reflects > 3) then
          if(ErrorFlag < 1 .OR. ErrorFlag > 3)then
            write(*,*) n,'still out after 3rd reflection.'
            write(*,*) 'Particle set Out of Bounds and no longer tracked'
            write(*,*) ' '
            write(*,*) 'The Program Cannot Continue and Will Terminate'
            stop
          else
            if(ErrorFlag == 1)then
              par(n,pnX) = par(n,pX)
              par(n,pnY) = par(n,pY)
              par(n,pnZ) = par(n,pZ)
            elseif(ErrorFlag == 2)then
              call die(n)
            else
              call setOut(n)
            endif
            OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
              write(210,24) n,ix(3)
            CLOSE(210)
            waterFlag = .TRUE.
            exit
          endif
        endif

        Xpos = fintersectX
        Ypos = fintersectY
        nXpos = freflectX
        nYpos = freflectY
      enddo

      if(waterFlag) cycle

      newXpos = nXpos
      newYpos = nYpos

      !Check to make sure new position is within model boundaries
      call mbounds(newYpos,newXpos,inbounds)
      if(inbounds /= 1) then
        if(ErrorFlag < 1 .OR. ErrorFlag > 3)then
          write(*,*) 'ERROR: Particle Outside Main Boundaries After ',         &
                     'intersect_reflect'
          write(*,*) 'Model Run Cannot Continue'
          write(*,*) ' '
          write(*,*) 'Previous Location:'
          write(*,*) '  x:   ',par(n,pX), ' y:   ',par(n,pY)
          write(*,*) '  lon: ',x2lon(par(n,pX),par(n,pY)),                     &
                     ' lat: ',y2lat(par(n,pY))
          write(*,*) ' '
          write(*,*) 'Current Location:'
          write(*,*) '  x:   ',newXpos,               ' y:   ',newYpos
          write(*,*) '  lon: ',x2lon(newXpos,newYpos),' lat: ',y2lat(newYpos)
          write(*,*) ' '
          stop
        else
          if(ErrorFlag == 1)then
            par(n,pnX) = par(n,pX)
            par(n,pnY) = par(n,pY)
            par(n,pnZ) = par(n,pZ)
          elseif(ErrorFlag == 2)then
            call die(n)
          else
            call setOut(n)
          endif
          OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
            write(210,25) n,ix(3)
          CLOSE(210)
          cycle
        endif
      endif

      !Check to make sure new position is not within an island
      call ibounds(in_island,newYpos,newXpos,island)
      if(in_island == 1) then
        if(ErrorFlag < 1 .OR. ErrorFlag > 3)then
          write(*,*) 'ERROR: Particle Inside Island Boundaries After ',        &
                     'intersect_reflect'
          write(*,*) 'Model Run Cannot Continue'
          write(*,*) ' '
          write(*,*) 'Previous Location:'
          write(*,*) '  x:   ',par(n,pX), ' y:   ',par(n,pY)
          write(*,*) '  lon: ',x2lon(par(n,pX),par(n,pY)),                     &
                     ' lat: ',y2lat(par(n,pY))
          write(*,*) ' '
          write(*,*) 'Current Location:'
          write(*,*) '  x:   ',newXpos,               ' y:   ',newYpos
          write(*,*) '  lon: ',x2lon(newXpos,newYpos),' lat: ',y2lat(newYpos)
          write(*,*) ' '
          stop
        else
          if(ErrorFlag == 1)then
            par(n,pnX) = par(n,pX)
            par(n,pnY) = par(n,pY)
            par(n,pnZ) = par(n,pZ)
          elseif(ErrorFlag == 2)then
            call die(n)
          else
            call setOut(n)
          endif
          OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
            write(210,26) n,ix(3)
          CLOSE(210)
          cycle
        endif
      endif

      ! End boundary condition tests ******************* 

      !Assign new particle positions
      par(n,pnX) = newXpos
      par(n,pnY) = newYpos
      par(n,pnZ) = newZpos

      ! Check to make sure new position is within a rho, u and v element
      CALL setEle(nXpos,nYpos,n,ele_err)

      IF(ele_err > 0)THEN
        if(ErrorFlag < 1 .OR. ErrorFlag > 3)then
          write(*,*) " "
          SELECT CASE (ele_err)
            CASE(4)
              write(*,*) "Jumped over a rho element"
            CASE(5)
              write(*,*) "Jumped over a u element"
            CASE(6)
              write(*,*) "Jumped over a v element"

          END SELECT
          write(*,*) ' '
          write(*,*) 'Previous Location:'
          write(*,*) '  x:   ',par(n,pX), ' y:   ',par(n,pY)
          write(*,*) '  lon: ',x2lon(par(n,pX),par(n,pY)),                     &
                     ' lat: ',y2lat(par(n,pY))
          write(*,*) ' '
          write(*,*) 'Current Location:'
          write(*,*) '  x:   ',newXpos,               ' y:   ',newYpos
          write(*,*) '  lon: ',x2lon(newXpos,newYpos),' lat: ',y2lat(newYpos)
          write(*,*) ' '
          write(*,*) 'The Program Cannot Continue and Will Terminate'
          stop
        else
          if(ErrorFlag == 1)then
            par(n,pnX) = par(n,pX)
            par(n,pnY) = par(n,pY)
            par(n,pnZ) = par(n,pZ)
          elseif(ErrorFlag == 2)then
            call die(n)
          else
            call setOut(n)
          endif
          OPEN(210,FILE='ErrorLog.txt',POSITION='APPEND')
            SELECT CASE (ele_err)
              CASE(1,4)
                write(210,27) n,ix(3)
              CASE(2,5)
                write(210,28) n,ix(3)
              CASE(3,6)
                write(210,29) n,ix(3)
            END SELECT
          CLOSE(210)
          cycle
        endif
      ENDIF

  
      ! *********************************************************
      ! *                                                       *
      ! *                      Settlement                       *
      ! *                                                       *
      ! *********************************************************

      if(settlementon) then

        CALL testSettlement(par(n,pAge),n,par(n,pX),par(n,pY),inpoly)
        if (inpoly .GT. 0) then
          par(n,pnZ) = P_depth
          endpoly(n) = inpoly
          par(n,pLifespan) = par(n,pAge)
        endif

      endif 

  
      ! *****************************************************************
      ! *                      End of Particle Loop                     *
      ! *****************************************************************

      IF(WriteModelTiming) then
        call CPU_TIME(times(8))

        timeCounts(2) = timeCounts(2) + (times(3)-times(2))
        timeCounts(3) = timeCounts(3) + (times(4)-times(3))
        timeCounts(4) = timeCounts(4) + (times(5)-times(4))
        timeCounts(5) = timeCounts(5) + (times(6)-times(5))
        timeCounts(6) = timeCounts(6) + (times(7)-times(6))
        timeCounts(7) = timeCounts(7) + (times(8)-times(7))
      ENDIF

    ENDDO !end loop for each particle

  
    ! *********************************************************
    ! *               Update particle locations               *
    ! *********************************************************

    do n=1,numpar
      par(n,ppX) = par(n,pX)
      par(n,ppY) = par(n,pY)
      par(n,ppZ) = par(n,pZ)
      par(n,pX)  = par(n,pnX)
      par(n,pY)  = par(n,pnY)
      par(n,pZ)  = par(n,pnZ)
    enddo

    DEALLOCATE(Pwc_zb,Pwc_zc,Pwc_zf)
    DEALLOCATE(Pwc_wzb,Pwc_wzc,Pwc_wzf)

  end subroutine update_particles


  SUBROUTINE find_currents(Xpar,Ypar,Zpar,Pwc_zb,Pwc_zc,Pwc_zf,Pwc_wzb,   &
    Pwc_wzc,Pwc_wzf,P_zb,P_zc,P_zf,ex,ix,p,version,Uad,Vad,Wad,           &
    wb,ubar,vbar,k11,k12,k22)
    !This Subroutine calculates advection currents at the particle's 
    !  location in space and time

    USE PARAM_MOD,  ONLY: us,ws,z0
    USE HYDRO_MOD,  ONLY: interp,WCTS_ITPI
    USE TENSION_MOD, ONLY: TSPSI,HVAL
    USE INT_MOD,    ONLY: polintd
    IMPLICIT NONE

    INTEGER, INTENT(IN) :: p,version
    DOUBLE PRECISION, INTENT(IN) :: Xpar,Ypar,Zpar,P_zb,P_zc,P_zf,ex(3),ix(3), &
      Pwc_zb(:),Pwc_zc(:),Pwc_zf(:),Pwc_wzb(:),Pwc_wzc(:),Pwc_wzf(:)
    DOUBLE PRECISION, INTENT(OUT) :: Uad,Vad,Wad

    !Number of Depth Levels to create tension spline with
    INTEGER, PARAMETER :: nN = 4

    INTEGER :: i,ii,iii
    DOUBLE PRECISION :: P_Ub,P_Uc,P_Uf,P_Vb,P_Vc,P_Vf,P_Wb,P_Wc,P_Wf,ey(3),    &
      Pwc_ub,Pwc_uc,Pwc_uf,Pwc_vb,Pwc_vc,Pwc_vf,Pwc_wb,Pwc_wc,Pwc_wf

! added
    DOUBLE PRECISION :: uu(us),vv(us),kv(us+1),zu(us),zu1(us),kv_u(us),dkv(us), &
      zw(ws),zw1(ws),tt(us),tt1(us),ss(us),ss1(us),dense(us), &
      mask_d(us),mask_k(us),F(us),M_vec(us),N_vec(us),&
      sum1,sum2,sum3,sum4,C,mld
    INTEGER :: j,k,mld_idx,mld_idx_k,mld_idx_d
    DOUBLE PRECISION, INTENT(IN)  :: wb
    DOUBLE PRECISION, INTENT(OUT) :: ubar,vbar,k11,k12,k22

        !version: 1 = return b, 2 = return c, 3 = return f

    ! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    !       Determine the Lowest Numbered US-Level of the Closest Four
    ! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    do i=3,us-2
      if ( (Zpar .LT. Pwc_zb(i)) .OR.  &
           (Zpar .LT. Pwc_zc(i)) .OR.  &
           (Zpar .LT. Pwc_zf(i))       ) exit
    enddo
    ii = i-2

    ! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    !       Determine the Lowest Numbered WS-Level of the Closest Four
    ! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    do i=3,ws-2
      if ( (Zpar .LT. Pwc_wzb(i)) .OR. &
           (Zpar .LT. Pwc_wzc(i)) .OR. &
           (Zpar .LT. Pwc_wzf(i))      ) exit
    enddo
    iii = i - 2

    !           *********************************************************
    !           *                                                       *
    !           *       Calculate U,V,W in Water Column Profile         *
    !           *                                                       *
    !           *********************************************************


    !i. Determine if particle is deep enough that velocities are affected by 
    !  the bottom.
    ! If so, apply log layer between deepest current velocity predicitons 
    ! (deepest rho s-level for u,v and deepest w s-level for w) and bottom.
    ! OR, if below z0, set advection velocities to 0.0
    if ((Zpar .LT. Pwc_wzb(1)+z0) .OR. &
        (Zpar .LT. Pwc_wzc(1)+z0) .OR. &
        (Zpar .LT. Pwc_wzf(1)+z0)      ) then

      Uad = 0.0
      Vad = 0.0
      Wad = 0.0

    elseif ((Zpar .LT. Pwc_zb(1)) .OR. &
            (Zpar .LT. Pwc_zc(1)) .OR. &
            (Zpar .LT. Pwc_zf(1))      ) then

      Pwc_Ub = interp(Xpar,Ypar,"uvelb",1)
      Pwc_Uc = interp(Xpar,Ypar,"uvelc",1)
      Pwc_Uf = interp(Xpar,Ypar,"uvelf",1)
      Pwc_Vb = interp(Xpar,Ypar,"vvelb",1)
      Pwc_Vc = interp(Xpar,Ypar,"vvelc",1)
      Pwc_Vf = interp(Xpar,Ypar,"vvelf",1)
      Pwc_Wb = interp(Xpar,Ypar,"wvelb",2)
      Pwc_Wc = interp(Xpar,Ypar,"wvelc",2)
      Pwc_Wf = interp(Xpar,Ypar,"wvelf",2)

      !  u(z)  = [ u(z1) / (log(z1/zo) ] * (log (z/zo) 
      !where:
      !  u is current velocity
      !  z1 is height of first sigma level above bottom
      !  z0 is roughness height of model
      !  z is height of desired velocity
      !
      !  Note that Pwc_wzb(1) = P_depth = Depth at particle location

      P_Ub=Pwc_Ub*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_zb(1) -Pwc_wzb(1))/z0)
      P_Uc=Pwc_Uc*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_zc(1) -Pwc_wzb(1))/z0)
      P_Uf=Pwc_Uf*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_zf(1) -Pwc_wzb(1))/z0)
      P_Vb=Pwc_Vb*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_zb(1) -Pwc_wzb(1))/z0)
      P_Vc=Pwc_Vc*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_zc(1) -Pwc_wzb(1))/z0)
      P_Vf=Pwc_Vf*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_zf(1) -Pwc_wzb(1))/z0)
      P_Wb=Pwc_Wb*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_wzb(2)-Pwc_wzb(1))/z0)
      P_Wc=Pwc_Wc*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_wzc(2)-Pwc_wzb(1))/z0)
      P_Wf=Pwc_Wf*log10((Zpar-Pwc_wzb(1))/z0)/log10((Pwc_wzf(2)-Pwc_wzb(1))/z0)


      !     *********************************************************
      !     *        Find Internal b,c,f and Advection Values       *
      !     *********************************************************
      !
      ! ii. fit polynomial to hydrodynamic model output and find internal 
      !     b,c,f values

      !a. U velocity
      ! 1. Prepare external time step values
      if (p .EQ. 1) then
        ey=0.0
        ey(1) = P_Ub
        ey(2) = P_Ub
        ey(3) = P_Uc
      else
        ey=0.0
        ey(1) = P_Ub
        ey(2) = P_Uc
        ey(3) = P_Uf
      endif

      ! 2. Get Advection value
      if(version .EQ. 1) then
        Uad = polintd(ex,ey,3,ix(1))
      elseif (version .EQ. 2) then
        Uad = polintd(ex,ey,3,ix(2))
      else
        Uad = polintd(ex,ey,3,ix(3))
      endif

      !b. V velocity
      ! 1. Prepare external time step values
      if (p .EQ. 1) then
        ey=0.0
        ey(1) = P_Vb
        ey(2) = P_Vb
        ey(3) = P_Vc
      else
        ey=0.0
        ey(1) = P_Vb
        ey(2) = P_Vc
        ey(3) = P_Vf
      endif

      ! 2. Get Advection value
      if(version .EQ. 1) then
        Vad = polintd(ex,ey,3,ix(1))
      elseif (version .EQ. 2) then
        Vad = polintd(ex,ey,3,ix(2))
      else
        Vad = polintd(ex,ey,3,ix(3))
      endif


      !c. W velocity
      ! 1. Prepare external time step values
      if (p .EQ. 1) then
        ey=0.0
        ey(1) = P_Wb
        ey(2) = P_Wb
        ey(3) = P_Wc
      else
        ey=0.0
        ey(1) = P_Wb
        ey(2) = P_Wc
        ey(3) = P_Wf
      endif

      ! 2. Get Advection value
      if(version .EQ. 1) then
        Wad = polintd(ex,ey,3,ix(1))
      elseif (version .EQ. 2) then
        Wad = polintd(ex,ey,3,ix(2))
      else
        Wad = polintd(ex,ey,3,ix(3))
      endif

    else

      Uad = WCTS_ITPI("uvel",Xpar,Ypar,ii ,Pwc_zb ,Pwc_zc ,Pwc_zf ,us,P_zb,    &
                      P_zc,P_zf,ex,ix,p,version)
      Vad = WCTS_ITPI("vvel",Xpar,Ypar,ii ,Pwc_zb ,Pwc_zc ,Pwc_zf ,us,P_zb,    &
                      P_zc,P_zf,ex,ix,p,version)
      Wad = WCTS_ITPI("wvel",Xpar,Ypar,iii,Pwc_wzb,Pwc_wzc,Pwc_wzf,ws,P_zb,    &
                      P_zc,P_zf,ex,ix,p,version)

    endif

! Get interpolated t,s,u,v,k at each s-level
    IF (version .EQ. 1) THEN
      DO i=1,us
        tt(i) = interp(Xpar,Ypar,"tempb",i)
        ss(i) = interp(Xpar,Ypar,"tempb",i)
        uu(i) = interp(Xpar,Ypar,"uvelb",i)
        vv(i) = interp(Xpar,Ypar,"vvelb",i)
        kv(i) = interp(Xpar,Ypar,"khb",i)
        zu(i) = Pwc_zb(i)
        zw(i) = Pwc_wzb(i)
        dense(i) = ROMS_EOS(tt(i),ss(i),0.d0)
        mask_d(i) = 1
        mask_k(i) = 1
      ENDDO
        kv(us+1) = interp(Xpar,Ypar,"khb",us+1)
        zw(us+1) = Pwc_wzb(us+1)
!        zw(us+1) = P_zetab
    ELSEIF (version .EQ. 2) THEN 
      DO i=1,us
        tt(i) = interp(Xpar,Ypar,"tempc",i)
        ss(i) = interp(Xpar,Ypar,"tempc",i)
        uu(i) = interp(Xpar,Ypar,"uvelc",i)
        vv(i) = interp(Xpar,Ypar,"vvelc",i)
        kv(i) = interp(Xpar,Ypar,"khc",i)
        zu(i) = Pwc_zc(i)
        zw(i) = Pwc_wzc(i)
        dense(i) = ROMS_EOS(tt(i),ss(i),0.d0)
        mask_d(i) = 1
        mask_k(i) = 1
      ENDDO
        kv(us+1) = interp(Xpar,Ypar,"khc",us+1)
        zw(us+1) = Pwc_wzc(us+1)
!       zw(us+1) = P_zetac
    ELSE
      DO i=1,us
        tt(i) = interp(Xpar,Ypar,"tempf",i)
        ss(i) = interp(Xpar,Ypar,"tempf",i)
        uu(i) = interp(Xpar,Ypar,"uvelf",i)
        vv(i) = interp(Xpar,Ypar,"vvelf",i)
        kv(i) = interp(Xpar,Ypar,"khf",i)
        zu(i) = Pwc_zf(i)
        zw(i) = Pwc_wzf(i)
        dense(i) = ROMS_EOS(tt(i),ss(i),0.d0)
        mask_d(i) = 1
        mask_k(i) = 1
      ENDDO
        kv(us+1) = interp(Xpar,Ypar,"khf",us+1)
        zw(us+1) = Pwc_wzf(us+1)
!        zw(us+1) = P_zetaf
    ENDIF

     
! Determine boundary layer depth
    DO i=us,1,-1   
       dkv(i) = abs(kv(i+1)-kv(i))
       kv_u(i) = 0.5*(kv(i)+kv(i+1))
    ENDDO
    DO i=us,1,-1
       IF (abs(dense(i)-dense(us))>0.15) mask_d(i)=0
       IF ((dkv(i)<2e-4 .and. kv_u(i)<2e-4) .or. kv_u(i)<1e-4) mask_k(i)=0
    ENDDO
    
    mld_idx_d=us
    mld_idx_k=us
    DO i=us-1,1,-1
       IF (mask_d(i+1).eq.1 .and. mask_d(i).eq.1) THEN
         mld_idx_d=i
       ELSE
         EXIT
       ENDIF
    ENDDO
    DO i=us-1,1,-1
       IF (mask_k(i+1).eq.1 .and. mask_k(i).eq.1) THEN
         mld_idx_k=i
       ELSE
         EXIT
       ENDIF
    ENDDO
    mld_idx=max(mld_idx_d,mld_idx_k)
    mld=abs(zw(mld_idx))
! Initialize F
    DO i=1,us
       F(i)=0.0
       M_vec(i)=0.0
       N_vec(i)=0.0
    ENDDO
    ubar=0.0
    vbar=0.0
    k11=0.0
    k12=0.0
    k22=0.0
  
! Calculate F
    DO i=mld_idx,us
       sum1=0.0
       DO j=mld_idx,i
         sum1=sum1+abs(zw(j)-zw(j+1))/(kv(j)+kv(j+1))*2
       ENDDO
       F(i)=exp(wb*sum1)
    ENDDO

    C=0.0
    DO i=mld_idx,us
      C=C+F(i)*abs(zw(i)-zw(i+1))/mld
    ENDDO
    DO i=mld_idx,us
      F(i)=F(i)/C
    ENDDO 
    
! Additional judgement
   IF (F(us-1)/F(us)<1e-3) THEN
     ubar=uu(us)
     vbar=vv(us)
     k11=0.d0
     k12=0.d0
     k22=0.d0
   ELSE
! Calculate ubar and vbar
    sum1=0.0
    sum2=0.0
    DO i=mld_idx,us
       sum1=sum1+uu(i)*F(i)*abs(zw(i)-zw(i+1))
       sum2=sum2+vv(i)*F(i)*abs(zw(i)-zw(i+1))
    ENDDO
    ubar=sum1/mld
    vbar=sum2/mld

! Calculate M and N
    sum1=0.0
    sum2=0.0
    DO i=mld_idx,us
       sum1=0.0
       DO j=mld_idx,i
         sum2=0.0
         DO k=mld_idx,i
            sum2=sum2+(uu(k)-ubar)*F(k)*abs(zw(k)-zw(k+1))
         ENDDO 
         sum1=sum1+sum2/F(j)/(kv(j)+kv(j+1))*2*abs(zw(j)-zw(j+1))
       ENDDO 
       M_vec(i)=F(i)*sum1
    ENDDO

    sum1=0.0
    sum2=0.0
    DO i=mld_idx,us
       sum1=0.0
       DO j=mld_idx,i
         sum2=0.0
         DO k=mld_idx,i
            sum2=sum2+(vv(k)-vbar)*F(k)*abs(zw(k)-zw(k+1))
         ENDDO 
         sum1=sum1+sum2/F(j)/(kv(j)+kv(j+1))*2*abs(zw(j)-zw(j+1))
       ENDDO 
       N_vec(i)=F(i)*sum1
    ENDDO

! Calculate kxx and kyy
    sum1=0.0
    sum2=0.0
    sum3=0.0
    sum4=0.0
    DO i=mld_idx,us
       sum1=sum1+(uu(i)-ubar)*M_vec(i)*abs(zw(i)-zw(i+1))
       sum2=sum2+(uu(i)-ubar)*N_vec(i)*abs(zw(i)-zw(i+1))
       sum3=sum3+(vv(i)-vbar)*N_vec(i)*abs(zw(i)-zw(i+1))
       sum4=sum4+F(i)*abs(zw(i)-zw(i+1))
    ENDDO 
    k11=-sum1/sum4
    k12=-sum2/sum4
    k22=-sum3/sum4
    k11=DMAX1(0.d0,k11)
    k22=DMAX1(0.d0,k22)

   ENDIF

    IF (isnan(ubar).OR.isnan(vbar).OR.isnan(k11).OR.isnan(k12) &
        .OR.isnan(k22).OR.isnan(sum1).OR.isnan(sum2) &
        .OR.isnan(sum3).OR.isnan(sum4)) THEN
      ubar=uu(us)
      vbar=vv(us)
      k11=0.d0
      k12=0.d0
      k22=0.d0
    ENDIF

    RETURN
  END SUBROUTINE find_currents

!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
  subroutine printOutput()
    use param_mod,   only: numpar,SaltTempOn,TrackCollisions,WriteModelTiming
    use convert_mod, only: x2lon,y2lat
    integer :: n
    double precision :: pLon,pLat

    ! increment file number
    prcount = prcount + 1

    !Based on user options, write specified data to output
    IF(SaltTempOn)THEN
      IF(TrackCollisions)THEN
        CALL writeOutput(par(:,pX),par(:,pY),par(:,pZ),par(:,pAge),prcount,    &
             HITBOTTOM=hitBottom,HITLAND=hitLand,P_SALT=P_Salt,P_TEMP=P_Temp)
      ELSE
        CALL writeOutput(par(:,pX),par(:,pY),par(:,pZ),par(:,pAge),prcount,    &
             P_SALT=P_Salt,P_TEMP=P_Temp)
      ENDIF
    ELSE
      IF(TrackCollisions)THEN
        CALL writeOutput(par(:,pX),par(:,pY),par(:,pZ),par(:,pAge),prcount,    &
             HITBOTTOM=hitBottom,HITLAND=hitLand)
      ELSE
        CALL writeOutput(par(:,pX),par(:,pY),par(:,pZ),par(:,pAge),prcount)
      ENDIF
    ENDIF

    !If Tracking Collisions, write update to .csv files
    IF(TrackCollisions)then

      OPEN(100,FILE='LandHits.csv'  ,POSITION='APPEND')
      OPEN(101,FILE='BottomHits.csv',POSITION='APPEND')
      101 format(I7,2(',',F9.4),',',F10.3,2(',',F10.5),',',I7)

        do n=1,numpar
          pLon = x2lon(par(n,pX),par(n,pY))
          pLat = y2lat(par(n,pY))
          if(hitLand(n)   > 0)write(100,101) n,pLon,pLat,par(n,pZ),            &
             par(n,pAge)/DBLE(3600*24),(DBLE(ix(3))/DBLE(86400)),hitLand(n)
          if(hitBottom(n) > 0)write(101,101) n,pLon,pLat,par(n,pZ),            &
             par(n,pAge)/DBLE(3600*24),(DBLE(ix(3))/DBLE(86400)),hitBottom(n)
        enddo

      CLOSE(100)
      CLOSE(101)

      !Reset Collision counters
      hitBottom = 0
      hitLand = 0
    ENDIF

    !If Tracking Model Timing, write Time data to file
    IF(WriteModelTiming)then
      call CPU_TIME(times(9))

      timeCounts(8) = times(9)-times(1)

      OPEN(300,FILE='Timing.csv',POSITION='APPEND')

        write(300,"(15(F14.4,','),F14.4)") (DBLE(ix(3))/DBLE(86400)),timeCounts(8),    &
          timeCounts(1),(timeCounts(1)/timeCounts(8))*DBLE(100.00),            &
          timeCounts(2),(timeCounts(2)/timeCounts(8))*DBLE(100.00),            &
          timeCounts(3),(timeCounts(3)/timeCounts(8))*DBLE(100.00),            &
          timeCounts(4),(timeCounts(4)/timeCounts(8))*DBLE(100.00),            &
          timeCounts(5),(timeCounts(5)/timeCounts(8))*DBLE(100.00),            &
          timeCounts(6),(timeCounts(6)/timeCounts(8))*DBLE(100.00),            &
          timeCounts(7),(timeCounts(7)/timeCounts(8))*DBLE(100.00)

      CLOSE(300)

      timeCounts = 0
      call CPU_TIME(times(1))
    ENDIF

  
  end subroutine printOutput

  SUBROUTINE writeOutput(x,y,z,P_age,prcount,hitBottom,hitLand,P_Salt,P_Temp)
    USE PARAM_MOD, ONLY: numpar,SaltTempOn,outpathGiven,outpath,writeCSV,      &
                         writeNC,TrackCollisions
    USE BEHAVIOR_MOD, ONLY: getStatus
    USE CONVERT_MOD, ONLY: x2lon,y2lat
    USE HYDRO_MOD, ONLY: writeNetCDF

    IMPLICIT NONE

    DOUBLE PRECISION, INTENT(IN) :: x(numpar),y(numpar),z(numpar),P_age(numpar)
    INTEGER         , INTENT(IN) :: prcount
    INTEGER, DIMENSION(numpar), INTENT(IN), OPTIONAL :: hitBottom,hitLand
    DOUBLE PRECISION, DIMENSION(numpar), INTENT(IN), OPTIONAL :: P_Salt,P_Temp

    INTEGER :: n
    DOUBLE PRECISION :: statuses(numpar)
    double precision, dimension(numpar) :: pLon,pLat

    !INPUT/OUTPUT FILE NAME CONSTRUCTION VARIABLES
    CHARACTER(LEN=100) :: filenm2
    CHARACTER(LEN=4  ) :: prefix2,suffix2
    INTEGER :: counter2

    !Convert particle position (in meters) to latitude and longitude &
    !Find identification number that describes a particle's behavior 
    !  type or status for use in visualization routines
    do n=1,numpar
      pLon(n) = x2lon(x(n),y(n))
      pLat(n) = y2lat(y(n))
      statuses(n) = getStatus(n)
    enddo

    !if writing to .csv files:
    if(writeCSV)then
      !Create a filename and unit number for each iteration    
      counter2=prcount+10000000
      prefix2='para'
      suffix2='.csv'
      if(outpathGiven)then
        write(filenm2,'(A,A,I8,A)') TRIM(outpath),prefix2,counter2,suffix2
      else
        write(filenm2,'(A,I8,A)') prefix2,counter2,suffix2
      endif
      open(2,FILE=TRIM(filenm2),STATUS='REPLACE')
      5 format(F10.3,',',I7,2(',',F9.4),2(',',F8.4)) !SaltTemp

      !Based on user options, Write specified data to file                                      
      do n = 1,numpar

        if (SaltTempOn) then
          write(2,5) z(n),int(statuses(n)),pLon(n),pLat(n),P_Salt(n),P_Temp(n)
        else
          write(2,5) z(n),int(statuses(n)),pLon(n),pLat(n)
        endif 

      enddo

      close(2)

    endif


    !if writing to NetCDF file(s):
    if(writeNC)then

      !Based on user options, Write specified data to file
      if (SaltTempOn) then
        if(TrackCollisions)then
          CALL writeNetCDF(int(ix(3)),P_age(:),pLon,pLat,z,statuses,           &
               SALT=P_Salt,TEMP=P_Temp,HITB=hitBottom,HITL=hitLand)
        else
          CALL writeNetCDF(int(ix(3)),P_age(:),pLon,pLat,z,statuses,           &
               SALT=P_Salt,TEMP=P_Temp)
        endif
      else
        if(TrackCollisions)then
          CALL writeNetCDF(int(ix(3)),P_age(:),pLon,pLat,z,statuses,           &
               HITB=hitBottom,HITL=hitLand)
        else
          CALL writeNetCDF(int(ix(3)),P_age(:),pLon,pLat,z,statuses)
        endif
      endif

    endif

  END SUBROUTINE writeOutput

  SUBROUTINE writeModelInfo()
    !This subroutine simply writes model information to standard output
    USE PARAM_MOD
    IMPLICIT NONE

    CHARACTER(len=10) :: tmp !For Converting Integers to Characters
    CHARACTER(len=200) :: filenm

    write(*,*) ' ******************** Model Info ******************** '
    write(*,*) ' '

    write(*,*) ' Run Name:              = ',TRIM(RunName)
    write(*,*) ' Executable Directory:  = ',TRIM(ExeDir)
    write(*,*) ' Output Directory:      = ',TRIM(OutDir)
    write(*,*) ' Run By:                = ',TRIM(RunBy)
    write(*,*) ' Institution:           = ',TRIM(Institution)
    write(*,*) ' Started On:            = ',TRIM(StartedOn)
    write(*,*) ' '

    write(tmp,'(F10.3)') days
    tmp = ADJUSTL(tmp)
    write(*,*) ' Days:                  = ',TRIM(tmp)
    write(tmp,'(I10)') numpar
    tmp = ADJUSTL(tmp)
    write(*,*) ' Particles:             = ',TRIM(tmp)
    write(*,*) ' Particle File:         = ',TRIM(parfile)
    write(*,*) ' '

    SELECT CASE(Behavior)
      CASE(0)
      write(*,*) ' Behavior:              = Passive'
      CASE(1)
      write(*,*) ' Behavior:              = Near-Surface'
      CASE(2)
      write(*,*) ' Behavior:              = Near-Bottom'
      CASE(3)
      write(*,*) ' Behavior:              = Diurnal Vertical Migration'
      CASE(4)
      write(*,*) ' Behavior:              = C.virginica oyster larvae'
      CASE(5)
      write(*,*) ' Behavior:              = C.ariakensis oyster larvae'
      CASE(6)
      write(*,*) ' Behavior:              = Constant sink/float'
      CASE(7)
      write(*,*) ' Behavior:              = Tidal Stream Transport'
    END SELECT

    if(mortality)then
      write(*,*) ' Particle Mortality:    = On'
    else
      write(*,*) ' Particle Mortality:    = Off'
    endif

    if(settlementon)then
      write(*,*) ' Settlement:            = On'
      write(*,*) ' Habitat File:          = ',TRIM(habitatfile)
      if(holesExist)write(*,*) ' Hole File:             = ',TRIM(holefile)
    else
      write(*,*) ' Settlement:            = Off'
    endif
    write(*,*) ' '

    if(HTurbOn)then
      write(*,*) ' Horizontal Turbulence: = On'
    else
      write(*,*) ' Horizontal Turbulence: = Off'
    endif
    if(VTurbOn)then
      write(*,*) ' Vertical Turbulence:   = On'
    else
      write(*,*) ' Vertical Turbulence:   = Off'
    endif
    if(SphericalProjection)then
      write(*,*) ' Projection:            = Spherical'
    else
      write(*,*) ' Projection:            = Mercator'
    endif
    if(OpenOceanBoundary)then
      write(*,*) ' Ocean Boundary:        = Open'
    else
      write(*,*) ' Ocean Boundary:        = Closed'
    endif
    if(SaltTempOn)then
      write(*,*) ' Salt & Temp Output:    = On'
    else
      write(*,*) ' Salt & Temp Output:    = Off'
    endif
    if(TrackCollisions)then
      write(*,*) ' Track Collisions:      = Yes'
    else
      write(*,*) ' Track Collisions:      = No'
    endif
    if(WriteModelTiming)then
      write(*,*) ' Track Model Timing:    = Yes'
    else
      write(*,*) ' Track Model Timing:    = No'
    endif

    SELECT CASE(numdigits)
      CASE(1)
        WRITE(filenm,'(A,I1.1,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE(2)
        WRITE(filenm,'(A,I2.2,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE(3)
        WRITE(filenm,'(A,I3.3,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE(4)
        WRITE(filenm,'(A,I4.4,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE(5)
        WRITE(filenm,'(A,I5.5,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE(6)
        WRITE(filenm,'(A,I6.6,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE(7)
        WRITE(filenm,'(A,I7.7,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE(8)
        WRITE(filenm,'(A,I8.8,A)') TRIM(prefix),filenum,TRIM(suffix)
      CASE DEFAULT
        WRITE(*,*) 'Model presently does not support numdigits of ',numdigits
        WRITE(*,*) 'Please use numdigit value from 1 to 8'
        WRITE(*,*) '  OR modify code in Hydrodynamic module'
        STOP
    END SELECT

    write(*,*) ' '
    write(*,*) ' Grid File:             = ',NCgridfile
    write(*,*) ' First Hydro File:      = ',TRIM(filenm)

    write(*,*) ' '
    write(tmp,'(I10)') seed
    tmp = ADJUSTL(tmp)
    write(*,*) ' Seed:                  = ',TRIM(tmp)
    write(*,*) ' '

  END SUBROUTINE writeModelInfo

end program
