
        SUBROUTINE RDINVEN( FDEV, VDEV, SDEV, FNAME,
     &                      FILFMT, NRAWBP, TFLAG )

C***********************************************************************
C  subroutine body starts at line 133
C
C  DESCRIPTION:
C      This subroutine controls reading an ASCII inventory file for any source 
C      category from one of many formats.  It determines the format and 
C      calls the appropriate reader subroutines. It controls the looping 
C      through multiple files when a list-formatted file is used as input.
C
C  PRECONDITIONS REQUIRED:
C      Input file unit FDEV opened
C      Inventory pollutant list created: MXIDAT, INVDCOD, and INVDNAM
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C      Subroutines: I/O API subroutines, CHECKMEM, FMTCSRC, RDEMSPT, 
C                   RDEPSPT, RDIDAPT, RDLINES
C      Functions: I/O API functions, GETFLINE, GETFORMT, GETINVYR,
C         GETISIZE
C
C  REVISION  HISTORY:
C      Created 10/98 by M. Houyoux
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

C.........  This module is for mobile-specific data
        USE MODMOBIL

C.........  This module contains the lists of unique inventory information
        USE MODLISTS

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'CONST3.EXT'    !  physical and mathematical constants
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C...........   EXTERNAL FUNCTIONS and their descriptions:
        
        CHARACTER*2     CRLF
        LOGICAL         ENVYN
        INTEGER         GETFLINE
        INTEGER         GETFORMT
        INTEGER         GETINVYR
        INTEGER         JUNIT

        EXTERNAL        CRLF, ENVYN, GETFLINE, GETFORMT,  
     &                  GETINVYR, JUNIT

C...........   SUBROUTINE ARGUMENTS
        INTEGER     , INTENT (IN) :: FDEV              ! unit no. of inv file
        INTEGER     , INTENT (IN) :: VDEV              ! unit no. of vmtmix file
        INTEGER     , INTENT (IN) :: SDEV              ! unit no. of speeds file
        CHARACTER(*), INTENT (IN) :: FNAME             ! logical name of file
        INTEGER     , INTENT(OUT) :: FILFMT            ! file format code
        INTEGER     , INTENT(OUT) :: NRAWBP            ! no. raw records x pol
        LOGICAL     , INTENT(OUT) :: TFLAG             ! true: PTREF output

C...........   Contents of PTFILE 
        CHARACTER*300,ALLOCATABLE:: NLSTSTR( : )! Char strings in list-fmt file

C...........   Dropped emissions
        INTEGER         NDROP             !  number of records dropped
        REAL            EDROP  ( MXIDAT ) !  total dropped for each pol/activity

C...........   File units and logical/physical names
        INTEGER         EDEV( 5 )   !  up to 5 EMS-95 emissions files
        INTEGER         TDEV        !  file listed in list formatted input file

C...........   Other local variables
        INTEGER         I, J, L, L1, L2 !  counters and indices

        INTEGER         ERRIOS      !  error i/o stat from sub call(s)
        INTEGER         ERRREC      !  record number for error msgs
        INTEGER      :: INY = 0     !  tmp inventory year
        INTEGER         IOS         !  i/o status
        INTEGER         INVFMT      !  inventory format code
        INTEGER         FLEN        !  length of FNAME string
        INTEGER         NEDIM1      !  1st dimension for sparse emis arrays
        INTEGER         NLINE       !  number of lines
        INTEGER         NRAWIN      !  total raw record-count (estimate)
        INTEGER         NRAWOUT     !  no. of valid entries in emis file(s)
        INTEGER         WKSET       !  setting for wkly profile TPFLAG component

        LOGICAL      :: EFLAG  = .FALSE. ! true: error occured
        LOGICAL      :: DFLAG  = .FALSE. ! true: weekday (not full week) nrmlizr 
        LOGICAL      :: KFLAG  = .FALSE. ! true: kill routine b/c of error 

        CHARACTER*16    ERFILDSC    !  desc of file creating an error from sub
        CHARACTER*300   INFILE      !  input file line buffer
        CHARACTER*300   LINE        !  input file line buffer
        CHARACTER*300   MESG        !  message buffer

        CHARACTER*16 :: PROGNAME =  'RDINVEN' ! program name

