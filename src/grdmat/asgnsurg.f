
        SUBROUTINE ASGNSURG

C***********************************************************************
C  subroutine body starts at line 109
C
C  DESCRIPTION:
C      For each source, find the most specific gridding surrogate code
C      that applies to that source. Do this using the grouped tables of
C      gridding cross references from RDGREF.  The hierarchical order is
C      defined in this subroutine, and can be determined from the in-source
C      comments below. Once a surrogate code has been identified, search for 
C      this code in the gridding surrogates tables (from RDSRG) and save the 
C      index to these tables for each source.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C     Created 4/99 by M. Houyoux
C     Modified 12/01 by Gabe Cano - deterministic mode
C
C************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2000, MCNC--North Carolina Supercomputing Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Programs Group
C MCNC--North Carolina Supercomputing Center  
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C env_progs@mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C...........   MODULES for public variables   
C...........   This module contains the source ararys
        USE MODSOURC

C...........   This module contains the cross-reference tables
        USE MODXREF

C...........   This module contains the gridding surrogates tables
        USE MODSURG

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  i/o api constant parameters

C...........   EXTERNAL FUNCTIONS and their descriptions:
        CHARACTER*2     CRLF
        LOGICAL         ENVYN
        INTEGER         FIND1
        INTEGER         FINDC

        EXTERNAL    CRLF, ENVYN, FIND1, FINDC

C.........  Other local variables
        INTEGER          I, J, L2, S    !  counters and indices

        INTEGER          F0, F1, F2, F3, F4, F5  ! tmp find indices
        INTEGER          FIP     !  tmp country/state/county code
        INTEGER          ISRG    !  tmp surrogate code
        INTEGER          ISCI    !  tmp surrogate code index in array

        LOGICAL       :: EFLAG    = .FALSE.
        LOGICAL, SAVE :: FIRSTIME = .TRUE.
        LOGICAL, SAVE :: REPDEFLT = .TRUE.

        CHARACTER*8               FMTFIP   ! format for writing FIPS code
        CHARACTER*10              RWTFMT   ! formt to write rdway type to string
        CHARACTER*10              VIDFMT   ! format to write veh ID to string
        CHARACTER*300             BUFFER   ! source fields buffer
        CHARACTER*300             MESG     ! message buffer
        CHARACTER(LEN=LNKLEN3) :: CLNK= ' '! tmp link ID
        CHARACTER(LEN=STALEN3)    CSTA     ! tmp Country/state code
        CHARACTER(LEN=STSLEN3)    CSTASCC  ! tmp Country/state code // SCC
        CHARACTER(LEN=STSLEN3)    CSTASL   ! tmp Country/state code // left SCC
        CHARACTER(LEN=SCCLEN3)    TSCCL    ! tmp left digits of TSCC
        CHARACTER(LEN=SRCLEN3)    CSRC     ! tmp source chars string
        CHARACTER(LEN=RWTLEN3)    CRWT     !  buffer for roadway type
        CHARACTER(LEN=FIPLEN3)    CFIP     ! tmp (character) FIPS code
        CHARACTER(LEN=FPLLEN3)    CFIPPLT  ! tmp FIPS code // plant id
        CHARACTER(LEN=FPSLEN3)    CFIPSCC  ! tmp FIPS code // SCC
        CHARACTER(LEN=FPSLEN3)    CFIPSL   ! tmp FIPS code // left SCC
        CHARACTER(LEN=SCCLEN3)    TSCC     ! tmp 10-digit SCC
        CHARACTER(LEN=VIDLEN3)    CVID     ! buffer for vehicle type ID

        CHARACTER*16 :: PROGNAME = 'ASGNSURG' ! program name

C***********************************************************************
C   begin body of subroutine ASGNSURG

C.........  For first time routine is called in all cases,
        IF( FIRSTIME ) THEN

C.............  Retrieve environment variables
            MESG = 'Switch for reporting default gridding surrogates'
            REPDEFLT = ENVYN ( 'REPORT_DEFAULTS', MESG, .TRUE., I )

