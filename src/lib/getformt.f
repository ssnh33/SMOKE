
        INTEGER FUNCTION GETFORMT( FDEV, EXTFORMAT )

C***********************************************************************
C  function body starts at line 109
C
C  DESCRIPTION:
C      This function returns the format of the inventory file, assuming that
C      the source category is already known.
C
C  PRECONDITIONS REQUIRED:
C      Inventory file opened on unit FDEV
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C      Subroutines: I/O API subroutine
C      Functions: I/O API functions, CHKINT, CHKREAL
C
C  REVISION  HISTORY:
C      Created 11/98 by M. Houyoux
C
C**************************************************************************
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

        IMPLICIT NONE

        CHARACTER(LEN=2), EXTERNAL :: CRLF

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  i/o api parameters

C...........   EXTERNAL FUNCTIONS:

C...........   SUBROUTINE ARGUMENTS
        INTEGER, INTENT(IN) :: FDEV       ! unit number of input point sources file
        INTEGER, INTENT(IN) :: EXTFORMAT  ! external format (used for list files)

C...........   Other local variables
        INTEGER         L, L1   ! indices
        INTEGER         IREC    ! current record number
        INTEGER         IOS     ! I/O status

        CHARACTER(LEN=256)   MESG        ! message buffer
        CHARACTER(LEN=100)   LINE        ! buffer to read line into

        CHARACTER(LEN=16) :: PROGNAME = 'GETFORMT'  ! program name

C***********************************************************************
C   begin body of function GETFORMT

        GETFORMT = IMISS3

C.........  Loop through lines of file
        IREC = 0
        DO

            READ( FDEV, 93000, IOSTAT=IOS ) LINE
            IREC = IREC + 1

C.............  Check for I/O errors
            IF( IOS > 0 ) THEN
                WRITE( MESG, 94010 )
     &                 'I/O error', IOS, 'reading inventory file ' //
     &                 'at line', IREC
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C.............  Check if we've reached the end of the file
            IF( IOS < 0 ) EXIT

C.............  Skip blank lines
            IF( LINE == ' ' ) CYCLE
 
C.............  Check for header lines
            L1 = INDEX( LINE, CINVHDR )
            IF( L1 .EQ. 1 ) THEN
            
C.................  Check if format is provided as a header entry

                L = INDEX( LINE, 'LIST' )
                IF( L .GT. 0 ) THEN
                    GETFORMT = LSTFMT
                    EXIT ! To end of read loop
                END IF

                L = INDEX( LINE, 'IDA' )
                IF( L .GT. 0 ) THEN
                    GETFORMT = IDAFMT
                    EXIT ! To end read loop
                END IF

                L = INDEX( LINE, 'EMS-95' )
                IF( L .GT. 0 ) THEN
                    GETFORMT = EMSFMT
                    EXIT ! To end read loop
                END IF

                L = INDEX( LINE, 'EPS2' )
                IF( L .GT. 0 ) THEN
                    GETFORMT = EPSFMT
                    EXIT ! To end read loop
                END IF

                L = INDEX( LINE, 'CEM' )
                IF( L .GT. 0 ) THEN
                    GETFORMT = CEMFMT
                    EXIT ! To end read loop
                END IF

                L = INDEX( LINE, 'TOXICS' )
                IF( L .GT. 0 ) THEN
                    L = INDEX( LINE, 'NONPOINT' )
                    IF( L .GT. 0 ) THEN
                        GETFORMT = TOXNPFMT
                        EXIT ! To end read loop
                    END IF
                    
                    GETFORMT = TOXFMT
                    EXIT ! To end read loop
                END IF

C.............  Otherwise, this is not a blank line, but also not a 
C               header line, so we're into the main body of the inventory
            ELSE
                EXIT

            END IF

        END DO     ! To head of read loop

C.........  Rewind inventory file
        REWIND( FDEV )

C.........  Check if an external format was passed in (used for list files)      
        IF( GETFORMT == IMISS3 ) THEN
            IF( EXTFORMAT /= -1 ) THEN
                GETFORMT = EXTFORMAT
            END IF
        END IF

C.........  If format has not been set, print error about missing header
        IF ( GETFORMT .EQ. IMISS3 ) THEN

            MESG = 'ERROR: Could not determine inventory file ' //
     &             'format due to missing or bad header ' //
     &             'information. ' // CRLF() // BLANK16 //
     &             'Valid headers are: ' // CRLF() // BLANK16 //
     &             '#LIST, #IDA, #EMS-95, #TOXICS, ' //
     &             '#TOXICS NONPOINT, or #CEM'
            CALL M3MSG2( MESG )
            CALL M3EXIT( PROGNAME, 0, 0, ' ', 2 )

        END IF

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

        END FUNCTION GETFORMT