C***********************************************************************
C   begin body of subroutine RDINVEN

        FLEN   = LEN_TRIM( FNAME )

C.........  Determine file format of inventory file
        INVFMT = GETFORMT( FDEV )
        
C.........   Initialize variables for keeping track of dropped emissions
        NDROP = 0
        EDROP = 0.  ! array

C.........  If SMOKE list format, read file and check file for formats.
C           NOTE- LSTFMT defined in EMCNST3.EXT
        IF( INVFMT .EQ. LSTFMT ) THEN

C.............  Generate message for GETFLINE and RDLINES calls
            MESG = CATEGORY( 1:CATLEN ) // ' inventory file, ' //
     &             FNAME( 1:FLEN ) // ', in list format'

C.............  Get number of lines of inventory files in list format
            NLINE = GETFLINE( FDEV, MESG )

C.............  Allocate memory for storing contents of list-format'd PTINV file
            ALLOCATE( NLSTSTR( NLINE ), STAT=IOS )
            CALL CHECKMEM( IOS, 'NLSTSTR', PROGNAME )

C.............  Store lines of PTINV file
            CALL RDLINES( FDEV, MESG, NLINE, NLSTSTR )

C.............  Check the format of the list-formatted inventory file and
C               return the code for the type of files it contains
            CALL CHKLSTFL( NLINE, FNAME, NLSTSTR, FILFMT )

C.........  If not list format, then set FILFMT to the type of file (IDA,EPS)
        ELSE

            FILFMT = INVFMT
 
        END IF

C.........  Get setting for interpreting weekly temporal profiles from the
C           environment. Default is false for non-EMS-95 and true for EMS-95
C           inventory inputs.
        DFLAG = .FALSE.
        IF ( FILFMT .EQ. EMSFMT ) DFLAG = .TRUE.
        MESG = 'Use weekdays only to normalize weekly profiles'
        DFLAG = ENVYN( 'WKDAY_NORMALIZE', MESG, DFLAG, IOS )

C.........  Set weekly profile interpretation flag...
C.........  Weekday normalized
        IF( DFLAG ) THEN
            WKSET = WDTPFAC
            MESG = 'NOTE: Setting inventory to use weekday '//
     &             'normalizer for weekly profiles'

C.........  Full-week normalized
        ELSE
            WKSET = WTPRFAC
            MESG = 'NOTE: Setting inventory to use full-week '//
     &             'normalizer for weekly profiles'

        END IF

C.........  Write message
        CALL M3MSG2( MESG )

C.........  If EMS-95 format, check the setting for the interpretation of
C           the weekly profiles
        IF( FILFMT .EQ. EMSFMT .AND. WKSET .NE. WDTPFAC ) THEN

            MESG = 'WARNING: EMS-95 format files will be using ' //
     &             'non-standard approach of ' // CRLF() // BLANK10 //
     &             'full-week normalized weekly profiles.  Can ' //
     &             'correct by setting ' // CRLF() // BLANK10 //
     &             'WKDAY_NORMALIZE to Y and rerunning.'
            CALL M3MSG2( MESG )

        ELSE IF( FILFMT .EQ. EPSFMT .AND. WKSET .NE. WTPRFAC ) THEN

            MESG = 'WARNING: EPS2.0 format files will be using ' //
     &             'non-standard approach of ' // CRLF() // BLANK10 //
     &             'weekday normalized weekly profiles.  Can ' //
     &             'correct by setting ' // CRLF() // BLANK10 //
     &             'WKDAY_NORMALIZE to N and rerunning.'
            CALL M3MSG2( MESG )

        END IF

C.........  Set default inventory characteristics (declared in MODINFO) used
C           by the IDA and EPS formats, including NPPOL
        CALL INITINFO( FILFMT )

C.........  Read vehicle mix, if it is available
C.........  The tables are passed through MODMOBIL and MODXREF
        IF( VDEV .GT. 0 ) THEN
            CALL RDVMIX( VDEV )
        END IF

C.........  Read speeds info, if it is available
C.........  The tables are passed through MODMOBIL and MODXREF
        IF( SDEV .GT. 0 ) THEN