C.............  Allocate memory for surrogate ID position

            FIRSTIME = .FALSE.

        ENDIF

C.........  Set up formats
        WRITE( RWTFMT, '("(I",I2.2,".",I2.2,")")' ) RWTLEN3, RWTLEN3
        WRITE( VIDFMT, '("(I",I2.2,".",I2.2,")")' ) VIDLEN3, VIDLEN3

C.........  Loop through the sources
        DO S = 1, NSRC

C.............  Create selection 
            SELECT CASE ( CATEGORY )

            CASE ( 'AREA' )
                FIP     = IFIP  ( S )
                CSRC    = CSOURC( S )
                CFIP    = CSRC( 1:FIPLEN3 )
                CSTA    = CFIP( 1:STALEN3 )
                TSCC    = CSCC( S )
                TSCCL   = TSCC( 1:LSCCEND )
                CFIPSCC = CFIP // TSCC
                CFIPSL  = CFIP // TSCCL
                CSTASCC = CSTA // TSCC
                CSTASL  = CSTA // TSCCL

            CASE ( 'BIOG' )

c note: insert here when needed

            CASE ( 'MOBILE' )

                FIP     = IFIP  ( S )
                CSRC    = CSOURC( S )
                CFIP    = CSRC( 1:FIPLEN3 )
                CLNK    = CLINK ( S )
                CSTA    = CFIP  ( 1:STALEN3 )

                WRITE( CRWT, RWTFMT ) IRCLAS( S )
                WRITE( CVID, VIDFMT ) IVTYPE( S )
                TSCC = CRWT // CVID
                CALL PADZERO( TSCC )

                TSCCL   = TSCC( 1:LSCCEND )
                CFIPSCC = CFIP // TSCC
                CFIPSL  = CFIP // TSCCL
                CSTASCC = CSTA // TSCC
                CSTASL  = CSTA // TSCCL

            END SELECT

C.............  Skip finding a surrogate if current source is a link source
            IF( CLNK .NE. ' ' ) CYCLE

C.................  Try for FIPS code & SCC match; then
C                           FIPS code & left SCC match; then
C                           Cy/st code & SCC match; then
C                           Cy/st code & left SCC match; then
C                           SCC match; then
C                           left SCC match

            F5 = FINDC( CFIPSCC, TXCNT( 9 ), CHRT09 ) 
            F4 = FINDC( CFIPSL , TXCNT( 8 ), CHRT08 ) 
            F3 = FINDC( CSTASCC, TXCNT( 6 ), CHRT06 ) 
            F2 = FINDC( CSTASL , TXCNT( 5 ), CHRT05 ) 
            F1 = FINDC( TSCC   , TXCNT( 3 ), CHRT03 ) 
            F0 = FINDC( TSCCL  , TXCNT( 2 ), CHRT02 )

            IF( F5 .GT. 0 ) THEN
c                ISRG = ISRG09( F5 ) 
                ISRG = ISRGCDA( ISRG09( F5 ) , 1)
                ISCI = ISRG09( F5 )
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop

            ELSEIF( F4 .GT. 0 ) THEN
                ISRG = ISRGCDA( ISRG08( F4 ) , 1)
                ISCI = ISRG08( F4 )
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop

            ELSEIF( F3 .GT. 0 ) THEN
                ISRG = ISRGCDA( ISRG06( F3 ) , 1)
                ISCI = ISRG06( F3 )
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop

            ELSEIF( F2 .GT. 0 ) THEN
                ISRG = ISRGCDA( ISRG05( F2 ) , 1)
                ISCI = ISRG05( F2 )
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop

            ELSEIF( F1 .GT. 0 ) THEN
                ISRG = ISRGCDA( ISRG03( F1 ) , 1)
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop

            ELSEIF( F0 .GT. 0 ) THEN
                ISRG = ISRGCDA( ISRG02( F0 ) , 1)
                ISCI = ISRG02( F0 )
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop

            END IF

