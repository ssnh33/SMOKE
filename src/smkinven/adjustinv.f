
        SUBROUTINE ADJUSTINV( NRAWBP, YDEV )

C**************************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      This subroutine is just a placeholder to call the area-to-point
C      routines for now.
C
C  PRECONDITIONS REQUIRED:
C      CSOURCA and SRCIDA arrays allocated and defined with Source IDs
C      NSRC is set.
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C      Created 11/02 by C. Seppanen
C
C**************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2002, MCNC Environmental Modeling Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Modeling Center
C MCNC
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C smoke@emc.mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C...........   MODULES for public variables
C...........   This module is the inventory arrays
        USE MODSOURC 

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constat parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters

C...........   EXTERNAL FUNCTIONS and their descriptions
        CHARACTER*2     CRLF
        EXTERNAL        CRLF

C...........   SUBROUTINE ARGUMENTS
        INTEGER     , INTENT (IN) :: NRAWBP  ! no. raw records by pollutant
        INTEGER     , INTENT (IN) :: YDEV    ! unit no. for ar-to-point

C...........   Other local variables
        CHARACTER*256   MESG        ! message buffer 

        CHARACTER*16 :: PROGNAME = 'ADJUSTINV' ! program name

C***********************************************************************
C   begin body of subroutine ADJUSTINV

C.........  Read and preprocess area-to-point factors file
C.........  Result of this call is that the NAR2PT and AR2PTABL 
C           arrays from MODAR2PT and the CHRT09 and ARPT09 arrays
C           from MODLISTS will be populated.
        IF( YDEV .GT. 0 ) CALL RDAR2PT( YDEV )

C.........  Assign area-to-point cross-reference entries to sources
C.........  Result of this call is that the AR2PTTBL, AR2PTIDX, and
C           AR2PTCNT arrays from MODLISTS will be populated
        CALL ASGNAR2PT( NRAWBP )

C.........  Read and preprocess NONHAPVOC exclusions cross-reference
C      CALL RD??

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )
 
        END SUBROUTINE ADJUSTINV
