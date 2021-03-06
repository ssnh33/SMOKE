
        MODULE MODSPRO

!***********************************************************************
!  Module body starts at line
!
!  DESCRIPTION:
!     This module contains the public data for the speciation profiles
!
!  PRECONDITIONS REQUIRED:
!
!  SUBROUTINES AND FUNCTIONS CALLED:
!
!  REVISION HISTORY:
!     Created 3/99 by M. Houyoux
!
!***************************************************************************
!
! Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
!                System
! File: @(#)$Id$
!
! COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
! All Rights Reserved
! 
! Carolina Environmental Program
! University of North Carolina at Chapel Hill
! 137 E. Franklin St., CB# 6116
! Chapel Hill, NC 27599-6116
! 
! smoke@unc.edu
!
! Pathname: $Source$
! Last updated: $Date$ 
!
!****************************************************************************

        IMPLICIT NONE

        INCLUDE 'EMPRVT3.EXT'

!.........  NOTE: The unique speciation profiles and speciation tables are
!.........        used multiple times: once for each inventory pollutant that 
!.........        needs speciation

!.........  Unique speciation profiles list and index to sorted tables
        INTEGER,              PUBLIC :: NSPROF         ! Number in unique list
        INTEGER,              PUBLIC :: NPOLSPRO       ! Number of profiles for pollutant

        ! position in INPRF of start of each profile
        INTEGER, ALLOCATABLE, PUBLIC :: IDXSPRO ( : )

        ! number of species in this profile
        INTEGER, ALLOCATABLE, PUBLIC :: NSPECIES( : )
  
        ! index to all-species list for this profile
        INTEGER, ALLOCATABLE, PUBLIC :: IDXSSPEC( :,: )
  
        ! unique list of each profile for searching
        CHARACTER(SPNLEN3), ALLOCATABLE, PUBLIC :: SPROFN( : )

!.........  Sorted speciation tables
        INTEGER,              PUBLIC :: MXSPFUL   ! Max no. in unprocessed table
        INTEGER,              PUBLIC :: MXSPEC    ! max no. of species per pol
        INTEGER,              PUBLIC :: NSPFUL    ! Number in unprocessed table

        REAL   , ALLOCATABLE, PUBLIC :: MOLEFACT( : ) ! mole-based spec factors
        REAL   , ALLOCATABLE, PUBLIC :: MASSFACT( : ) ! mass-based spec factors

        ! speciation profile codes
        CHARACTER(SPNLEN3), ALLOCATABLE, PUBLIC :: INPRF( : )
  
        ! names of species
        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: SPECID( : )

!.........  Table of species names per inventory pollutant

        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: SPCNAMES( :,: )

!.........  Table of mole-based units per inventory pollutant for all species

        CHARACTER(IOULEN3), ALLOCATABLE, PUBLIC :: MOLUNITS( :,: )

!.........  Header definitions for NONHAP<pollutants>
        CHARACTER(4), PARAMETER :: HDRSTART = '#NHAP' ! start of header

        INTEGER,                         PUBLIC :: NSPDEF   ! no. pols with def'ns
        INTEGER,                         PUBLIC :: MXSPLST  ! max items per def'n list
        INTEGER,            ALLOCATABLE, PUBLIC :: NSPLST   ( : ) ! no. item in each (nspdef)
        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: SPCDEFPOL( : ) ! pols with def'ns (nspdef)
        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: SPCDEFLST( :,: ) ! the def'ns (mxsplst,nspdef)

!.........  Sorted groups of pollutant to pollutant conversion factors

!.........  Default FIPS code=0, SCC=0 (for all pollutants)
        LOGICAL               , ALLOCATABLE, PUBLIC :: CNVFLAG( : )
        REAL                  , ALLOCATABLE, PUBLIC :: CNVFC00( : )

!.........  FIPS code=0, SCC=all (for all pollutants)
        INTEGER,                         PUBLIC :: NCNV1
        REAL,               ALLOCATABLE, PUBLIC :: CNVFC01( :,: ) 
        CHARACTER(SCCLEN3), ALLOCATABLE, PUBLIC :: CNVRT01( : )

!.........  FIPS code=country/state default, SCC=all (for all pollutants)
        INTEGER,                         PUBLIC :: NCNV2
        REAL,               ALLOCATABLE, PUBLIC :: CNVFC02( :,: ) 
        CHARACTER(STSLEN3), ALLOCATABLE, PUBLIC :: CNVRT02( : )

!.........  FIPS code=all, SCC=all (for all pollutants)
        INTEGER,                         PUBLIC :: NCNV3
        REAL,               ALLOCATABLE, PUBLIC :: CNVFC03( :,: ) 
        CHARACTER(FPSLEN3), ALLOCATABLE, PUBLIC :: CNVRT03( : )

!.........  Factors by speciation profile (for all pollutants)
!.........  In this case, the other three groups are not used, since the
!           GSCNV file has to be by FIPS/SCC or by profile (not both in the
!           same file)
        INTEGER,                         PUBLIC :: NCNV4
        REAL,               ALLOCATABLE, PUBLIC :: CNVFC04( :,: ) 
        CHARACTER(SPNLEN3), ALLOCATABLE, PUBLIC :: CNVRT04( : )

!.........  Parameter and arrays for the GSPRO_COMBO file
!.........  These arrays work with the INVCFIP array in MODLISTS
        INTEGER, PARAMETER, PUBLIC :: CMBMAX = 10

        INTEGER,            ALLOCATABLE, PUBLIC :: CMBNP( : )
        REAL,               ALLOCATABLE, PUBLIC :: CMBWGHT( :,: )
        CHARACTER(SPNLEN3), ALLOCATABLE, PUBLIC :: CMBSPCD( :,: )

!.........  Array of 1-d species names, needed for tagging.
        INTEGER,                         PUBLIC :: NSPCALL      ! length of SPCLIST
        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: SPCLIST( : ) ! 1-d array of all species


        END MODULE MODSPRO
