
        SUBROUTINE  FIXSTK( FDEV, NSRC )

C***********************************************************************
C  subroutine body starts at line 159
C
C  DESCRIPTION:
C       Read and use replacement stack parameters from file PSTK to fill in
C       stack parameters which are "missing" (i.e., negative). Also use
C       ultimate defaults (set as local parameters) when no other stack 
C       parameters are available.
C
C  PRECONDITIONS REQUIRED:
C       Opened file with unit FDEV
C       Memory of arrays already allocated and with NSRC
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C       Subroutines: I/O API subroutines, CHECKMEM, FMTCSRC
C       Function: I/O API functions, GETFLINE
C
C  REVISION  HISTORY:
C       prototype 12/95 by CJC
C       copied by: mhouyoux
C       origin: fixstk.F 4.3
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
C All Rights Reserved
C 
C Carolina Environmental Program
C University of North Carolina at Chapel Hill
C 137 E. Franklin St., CB# 6116
C Chapel Hill, NC 27599-6116
C 
C smoke@unc.edu
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C.........  MODULES for public variables
C.........  This module contains the inventory arrays
        USE MODSOURC, ONLY: CSOURC, CSCC, IFIP, 
     &                      STKHT, STKDM, STKVE, STKTK

        IMPLICIT NONE

C...........   INCLUDES:

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C...........   EXTERNAL FUNCTIONS and their descriptions:

        CHARACTER(2)    CRLF
        INTEGER         FINDC
        INTEGER         GETFLINE
        LOGICAL         BLKORCMT

        EXTERNAL        BLKORCMT, CRLF, FINDC, GETFLINE

C...........   ARGUMENTS and their descriptions:

        INTEGER       FDEV             ! unit no. for stack parameter file PSTK
        INTEGER       NSRC             ! actual number of sources

C...........   LOCAL PARAMETERS and their descriptions:
        REAL   , PARAMETER :: MINHT =    0.5    ! Min stack height (m)
        REAL   , PARAMETER :: MINDM =    0.01   ! Min stack diameter (m)
        REAL   , PARAMETER :: MINTK =  260.0    ! Min stack exit temperature (K)
        REAL   , PARAMETER :: MINVE =    0.0001 ! Min stack exit velocity (m/s)
        REAL   , PARAMETER :: MAXHT = 2100.0    ! Max stack height (m)
        REAL   , PARAMETER :: MAXDM =  100.0    ! Max stack diameter (m)
        REAL   , PARAMETER :: MAXTK = 2000.0    ! Max stack exit temperature (K)
        REAL   , PARAMETER :: MAXVE =  500.0    ! Max stack exit velocity (m/s)

C...........    LOCAL VARIABLES and their descriptions:

C.........  Unsorted arrays from stack replacements file

        INTEGER           , ALLOCATABLE :: INDXA( : ) ! sorting index
        REAL              , ALLOCATABLE :: SHTA ( : ) ! stack height 
        REAL              , ALLOCATABLE :: SDMA ( : ) ! stack diameter
        REAL              , ALLOCATABLE :: STKA ( : ) ! stack temperature 
        REAL              , ALLOCATABLE :: SVEA ( : ) ! stack velocity 
        CHARACTER(FPSLEN3), ALLOCATABLE :: SFSCA( : ) ! FIPS code // SCC 

C.........  Tables of stack parameter updates
C.........  Ultimate defaults
        REAL               HT0      !  ultimate fallback height
        REAL               DM0      !  ultimate fallback diameter
        REAL               TK0      !  ultimate fallback temperature
        REAL               VE0      !  ultimate fallback velocity

C.........  SCC-only table
        INTEGER                            NR1       ! number
        INTEGER           , ALLOCATABLE :: ID1 ( : ) ! index to unsorted 
        CHARACTER(SCCLEN3), ALLOCATABLE :: TBL1( : ) ! SCC

C.........  SCC-country/state table
        INTEGER                            NR2       ! number
        INTEGER           , ALLOCATABLE :: ID2 ( : ) ! index to unsorted
        CHARACTER(STSLEN3), ALLOCATABLE :: TBL2( : ) ! co/st // scc

C.........  SCC-FIPS code table
        INTEGER                            NR3       ! number
        INTEGER           , ALLOCATABLE :: ID3 ( : ) ! index to unsorted
        CHARACTER(FPSLEN3), ALLOCATABLE :: TBL3( : ) ! FIPS code // scc
         