c            CALL RDSPEED( SDEV )
c note: write this routine
        END IF

C.........  Get the total number of records (Srcs x Non-missing pollutants)
C.........  Depending on the format, NRAWIN can equal NEDIM1, or 
C           NEDIM1 can equal NRAWIN * NIPPA. This second case does not hold
C           true if there are multiple input files from list format, with 
C           different number of data variables in each file.
        CALL GETISIZE( FDEV, CATEGORY, INVFMT, NRAWIN, NEDIM1 ) ! Est records

C.........  For EMS-95 mobile sources, need to multiply the sizes by the
C           number of vehicle types
        IF( CATEGORY .EQ. 'MOBILE' .AND. FILFMT .EQ. EMSFMT ) THEN
            NRAWIN = NRAWIN * NVTYPE
            NEDIM1 = NEDIM1 * NVTYPE
        END IF

C.........  Allocate memory for (unsorted) input arrays using dimensions set
C           based on the source category and type of inventory being input
        CALL SRCMEM( CATEGORY, 'UNSORTED', .TRUE., .FALSE., NRAWIN, 
     &               NEDIM1, NPPOL )

        CALL SRCMEM( CATEGORY, 'UNSORTED', .TRUE., .TRUE., NRAWIN, 
     &               NEDIM1, NPPOL )

C.........   Initialize sorting index and input record index
C.........   For EMS-95 and EPS formats, these arrays are simply arrays of
C            ones.  They are used to restructure the IDA formatted data that
C            contain multiple data records on each line, in any order.
        DO I = 1, NEDIM1
            INDEXA( I ) = I
            INRECA( I ) = I
        END DO

C.........  Initialize pollutant-specific values as missing
        POLVLA = BADVAL3  ! array

C.........  Read emissions from raw file(s) depending on input format...

C.........  IDA format (single file)
        IF( INVFMT .EQ. IDAFMT ) THEN

            SELECT CASE( CATEGORY )
            CASE( 'AREA' )
                CALL RDIDAAR( FDEV, NRAWIN, NEDIM1, WKSET, 
     &                        NRAWOUT, EFLAG, NDROP, EDROP )

            CASE( 'MOBILE' )
                
                CALL RDIDAMB( FDEV, NRAWIN, NEDIM1, WKSET, 
     &                        NRAWOUT, EFLAG, NDROP, EDROP )

            CASE( 'POINT' )
                CALL RDIDAPT( FDEV, NRAWIN, NEDIM1, WKSET, 
     &                        NRAWOUT, EFLAG, NDROP, EDROP )

            END SELECT

            KFLAG = ( KFLAG .OR. EFLAG )  ! overall subroutine kill

            NRAWBP = NRAWOUT 

C.........  EPS format (single file)
        ELSEIF( INVFMT .EQ. EPSFMT ) THEN

            SELECT CASE( CATEGORY )
            CASE( 'AREA' )
                CALL RDEPSAR( FDEV, NRAWIN, WKSET, INY, NRAWOUT, 
     &                        ERRIOS, ERRREC, ERFILDSC, EFLAG, 
     &                        NDROP, EDROP )

            CASE( 'MOBILE' )
c                CALL RDEPSMV(  )

            CASE( 'POINT' )
                CALL RDEPSPT( FDEV, NRAWIN, WKSET, 
     &                        INY, NRAWOUT, ERRIOS, ERRREC, 
     &                        ERFILDSC, EFLAG, NDROP, EDROP )

            END SELECT

            KFLAG = ( KFLAG .OR. EFLAG )  ! overall subroutine kill

            NRAWBP = NRAWOUT

C.........  NTI 1996 format.  THIS FEATURE IS NOT SUPPORTED IN SMOKE.
        ELSE IF( INVFMT .EQ. NTIFMTA ) THEN

            SELECT CASE( CATEGORY )
            CASE( 'AREA' )
                CALL RDNTIAR( FDEV )
            END SELECT

C.........  SMOKE list format requires a loop for multiple files
C.........  Includes EMS-95 format
        ELSEIF( INVFMT .EQ. LSTFMT ) THEN  

            INY = IMISS3
            J   = 0
            DO             ! Loop through lines of the list-formatted file

                J = J + 1  ! Can't use standard loop because J used also below
                IF( J .GT. NLINE ) EXIT

                LINE = NLSTSTR( J )

                I = GETINVYR( LINE )

                IF( I .GT. 0 ) THEN
                    INY = I
                    CYCLE
                END IF

