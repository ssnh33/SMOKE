
        SUBROUTINE FILLSTBL( NIPOL, NXREF, ICSIZE, XTYPE, XTCNT )

C***********************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      This subroutine populates the speciation profile codes part of the 
C      grouped speciation cross-reference tables.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C     Created 3/99 by M. Houyoux
C
C****************************************************************************/
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 1999, MCNC--North Carolina Supercomputing Center
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

C...........   This module is for cross reference tables
        USE MODXREF

        IMPLICIT NONE

C...........   INCLUDES
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters

C...........   EXTERNAL FUNCTIONS and their descriptions:
        CHARACTER*2     CRLF
        EXTERNAL        CRLF

C...........   SUBROUTINE ARGUMENTS
        INTEGER     , INTENT (IN) :: NIPOL           ! no. pollutants
        INTEGER     , INTENT (IN) :: NXREF           ! no. ungrpd x-ref entries
        INTEGER     , INTENT (IN) :: ICSIZE( * )     ! size of x-ref groups
        INTEGER     , INTENT (IN) :: XTYPE ( NXREF ) ! group no. of x-ref entry
        INTEGER     , INTENT (IN) :: XTCNT ( NXREF ) ! pos. in x-ref group

C...........   Other local variables
        INTEGER       I, J, K, T       ! counter and indices
        INTEGER       ISP              ! temporary pollutant position in EINAM

        LOGICAL    :: EFLAG = .FALSE.  ! true: error has occurred

        CHARACTER*300          MESG    ! message buffer
        CHARACTER(LEN=SPNLEN3) SPCODE  ! tmp for speciation profile code

        CHARACTER*16 :: PROGNAME = 'FILLSTBL' ! program name

C***********************************************************************
C   begin body of subroutine FILLSTBL

C.........  Store the temporal profile codes for each x-ref entry, depending
C           on the group (XTYPE) and the position in that group (XTCNT)

        DO I = 1, NXREF

            J      = INDXTA( I )
            ISP    = ISPTA ( J )
            SPCODE = CSPRNA( J )

            T      = XTYPE ( I )
            K      = XTCNT ( I )

            IF( ISP .EQ. 0 ) THEN
                EFLAG = .TRUE.
                MESG = 'INTERNAL ERROR: Pollutant code was 0 ' //
     &                 'for speciation cross-reference entry ' //
     &                 CRLF()// BLANK10// 'in program ' // PROGNAME
                CALL M3MESG( MESG )
            ENDIF

C.................  Populate tables depending on type. Note that all profiles 
C                   are, by definition, pollutant-specific.
            SELECT CASE ( T )

            CASE( 0 )  ! Skip this x-ref because it is invalid or duplicate

            CASE( 1 )
                CSPT01( ISP )   = SPCODE

            CASE( 2 )
                CSPT02( K,ISP ) = SPCODE

            CASE( 3 )
                CSPT03( K,ISP ) = SPCODE

            CASE( 4 )
                CSPT04( K,ISP ) = SPCODE

            CASE( 5 )
                CSPT05( K,ISP ) = SPCODE

            CASE( 6 )
                CSPT06( K,ISP ) = SPCODE

            CASE( 7 )
                CSPT07( K,ISP ) = SPCODE

            CASE( 8 )
                CSPT08( K,ISP ) = SPCODE

            CASE( 9 )
                CSPT09( K,ISP ) = SPCODE
                    
            CASE( 10 )
                CSPT10( K,ISP ) = SPCODE
                    
            CASE( 11 )
                CSPT11( K,ISP ) = SPCODE
                    
            CASE( 12 )
                CSPT12( K,ISP ) = SPCODE
                    
            CASE( 13 )
                CSPT13( K,ISP ) = SPCODE
             
            CASE( 14 )
                CSPT14( K,ISP ) = SPCODE
                   
            CASE( 15 )
                CSPT15( K,ISP ) = SPCODE
                                        
            CASE( 16 )
                CSPT16( K,ISP ) = SPCODE
                                        
            CASE DEFAULT

            END SELECT

        ENDDO                            ! End Loop on sorted x-ref entries

        IF( EFLAG ) THEN
            MESG = 'Problem processing cross-reference records.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

        END SUBROUTINE FILLSTBL