C.........  Other local variables
        INTEGER         I, J, K, L1, L2, L3, S   !  counters and indices

        INTEGER         FIP     !  temporary FIPs code
        INTEGER         NCNT    !  number of entry lines
        INTEGER         IOS     !  I/O error status
        INTEGER         IREC    !  current record number
        INTEGER         LDEV    !  log file unit number
        INTEGER         NLINE   !  number of lines
        INTEGER         NPSTK   !  number of PSTK entries
        INTEGER         SID     !  temporary state ID

        REAL            HT      !  temporary height
        REAL            DM      !  temporary diameter
        REAL            TK      !  temporary exit temperature
        REAL            VE      !  temporary velocity

        LOGICAL      :: EFLAG = .FALSE.  !  error flag
        LOGICAL         DFLAG( NSRC )    ! true if source getting default parms

        CHARACTER(8)       FMTFIP    !  format for converting FIPs code
        CHARACTER(8)       FMTSTA    !  format for converting cntry/state
        CHARACTER(300)     BUFFER    !  temporary buffer
        CHARACTER(300)     MESG      !  message buffer
        CHARACTER(300)     LINE      !  read buffer for a line
        CHARACTER(FIPLEN3) CFIP      !  tmp character-string FIP
        CHARACTER(FIPLEN3) FIPZERO   !  zero buffer for FIPS code
        CHARACTER(STALEN3) CSTA      !  tmp country/state
        CHARACTER(CNYLEN3) CCNY      !  tmp county
        CHARACTER(SCCLEN3) TSCC      !  tmp SCC
        CHARACTER(SCCLEN3) SCCZERO   !  zero buffer for SCC
        CHARACTER(STSLEN3) CSTASCC   !  tmp country/state // SCC
        CHARACTER(STSLEN3) CSTASCCZ  !  zero buffer for cntry/state // SCC
        CHARACTER(FPSLEN3) CFIPSCC   !  tmp FIPS code // SCC
        CHARACTER(FPSLEN3) CFIPSCCZ  !  zero buffer for FIPS code // SCC

        CHARACTER(16) :: PROGNAME = 'FIXSTK'  ! program name
     
C***********************************************************************
C   begin body of subroutine FIXSTK

C.........   Get LOG file unit, so can write to directly (using M3MESG would
C            add too many spaces for some messages)
        LDEV = INIT3()

        CALL M3MSG2( 'Reading default stack parameters...' )

C.........  Get dimensions of input file
        NLINE = GETFLINE( FDEV, 'Stack replacement file')