C.................  Final check to ensure the inventory year is set when needed
                IF( INY .LT. 0 .AND. FILFMT .EQ. EMSFMT ) THEN  
                    MESG = 'Must set inventory year using ' //
     &                     'INVYEAR packet for EMS-95 input.'
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF
     
C.................  Store path of file name (if no INVYEAR packet on this line)
                INFILE = LINE

C.................  Open INFILE
                TDEV = JUNIT()
                OPEN( TDEV, ERR=1006, FILE=INFILE, STATUS='OLD' )

                WRITE( MESG,94010 ) 'Successful OPEN for ' //
     &                 'inventory file(s):' // CRLF() // BLANK5 //
     &                 INFILE( 1:LEN_TRIM( INFILE ) )
                CALL M3MSG2( MESG ) 

C.................  Read file based on format set above
                IF( FILFMT .EQ. IDAFMT ) THEN

                    SELECT CASE( CATEGORY )
                    CASE( 'AREA' )
                        CALL RDIDAAR( TDEV, NRAWIN, NEDIM1, WKSET, 
     &                                NRAWOUT, EFLAG, NDROP, EDROP )

                    CASE( 'MOBILE' )
                        CALL RDIDAMB( TDEV, NRAWIN, NEDIM1, WKSET, 
     &                                NRAWOUT, EFLAG, NDROP, EDROP  )
     &                                

                    CASE( 'POINT' )
                        CALL RDIDAPT( TDEV, NRAWIN, NEDIM1, WKSET, 
     &                                NRAWOUT, EFLAG, NDROP, EDROP )

                    END SELECT

                    KFLAG = ( KFLAG .OR. EFLAG )  ! overall subroutine kill
                    CLOSE( TDEV )

                ELSEIF( FILFMT .EQ. EPSFMT ) THEN

                    SELECT CASE( CATEGORY )
                    CASE( 'AREA' )
                        CALL RDEPSAR( TDEV, NRAWIN, WKSET, INY, NRAWOUT, 
     &                                ERRIOS, ERRREC, ERFILDSC, EFLAG, 
     &                                NDROP, EDROP )

                    CASE( 'MOBILE' )
c                        CALL RDEPSMV(  )

                    CASE( 'POINT' )
                        CALL RDEPSPT( TDEV, NRAWIN, WKSET, INY, NRAWOUT, 
     &                                ERRIOS, ERRREC, ERFILDSC, EFLAG, 
     &                                NDROP, EDROP )

                    END SELECT

                    KFLAG = ( KFLAG .OR. EFLAG )  ! overall subroutine kill
                    CLOSE( TDEV )

                ELSEIF( FILFMT .EQ. EMSFMT ) THEN

                    EDEV( 1 ) = TDEV  ! Store first file unit number
 
C.....................  Make sure that next 4 files in list are also EMSFMT
C.....................  Increment line, scan for INVYEAR, open file, check file,
C                       write message, and store unit number.
                    DO I = 2, NEMSFILE

                        J = J + 1
                        LINE = NLSTSTR( J )
                        INFILE = LINE( 1:LEN_TRIM( LINE ) )
                        IF( INDEX( INFILE,'INVYEAR' ) .GT. 0 ) GOTO 1007 !Error
                        TDEV = JUNIT()
                        OPEN( TDEV, ERR=1006, FILE=INFILE, STATUS='OLD')
                        FILFMT = GETFORMT( TDEV )
                        IF( FILFMT .NE. EMSFMT ) GO TO 1008  ! Error
                        CALL M3MSG2( INFILE( 1:LEN_TRIM( INFILE ) ) )
                        EDEV( I ) = TDEV

                    END DO

C.....................  Call EMS-95 reader for current 5 files
C.....................  These calls populate the unsorted inventory 
C                       variables in the module MODSOURC
                    SELECT CASE( CATEGORY )
                    CASE( 'AREA' )
                        CALL RDEMSAR( EDEV, INY, NRAWIN, WKSET, NRAWOUT, 
     &                                ERRIOS, ERRREC, ERFILDSC, EFLAG, 
     &                                NDROP, EDROP )