C.............  Try for any FIPS code match
            F0 = FINDC( CFIP, TXCNT( 7 ), CHRT07 ) 

            IF( F0 .GT. 0 ) THEN
                ISRG = ISRGCDA( ISRG07( F0 ) , 1)
                ISCI = ISRG07( F0 )
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop
            END IF

C.............  Try for any country/state code match (not, pol-specific)
            F0 = FINDC( CSTA, TXCNT( 4 ), CHRT04 ) 

            IF( F0 .GT. 0 ) THEN
                ISRG = ISRGCDA( ISRG04( F0 ) , 1)
                ISCI = ISRG04( F0 )
                CALL SETSOURCE_GSURG
                CYCLE                       !  to end of sources-loop
            END IF

            IF( ISRG01 .NE. IMISS3 .AND. REPDEFLT ) THEN
                ISRG = ISRG01
                    
                CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )

                WRITE( MESG,94010 )
     &                 'WARNING: Using default gridding ' //
     &                 'cross-reference code of', ISRG, 'for:' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L2 )
                CALL M3MESG( MESG )

                CALL SETSOURCE_GSURG

            ELSEIF( ISRG01 .NE. IMISS3 ) THEN
                ISRG = ISRG01
                CALL SETSOURCE_GSURG

            ELSE
                EFLAG = .TRUE.

                CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )

                WRITE( MESG,94010 )
     &                 'ERROR: No gridding cross-reference ' //
     &                 'available (and no default) for:' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L2 )

                CALL M3MESG( MESG )

            END IF    !  if default profile code is available or not

        END DO        !  end loop on source, S

        IF( EFLAG ) THEN
            MESG = 'Problem assigning gridding surrogates to sources'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF 

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94300   FORMAT( A, I2.2, A, I2.2, A )

C******************  INTERNAL SUBPROGRAMS  *****************************

        CONTAINS

C.............  This internal subprogram stores the index of the surrogate 
C               codes from the surrogates file for each source.
            SUBROUTINE SETSOURCE_GSURG

C.............  Local variables
            INTEGER          IFIPPOS  ! position of cy/st/co code in list
            INTEGER          ISRGPOS  ! position of surrogate code in list
            INTEGER          ISCIPOS  ! position of surrogate code index 
                                      ! in array
            INTEGER, SAVE :: LFIP     ! FIPS code from previous iteration
            INTEGER, SAVE :: SAVFPOS  ! IFIPPOS from previous iteration 

C----------------------------------------------------------------------

            ISRGPOS = MAX( FIND1( ISRG, NSRGS, SRGLIST ), 0 )

            IF( ISRGPOS .EQ. 0 ) THEN

                CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )

                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 
     &                 'ERROR: Gridding surrogate code', ISRG, 
     &                 'is not in surrogates file, but was ' //
     &                 CRLF() // BLANK5 // 'assigned to source:' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L2 )
                CALL M3MESG( MESG )

            END IF

            SRGIDPOS( S ) = ISRGPOS
            SRGCDPOS( S ) = ISCI

C.............  For non-link sources, find cy/st/co code in surrogates table
C.............  Only do find if this FIPS code is different from previous, for
C               efficiency pruposes.  The sources that are outside the grid
C               will be written out from the matrix generator routines.
            IFIPPOS = 0
            IF( FIP .NE. LFIP ) THEN
                IFIPPOS = FIND1( FIP, NSRGFIPS, SRGFIPS )
                LFIP    = FIP
                SAVFPOS = IFIPPOS

            ELSE IF( FIP .EQ. LFIP ) THEN
                IFIPPOS = SAVFPOS

            END IF

            SGFIPPOS( S ) = IFIPPOS

            RETURN

C------------------- SUBPROGRAM FORMAT STATEMENTS ----------------------

C...........   Internal buffering formats............ 94xxx

94010       FORMAT( 10( A, :, I8, :, 1X ) )

            END SUBROUTINE SETSOURCE_GSURG

        END SUBROUTINE ASGNSURG