C.........  Allocate memory for arrays.  Since this file is not likely to be
C           large, allocate all arrays based on number of lines in the file.
        ALLOCATE( INDXA( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INDXA', PROGNAME )
        ALLOCATE( SHTA( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SHTA', PROGNAME )
        ALLOCATE( SDMA( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SDMA', PROGNAME )
        ALLOCATE( STKA( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'STKA', PROGNAME )
        ALLOCATE( SVEA( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SVEA', PROGNAME )
        ALLOCATE( SFSCA( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SFSCA', PROGNAME )

C.........  Simply allocate for all lines. These inputs will not be large,
C           so the wasted memory will not matter
        ALLOCATE( TBL1( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'TBL1', PROGNAME )
        ALLOCATE( ID1( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ID1', PROGNAME )
        ALLOCATE( TBL2( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'TBL2', PROGNAME )
        ALLOCATE( ID2( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ID2', PROGNAME )
        ALLOCATE( TBL3( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'TBL3', PROGNAME )
        ALLOCATE( ID3( NLINE ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ID3', PROGNAME )

C.........  Create format for writing FIPS code and country/state code
        WRITE( FMTFIP, 94300 ) '(I', FIPLEN3  , '.', FIPLEN3, ')'
        WRITE( FMTSTA, 94300 ) '(I', FIPLEN3-3, '.', FIPLEN3-3, ')'

C.........  Create zero-filled buffers
        FIPZERO  = REPEAT( '0', FIPLEN3 )
        SCCZERO  = REPEAT( '0', SCCLEN3 )
        CSTASCCZ = REPEAT( '0', STSLEN3 )
        CFIPSCCZ = REPEAT( '0', FPSLEN3 )

C.........  Read the PSTK file until hit the end of the file
C.........  For now, require the SCC to be in quotes to use list formatting
        NCNT  = 0
        IREC  = 0
        DO I = 1, NLINE       !  head of input loop
        
            READ( FDEV, *, IOSTAT=IOS ) LINE
            IREC = IREC + 1
            
            IF ( IOS .GT. 0 ) THEN      !  I/O error
                WRITE( MESG,94010 ) 'I/O Error', IOS, 
     &                 'reading stack replacements file at line', IREC
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF
               
            IF( BLKORCMT( LINE ) ) THEN
                CYCLE
            ELSE
                BACKSPACE( FDEV )
            END IF
            
            READ( FDEV, *, IOSTAT=IOS ) FIP, TSCC, HT, DM, TK, VE
            NCNT = NCNT + 1      ! actual line #s after skipping blank and comments

            WRITE( CFIP, FMTFIP ) FIP

            CALL PADZERO( TSCC )

            INDXA( NCNT ) = NCNT
            SFSCA( NCNT ) = CFIP // TSCC
            SHTA ( NCNT ) = HT
            SDMA ( NCNT ) = DM
            STKA ( NCNT ) = TK
            SVEA ( NCNT ) = VE
        END DO  

        NPSTK = NCNT

C.........  Sort PSTK data 
        CALL SORTIC( NPSTK, INDXA, SFSCA )

C.........  Disaggregate PSTK data into 4 categories
        NR1   = 0
        NR2   = 0
        NR3   = 0
        L1    = FIPLEN3 - 3  ! without county
        L2    = L1 + 1
        L3    = FIPLEN3 + 1
        DO I = 1, NPSTK

            J    = INDXA( I )
            CFIP = SFSCA( J )( 1 :FIPLEN3 )
            CSTA = SFSCA( J )( 1 :L1 )
            CCNY = SFSCA( J )( L2:FIPLEN3 )
            TSCC = SFSCA( J )( L3:FPSLEN3 ) 

            IF( CFIP .EQ. FIPZERO .AND. 
     &          TSCC .EQ. SCCZERO       ) THEN  !  fallback default
                HT0 = SHTA ( J )
                DM0 = SDMA ( J )
                TK0 = STKA ( J )
                VE0 = SVEA ( J )

            ELSEIF( CFIP .EQ. FIPZERO ) THEN    !  SCC only
                NR1 = NR1 + 1
                TBL1( NR1 ) = TSCC
                ID1 ( NR1 ) = J

            ELSE IF( CCNY .EQ. '000' ) THEN     !  state and SCC
                NR2 = NR2 + 1
                TBL2( NR2 ) = CSTA // TSCC
                ID2 ( NR2 ) = J

            ELSE                                !  FIP and SCC
                NR3 = NR3 + 1
                TBL3( NR3 ) = CFIP // TSCC
                ID3 ( NR3 ) = J

            END IF

        END DO ! End loop on NPSTK
 
C.........  Bound stack parameters to minima and maxima values
C.........  This is in a separate loop to permit better reporting
C.........  Watch out for negative numbers or zeroes, because these are 
C.........  the missing stack parameters, which should get defaults.

        CALL M3MSG2( 'Bounding MIN and MAX stack parameters...' )

        DO S = 1, NSRC

            HT   = STKHT( S )
            DM   = STKDM( S )
            TK   = STKTK( S )
            VE   = STKVE( S )
            TSCC = CSCC ( S )

            IF ( HT .GT. MAXHT .OR.
     &         ( HT .LT. MINHT .AND. HT .GT. 0 ) .OR.
     &           DM .GT. MAXDM .OR.
     &         ( DM .LT. MINDM .AND. DM .GT. 0 ) .OR.
     &           TK .GT. MAXTK .OR.
     &         ( TK .LT. MINTK .AND. TK .GT. 0 ) .OR.
     &           VE .GT. MAXVE .OR.
     &         ( VE .LT. MINVE .AND. VE .GT. 0 ) ) THEN

                CALL FMTCSRC( CSOURC(S), 7, BUFFER, L2 )
                WRITE( MESG,94010 ) BUFFER( 1:L2 ) // ' SCC: '// TSCC
                CALL M3MESG( MESG )

            END IF

            IF ( HT .GT. MAXHT ) THEN
                WRITE( LDEV,94030 ) 'Height', HT, MAXHT
                HT = MAXHT

            ELSEIF( HT .LT. MINHT .AND. HT .GT. 0 ) THEN
                WRITE( LDEV,94040 ) 'Height', HT, MINHT
                HT = MINHT

            END IF

            IF ( DM .GT. MAXDM ) THEN
                WRITE( LDEV,94030 ) '  Diam', DM, MAXDM
                DM = MAXDM

            ELSEIF( DM .LT. MINDM .AND. DM .GT. 0 ) THEN
                WRITE( LDEV,94040 ) '  Diam', DM, MINDM
                DM = MINDM

            END IF

            IF ( TK .GT. MAXTK )THEN
                WRITE( LDEV,94030 ) '  Temp', TK, MAXTK
                TK = MAXTK

            ELSEIF( TK .LT. MINTK .AND. TK .GT. 0 ) THEN 
                WRITE( LDEV,94040 ) '  Temp', TK, MINTK
                TK = MINTK

            END IF

            IF ( VE .GT. MAXVE )THEN
                WRITE( LDEV,94030 ) ' Veloc', VE, MAXVE
                VE = MAXVE

            ELSEIF( VE .LT. MINVE .AND. VE .GT. 0 ) THEN
                WRITE( LDEV,94040 ) ' Veloc', VE, MINVE
                VE = MINVE
 
            END IF

            STKHT( S ) = HT
            STKDM( S ) = DM
            STKTK( S ) = TK
            STKVE( S ) = VE

        END DO ! Loop on sources

        CALL M3MSG2( 'Fixing MISSING stack parameters...' )

C...........   Now do replacements of MISSING stack parameters:
C...........   4 passes -- ht, dm, tk, ve
C...........   Treat parameters equal to 0 as missing

        DO S = 1, NSRC

            K = 0                ! Initialize K to test if replacements made
            DFLAG( S ) = .FALSE. ! Initialize DFLAG to test if defaults used

C.............  Set up temporary character strings
            FIP = IFIP( S )
            SID = FIP / 1000
            WRITE( CFIP, FMTFIP ) FIP
            WRITE( CSTA, FMTSTA ) SID
            TSCC = CSCC( S )
            CFIPSCC  = CFIP // TSCC
            CFIPSCCZ = CFIP // SCCZERO
            CSTASCC  = CSTA // TSCC
            CSTASCCZ = CSTA // SCCZERO
            
            IF ( STKHT( S ) .LE. 0.0 ) THEN
                
                K = FINDC( CFIPSCC, NR3, TBL3 )

                IF( K .LE. 0 ) 
     &              K = FINDC( CFIPSCCZ, NR3, TBL3 )

                IF ( K .GT. 0 ) THEN
                    J  = ID3 ( K )
                    HT = SHTA( J )
                    DM = SDMA( J )
                    TK = STKA( J )
                    VE = SVEA( J )
                ELSE
                    K = FINDC( CSTASCC, NR2, TBL2 )

                    IF( K .LE. 0 ) 
     &                  K = FINDC( CSTASCCZ, NR2, TBL2 )

                    IF ( K .GT. 0 ) THEN
                        J  = ID2 ( K )
                        HT = SHTA( J )
                        DM = SDMA( J )
                        TK = STKA( J )
                        VE = SVEA( J )
                    ELSE

                        K = FINDC( TSCC, NR1, TBL1 )
                        IF ( K .GT. 0 ) THEN
                            J  = ID1 ( K )
                            HT = SHTA( J )
                            DM = SDMA( J )
                            TK = STKA( J )
                            VE = SVEA( J )
                        ELSE
                            DFLAG( S ) = .TRUE.

                        END IF 
                    END IF 
                END IF 

                IF( .NOT. DFLAG( S ) ) THEN

                    CALL FMTCSRC( CSOURC(S), 7, BUFFER, L2)
                    WRITE( MESG,94010 ) 
     &                     BUFFER( 1:L2 ) // ' SCC: ' // TSCC //
     &                     CRLF() // BLANK5 // 
     &                     '             Old        New'
                    CALL M3MESG( MESG )

                    WRITE( LDEV,94020 )     'Height', STKHT( S ), HT
                    STKHT( S ) = HT

                    IF ( STKDM( S ) .LE. 0 ) THEN
                        WRITE( LDEV,94020 ) '  Diam', STKDM( S ), DM
                        STKDM( S ) = DM
                    END IF

                    IF ( STKTK( S ) .LE. 0 ) THEN
                        WRITE( LDEV,94020 ) '  Temp', STKTK( S ), TK
                        STKTK( S ) = TK
                    END IF 

                    IF ( STKVE( S ) .LE. 0 ) THEN
                        WRITE( LDEV,94020 ) ' Veloc', STKVE( S ), VE
                        STKVE( S ) = VE
                    END IF
                END IF

            END IF      !  if stack height bad

            IF ( STKDM( S ) .LE. 0.0 ) THEN
                K = FINDC( CFIPSCC, NR3, TBL3 )

                IF( K .LE. 0 ) 
     &              K = FINDC( CFIPSCCZ, NR3, TBL3 )

                IF ( K .GT. 0 ) THEN
                    J  = ID3 ( K )
                    DM = SDMA( J )
                    TK = STKA( J )
                    VE = SVEA( J )
                ELSE
                    K = FINDC( CSTASCC, NR2, TBL2 )

                    IF( K .LE. 0 ) 
     &                  K = FINDC( CSTASCCZ, NR2, TBL2 )

                    IF ( K .GT. 0 ) THEN
                        J  = ID2 ( K )
                        DM = SDMA( J )
                        TK = STKA( J )
                        VE = SVEA( J )
                    ELSE
                        K = FINDC( TSCC, NR1, TBL1 )
                        IF ( K .GT. 0 ) THEN
                            J  = ID1 ( K )
                            DM = SDMA( J )
                            TK = STKA( J )
                            VE = SVEA( J )
                        ELSE
                            DFLAG( S ) = .TRUE.

                        END IF 
                    END IF 
                END IF 

                IF( .NOT. DFLAG( S ) ) THEN

                    CALL FMTCSRC( CSOURC(S), 7, BUFFER, L2)
                    WRITE( MESG,94010 ) 
     &                     BUFFER( 1:L2 ) // ' SCC: ' // TSCC //
     &                     CRLF() // BLANK5 // 
     &                     '             Old        New'
                    CALL M3MESG( MESG )

                    WRITE( LDEV,94020 ) '  Diam', STKDM( S ), DM
                    STKDM( S ) = DM

                    IF ( STKTK( S ) .LE. 0 ) THEN
                        WRITE( LDEV,94020 ) '  Temp', STKTK( S ), TK
                        STKTK( S ) = TK
                    END IF 

                    IF ( STKVE( S ) .LE. 0 ) THEN
                        WRITE( LDEV,94020 ) ' Veloc', STKVE( S ), VE
                        STKVE( S ) = VE
                    END IF
                END IF

            END IF      !  if stack diameter bad

            IF ( STKTK( S ) .LE. 0.0 ) THEN
                K = FINDC( CFIPSCC, NR3, TBL3 )

                IF( K .LE. 0 ) 
     &              K = FINDC( CFIPSCCZ, NR3, TBL3 )

                IF ( K .GT. 0 ) THEN
                    J  = ID3 ( K )
                    TK = STKA( J )
                    VE = SVEA( J )
                ELSE
                    K   = FINDC( CSTASCC, NR2, TBL2 )

                    IF( K .LE. 0 ) 
     &                  K = FINDC( CSTASCCZ, NR2, TBL2 )

                    IF ( K .GT. 0 ) THEN
                        J  = ID2 ( K )
                        TK = STKA( J )
                        VE = SVEA( J )
                    ELSE
                        K = FINDC( TSCC, NR1, TBL1 )
                        IF ( K .GT. 0 ) THEN
                            J  = ID1 ( K )
                            TK = STKA( J )
                            VE = SVEA( J )
                        ELSE
                            DFLAG( S ) = .TRUE.

                        END IF 
                    END IF 
                END IF 

                IF( .NOT. DFLAG( S ) ) THEN

                    CALL FMTCSRC( CSOURC(S), 7, BUFFER, L2)
                    WRITE( MESG,94010 ) 
     &                     BUFFER( 1:L2 ) // ' SCC: ' // TSCC //
     &                     CRLF() // BLANK5 // 
     &                     '             Old        New'
                    CALL M3MESG( MESG )

                    WRITE( LDEV,94020 ) '  Temp', STKTK( S ), TK
                    STKTK( S ) = TK

                    IF ( STKVE( S ) .LE. 0 ) THEN
                        WRITE( LDEV,94020 ) ' Veloc', STKVE( S ), VE
                        STKVE( S ) = VE
                    END IF
                END IF

            END IF      !  if stack exhaust temperature bad

            IF ( STKVE( S ) .LE. 0.0 ) THEN
                K = FINDC( CFIPSCC, NR3, TBL3 )

                IF( K .LE. 0 ) 
     &              K = FINDC( CFIPSCCZ, NR3, TBL3 )

                IF ( K .GT. 0 ) THEN
                    J  = ID3 ( K )
                    VE = SVEA( J )
                ELSE
                    K = FINDC( CSTASCC, NR2, TBL2 )

                    IF( K .LE. 0 ) 
     &                  K = FINDC( CSTASCCZ, NR2, TBL2 )

                    IF ( K .GT. 0 ) THEN
                        J  = ID2 ( K )
                        VE = SVEA( J )
                    ELSE
                        K = FINDC( TSCC, NR1, TBL1 )
                        IF ( K .GT. 0 ) THEN
                            J  = ID1 ( K )
                            VE = SVEA( J )
                        ELSE
                            DFLAG( S ) = .TRUE.

                        END IF 
                    END IF 
                END IF 

                IF( .NOT. DFLAG( S ) ) THEN

                    CALL FMTCSRC( CSOURC(S), 7, BUFFER, L2)
                    WRITE( MESG,94010 ) 
     &                     BUFFER( 1:L2 ) // ' SCC: ' // TSCC //
     &                     CRLF() // BLANK5 // 
     &                     '             Old        New'
                    CALL M3MESG( MESG )

                    WRITE( LDEV,94020 ) ' Veloc', STKVE( S ), VE
                    STKVE( S ) = VE
                END IF

            END IF      !  if stack exhaust velocity bad

        END DO  !  end loop on sources for fixing missing stack parameters

C.........  Apply ultimate fallback parameters, and write report
C.........  This is in a separate loop to permit better reporting
     
        CALL M3MESG( 'Ultimate fallback stack parameters report:' )

        DO S = 1, NSRC

            IF( DFLAG( S ) ) THEN

                CALL FMTCSRC( CSOURC(S), 7, BUFFER, L2 )

                WRITE( MESG,94010 ) 
     &                 BUFFER( 1:L2 ) // ' SCC: ' // TSCC //
     &                 CRLF() // BLANK5 // 
     &                 '             Old        New'
                CALL M3MESG( MESG )

                IF ( STKHT( S ) .LE. 0 ) THEN
                    WRITE( LDEV,94020 ) 'Height', STKHT( S ), HT0
                    STKHT( S ) = HT0
                END IF

                IF ( STKDM( S ) .LE. 0 ) THEN
                    WRITE( LDEV,94020 ) '  Diam', STKDM( S ), DM0
                    STKDM( S ) = DM0
                END IF

                IF ( STKTK( S ) .LE. 0 ) THEN
                    WRITE( LDEV,94020 ) '  Temp', STKTK( S ), TK0
                    STKTK( S ) = TK0
                END IF 

                IF ( STKVE( S ) .LE. 0 ) THEN
                    WRITE( LDEV,94020 ) ' Veloc', STKVE( S ), VE0
                    STKVE( S ) = VE0
                END IF

            END IF

        END DO  ! Loop through sources for applying ultimate fallbacks

        DEALLOCATE( INDXA )
        DEALLOCATE( SFSCA )
        DEALLOCATE( SHTA )
        DEALLOCATE( SDMA )
        DEALLOCATE( STKA )
        DEALLOCATE( SVEA )
        DEALLOCATE( TBL1 )
        DEALLOCATE( ID1 )
        DEALLOCATE( TBL2 )
        DEALLOCATE( ID2 )
        DEALLOCATE( TBL3 )
        DEALLOCATE( ID3 )

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10 ( A, :, I8, :, 1X ) )

94020   FORMAT( 7X, A, 2X, E10.3, 1X, E10.3 )

94030   FORMAT( 7X, A6, 1X, '> max.  Change from ', 
     &          E10.3, ' to ', E10.3 )

94040   FORMAT( 7X, A6, 1X, '< min.  Change from ', 
     &          E10.3, ' to ', E10.3 )

94050   FORMAT( A4, A6 )

94300   FORMAT( A, I2.2, A, I2.2, A )

        END SUBROUTINE FIXSTK