C.....................  The mobile call can be for EMS-95 format or for
C                       a list-formatted format that is similar and that was
C                       used in the SMOKE prototype
                    CASE( 'MOBILE' )
                        CALL RDEMSMB( EDEV, INY, NRAWIN, NEDIM1, WKSET, 
     &                                NRAWOUT, ERRIOS, ERRREC, ERFILDSC, 
     &                                EFLAG, NDROP, EDROP )

c note: Will have set a flag above so that after the VMT data are read
C    n: in, the process of converting the SCCs and expanding using the
C    n: vehicle mix will take place.

                    CASE( 'POINT' )
                        TFLAG = .TRUE.
                        CALL RDEMSPT( EDEV, INY, NRAWIN, WKSET,NRAWOUT, 
     &                                ERRIOS, ERRREC, ERFILDSC, EFLAG, 
     &                                NDROP, EDROP )
 
                    END SELECT

                    KFLAG = ( KFLAG .OR. EFLAG )  ! overall subroutine kill

                    IF( ERRIOS .GT. 0 ) THEN

                        L2 = LEN_TRIM( ERFILDSC )
                        WRITE( MESG, 94010 ) 
     &                         'Error ', ERRIOS,  'reading ' // 
     &                         ERFILDSC( 1:L2 ) // ' file at line', 
     &                         ERRREC
                        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

                    ELSEIF( EFLAG ) THEN
                        MESG = 'Problem reading EMS-95 inventory files.'
                        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

                    END IF

C.....................  Close EMS-95 files
                    DO I = 1, NEMSFILE
                        CLOSE( EDEV( I ) )
                    END DO

                ELSE  ! File format not recognized	

                    MESG = 'File format is not recognized for file. ' //
     &                     CRLF() // BLANK10 // 
     &                     INFILE( 1:LEN_TRIM( INFILE ) )
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

                END IF

            END DO     ! End of loop through list-formatted PTINV file

C.............  Set exact pollutant times records
            NRAWBP = NRAWOUT

        END IF

C.........  Report how many records were dropped and the numbers involved
        IF( NDROP .GT. 0 ) THEN

            WRITE( MESG,94010 ) 'WARNING:', NDROP, 
     &             'input data records dropped.  This has resulted'  //
     &             CRLF() // BLANK10 //
     &             'in the following amounts of ' //
     &             'lost data (emissions are in tons/year):'
            CALL M3MSG2( MESG )

            DO I = 1, MXIDAT

                IF( EDROP( I ) .GT. 0. ) THEN
                    WRITE( MESG,94060 ) 
     &                     BLANK16 // INVDNAM( I ) // ': ', EDROP( I )
                    CALL M3MSG2( MESG )
                END IF

            END DO

        END IF          !  if ndrop > 0

C.........  Abort if there was a reading error
        IF( KFLAG ) THEN
           MESG = 'Error reading raw inventory file ' // FNAME( 1:FLEN )
           CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

        RETURN

C******************  ERROR MESSAGES WITH EXIT **************************

C.........  Error opening raw input file
1006    WRITE( MESG,94010 ) 'Problem at line ', J, 'of ' //
     &         FNAME( 1:FLEN ) // '.' // ' Could not open file:' //
     &         CRLF() // BLANK5 // INFILE( 1:LEN_TRIM( INFILE ) )
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.........  Error with INVYEAR packet read
1007    WRITE( MESG,94010 ) 'Problem at line ', J, 'of ' // 
     &         FNAME( 1:FLEN ) // '.' // CRLF() // BLANK10 // 
     &         'INVYEAR packet can be used only once for each ' //
     &         'group of five EMS-95 files.'
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.........  Error with number of EMS-95 files
1008    WRITE( MESG,94010 ) 'Problem at line ', J, 'of ' //
     &         FNAME( 1:FLEN ) // '.' // CRLF() // BLANK10 // 
     &        'EMS-95 files must be in groups of five.'
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94060   FORMAT( 10( A, :, E10.3, :, 1X ) )

        END SUBROUTINE RDINVEN
