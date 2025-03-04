#!/bin/csh -f

#######################################################################
#                     Batch Parameters for Run Job
#######################################################################

#PBS -l walltime=@CONVERT_T
#@CONVERT_P
#PBS -N @CONVERT_N
#@RUN_Q
#@BATCH_GROUP

#######################################################################
#                  System Environment Variables
#######################################################################

umask 022

limit stacksize unlimited

@SETENVS

#######################################################################
#           Architecture Specific Environment Variables
#######################################################################

setenv ARCH `uname`

setenv SITE             @SITE
setenv GEOSBIN          @GEOSBIN 
setenv RUN_CMD         "@RUN_CMD"
setenv GCMVER           @GCMVER

echo "Sourcing g5_modules in $GEOSBIN"
source $GEOSBIN/g5_modules >& /dev/null
setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${BASEDIR}/${ARCH}/lib

#######################################################################
#             Experiment Specific Environment Variables
#######################################################################

setenv    EXPID   @EXPID
setenv    EXPDIR  @EXPDIR
setenv    CNVDIR  @CNVDIR
setenv    HOMDIR  @HOMDIR
setenv    SCRDIR  $CNVDIR/scratch
setenv    ORGDIR  $CNVDIR/original_restarts
setenv    RSTDIR  $CNVDIR/converted_restarts

#######################################################################
#                 Create Experiment Sub-Directories
#######################################################################

if (! -e $SCRDIR) mkdir -p $SCRDIR
if (! -e $RSTDIR) mkdir -p $RSTDIR
if (! -e $ORGDIR) mkdir -p $ORGDIR

#######################################################################
#                   Clear Restarts Sub-Directories
#######################################################################

/bin/rm -f $RSTDIR/* >& /dev/null
/bin/rm -f $ORGDIR/* >& /dev/null

#######################################################################
#                   Set Experiment Run Parameters
#######################################################################

set       NX = `grep  "^ *NX:" $HOMDIR/AGCM.rc | cut -d':' -f2`
set       NY = `grep  "^ *NY:" $HOMDIR/AGCM.rc | cut -d':' -f2`
set  AGCM_IM = `grep  AGCM_IM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  AGCM_JM = `grep  AGCM_JM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  AGCM_LM = `grep  AGCM_LM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  OGCM_IM = `grep  OGCM_IM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  OGCM_JM = `grep  OGCM_JM: $HOMDIR/AGCM.rc | cut -d':' -f2`
>>>COUPLED<<<set       NX = `grep  OGCM_NX: $HOMDIR/AGCM.rc | cut -d':' -f2`
>>>COUPLED<<<set       NY = `grep  OGCM_NY: $HOMDIR/AGCM.rc | cut -d':' -f2`

# Set ATMOS and OCEAN Horizontal Resolution Tags
# ----------------------------------------------
set AGCM_IM_Tag = `echo $AGCM_IM | awk '{printf "%4.4i", $1}'`
set AGCM_JM_Tag = `echo $AGCM_JM | awk '{printf "%4.4i", $1}'`
set OGCM_IM_Tag = `echo $OGCM_IM | awk '{printf "%4.4i", $1}'`
set OGCM_JM_Tag = `echo $OGCM_JM | awk '{printf "%4.4i", $1}'`

>>>FVLATLON<<<set ATMOStag = DC${AGCM_IM_Tag}xPC${AGCM_JM_Tag}
>>>FVCUBED<<<set ATMOStag = CF${AGCM_IM_Tag}x6C
>>>DATAOCEAN<<<set OCEANtag = DE${OGCM_IM_Tag}xPE${OGCM_JM_Tag}
>>>COUPLED<<<set OCEANtag = TM${OGCM_IM_Tag}xTM${OGCM_JM_Tag}

#######################################################################
#   Move to Scratch Directory and Copy RC Files from Home Directory
#######################################################################

cd $SCRDIR
/bin/rm -rf * >& /dev/null
                             /bin/ln -sf $EXPDIR/RC/* .
                             @CPEXEC -f  $HOMDIR/*.rc .

if(-e ExtData.rc )    /bin/rm -f   ExtData.rc
set  extdata_files = `/bin/ls -1 *_ExtData.rc`
cat $extdata_files > ExtData.rc

#######################################################################
#           Determine where and what type our restarts are
#######################################################################

unsetenv FNDDIR

set fv_rst = `cat AGCM.rc | grep "^DYN_INTERNAL_RESTART_FILE"  | cut -d ":" -f2`

if (-e $CNVDIR/$fv_rst ) then
   setenv FNDDIR $CNVDIR
else if (-e $HOMDIR/$fv_rst ) then
   setenv FNDDIR $HOMDIR
else if (-e $EXPDIR/$fv_rst ) then
   setenv FNDDIR $EXPDIR
endif

if ( ! $?FNDDIR ) then
  echo "Couldn't find a dynamics internal restart file."
  echo "Note also that this code does not support prefixes to restart file names."
  exit 4
endif

set filetype = `/usr/bin/file -Lb --mime-type $FNDDIR/$fv_rst`

set fileext = `echo $fv_rst | tail - -c 5`

if ( $filetype =~ "application/x-hdf*" ) then
   set fromformat = "NetCDF4"
   set fromtype   = "pnc4"
   set fromext    = ".nc4"

   set toformat   = "binary"
   set totype     = "binary"
   set toext      = ".bin"
else
   set fromformat = "binary"
   set fromtype   = "binary"
   set fromext    = ".bin"

   set toformat   = "NetCDF4"
   set totype     = "pnc4"
   set toext      = ".nc4"
endif

if ( $fileext == "_rst" ) then
   set fromext = ""
endif

echo "Found $fromformat $fv_rst in $FNDDIR"
echo "Converting from $fromformat restarts to $toformat restarts"

#######################################################################
#                     Copy cap_restart into SCRDIR
#######################################################################

echo "Copying cap_restart into $SCRDIR for BCs"

if (-e $FNDDIR/cap_restart) then
  @CPEXEC $FNDDIR/cap_restart .
else
  echo "Couldn't find cap_restart in $FNDDIR. Please place"
  echo "cap_restart in the same directory as the restarts."
  exit 5
endif

#######################################################################
#                        Link Boundary Datasets
#######################################################################

setenv BCSDIR   @BCSDIR
setenv SSTDIR   @SSTDIR
setenv CHMDIR   @CHMDIR
setenv BCRSLV   ${ATMOStag}_${OCEANtag}
setenv DATELINE DC

>>>COUPLED<<<setenv GRIDDIR  @COUPLEDIR/a${AGCM_IM}x${AGCM_JM}_o${OGCM_IM}x${OGCM_JM}
>>>COUPLED<<<setenv BCTAG `basename $GRIDDIR`
>>>DATAOCEAN<<<setenv BCTAG `basename $BCSDIR`

>>>OSTIA<<<set YEAR = `cat cap_restart | cut -c1-4`

set             FILE = linkbcs
/bin/rm -f     $FILE
cat << _EOF_ > $FILE
#!/bin/csh -f

>>>COUPLED<<</bin/mkdir -p RESTART
/bin/mkdir -p            ExtData
/bin/ln    -sf $CHMDIR/* ExtData

>>>COUPLED<<</bin/ln -s $GRIDDIR/SEAWIFS_KPAR_mon_clim.${OGCM_IM}x${OGCM_JM}               SEAWIFS_KPAR_mon_clim.data
>>>COUPLED<<</bin/ln -s $GRIDDIR/${BCRSLV}-Pfafstetter.til   tile.data
>>>COUPLED<<</bin/ln -s $GRIDDIR/${BCRSLV}-Pfafstetter.TRN   runoff.bin
>>>COUPLED<<</bin/ln -s $GRIDDIR/tripolar_${OGCM_IM}x${OGCM_JM}.ascii .
>>>COUPLED<<</bin/ln -s $GRIDDIR/vgrid50.ascii ./vgrid.ascii

>>>DATAOCEAN<<</bin/ln -sf $SSTDIR/@SSTFILE   sst.data
>>>DATAOCEAN<<</bin/ln -sf $SSTDIR/@ICEFILE fraci.data
>>>DATAOCEAN<<</bin/ln -sf $SSTDIR/@KPARFILE SEAWIFS_KPAR_mon_clim.data

>>>DATAOCEAN<<</bin/ln -sf $BCSDIR/$BCRSLV/${BCRSLV}-Pfafstetter.til  tile.data
>>>DATAOCEAN<<<if(     -e  $BCSDIR/$BCRSLV/${BCRSLV}-Pfafstetter.TIL) then
>>>DATAOCEAN<<</bin/ln -sf $BCSDIR/$BCRSLV/${BCRSLV}-Pfafstetter.TIL  tile.bin
>>>DATAOCEAN<<<endif

/bin/ln -sf $BCSDIR/Shared/pchem.species.CMIP-5.1870-2097.z_91x72.nc4 species.data
/bin/ln -sf $BCSDIR/Shared/*bin .

/bin/ln -sf $BCSDIR/$BCRSLV/visdf_@RES_DATELINE.dat visdf.dat
/bin/ln -sf $BCSDIR/$BCRSLV/nirdf_@RES_DATELINE.dat nirdf.dat
/bin/ln -sf $BCSDIR/$BCRSLV/vegdyn_@RES_DATELINE.dat vegdyn.data
/bin/ln -sf $BCSDIR/$BCRSLV/lai_clim_@RES_DATELINE.data lai.data
/bin/ln -sf $BCSDIR/$BCRSLV/ndvi_clim_@RES_DATELINE.data ndvi.data
/bin/ln -sf $BCSDIR/$BCRSLV/green_clim_@RES_DATELINE.data green.data
/bin/ln -sf $BCSDIR/$BCRSLV/topo_DYN_ave_@RES_DATELINE.data topo_dynave.data
/bin/ln -sf $BCSDIR/$BCRSLV/topo_GWD_var_@RES_DATELINE.data topo_gwdvar.data
/bin/ln -sf $BCSDIR/$BCRSLV/topo_TRB_var_@RES_DATELINE.data topo_trbvar.data

>>>FVCUBED<<<if(     -e  $BCSDIR/$BCRSLV/Gnomonic_$BCRSLV.dat ) then
>>>FVCUBED<<</bin/ln -sf $BCSDIR/$BCRSLV/Gnomonic_$BCRSLV.dat .
>>>FVCUBED<<<endif

>>>COUPLED<<<@CPEXEC -R $GRIDDIR/INPUT .
>>>COUPLED<<<@CPEXEC $HOMDIR/input.nml .
>>>COUPLED<<<@CPEXEC $HOMDIR/*_table .
>>>COUPLED<<</bin/ln -sf $GRIDDIR/cice/kmt_cice.bin .
>>>COUPLED<<</bin/ln -sf $GRIDDIR/cice/grid_cice.bin .

>>>FVCUBED<<<if(! -e input.nml ) then
>>>FVCUBED<<</bin/touch input.nml
>>>FVCUBED<<<endif

_EOF_

chmod +x linkbcs
@CPEXEC  linkbcs $CNVDIR
       ./linkbcs

#######################################################################
#                 Create Binary Tile File from ASCII
#######################################################################

if (! -e tile.bin) then
$RUN_CMD 1 $GEOSBIN/binarytile.x tile.data tile.bin
endif

#######################################################################
#          Get C2L History weights/index file for Cubed-Sphere
#######################################################################

set C_NPX = `echo $AGCM_IM | awk '{printf "%5.5i", $1}'`
set C_NPY = `echo $AGCM_JM | awk '{printf "%5.5i", $1}'`
set H_NPX = `echo @HIST_IM | awk '{printf "%5.5i", $1}'`
set H_NPY = `echo @HIST_JM | awk '{printf "%5.5i", $1}'`

set c2l_file = "${C_NPX}x${C_NPY}_c2l_${H_NPX}x${H_NPY}.bin"

if (-e $BCSDIR/$BCRSLV/${c2l_file}) /bin/ln -s $BCSDIR/$BCRSLV/${c2l_file} .

#######################################################################
#                 Alter CAP.rc to do a zero-length run
#######################################################################

sed -i -e '/JOB_SGMT:/ s/[0-9][0-9]* [0-9][0-9]*/00000000 000000/' \
       -e '/NUM_SGMT:/ s/[0-9][0-9]*/1/' CAP.rc

#######################################################################
#                        Use a blank HISTORY.rc
#######################################################################

set FILE = HISTORY.rc
/bin/rm -f $FILE
cat << _EOF_ > $FILE

EXPID:  Convert
EXPDSC: Convert restarts

COLLECTIONS:
           ::
_EOF_

#######################################################################
#           Use sed to alter AGCM.rc to do the conversion
#######################################################################

sed -r -i -e "/RESTART_TYPE:/ s/binary|pbinary|pnc4/$fromtype/" \
          -e "/CHECKPOINT_TYPE:/ s/binary|pbinary|pnc4/$totype/" \
          -e "/^ *NX:/ s/[0-9][0-9]*/@CNV_NX/" \
          -e "/^ *NY:/ s/[0-9][0-9]*/@CNV_NY/" \
          -e "/AEROCLIM/ d" AGCM.rc

# Remove any suffixes
# -------------------

sed -r -i -e "/CHECKPOINT_FILE:/ s/.nc4|.bin//" \
          -e "/RESTART_FILE:/ s/.nc4|.bin//" AGCM.rc

sed -r -i -e "/CHECKPOINT_FILE:/ s#(.*FILE:)(\s*)(.*)#\1\2\3$toext#" AGCM.rc

if ( $fromext != "_rst" ) then
  sed -r -i -e "/RESTART_FILE:/ s/rst/rst$fromext/" AGCM.rc
endif

sed -r -i -e "/DYCORE: / a DEFAULT_CHECKPOINT_TYPE: $totype" AGCM.rc

# Add pluses to files to allow for extra fields (or change - to +)
# ----------------------------------------------------------------
#if ( $toformat == "NetCDF4" ) then
  #sed -r -i -e '/RESTART_FILE:\s*-/ s#(.*FILE:)(\s*)(-)(.*)#\1\2+\4#' \
            #-e '/RESTART_FILE:\s*[a-z]/ s#(.*FILE:)(\s*)(.*)#\1\2+\3#' AGCM.rc
#endif

#######################################################################
#           Use sed to restore VEGDYN_INTERNAL_RESTART_TYPE
#######################################################################

sed -r -i -e "/VEGDYN_INTERNAL_RESTART_TYPE:/ s/$fromtype/binary/" AGCM.rc

# If a plus is added above, we must remove the one on vegdyn
# ----------------------------------------------------------

#if ( $toformat == "NetCDF4" ) then
  #sed -r -i -e '/VEGDYN_INTERNAL_RESTART_FILE:/ s#\+vegdyn#vegdyn#' AGCM.rc
#endif

#######################################################################
#                    Get Executable and RESTARTS 
#######################################################################

@CPEXEC $EXPDIR/GEOSgcm.x .

set rst_files      = `cat AGCM.rc | grep "RESTART_FILE"    | grep -v VEGDYN | grep -v "#" | cut -d ":" -f1 | cut -d "_" -f1-2`
set rst_file_names = `cat AGCM.rc | grep "RESTART_FILE"    | grep -v VEGDYN | grep -v "#" | cut -d ":" -f2`

set chk_files      = `cat AGCM.rc | grep "CHECKPOINT_FILE" | grep -v "#" | cut -d ":" -f1 | cut -d "_" -f1-2`
set chk_file_names = `cat AGCM.rc | grep "CHECKPOINT_FILE" | grep -v "#" | cut -d ":" -f2`

# Remove possible bootstrap parameters (+/-)
# ------------------------------------------
set dummy = `echo $rst_file_names`
set rst_file_names = ''
foreach rst ( $dummy )
  set length  = `echo $rst | awk '{print length($0)}'`
  set    bit  = `echo $rst | cut -c1`
  if(  "$bit" == "+" | \
       "$bit" == "-" ) set rst = `echo $rst | cut -c2-$length`
  set rst_file_names = `echo $rst_file_names $rst`
end

@ n = 0
set found_rst_files = ''
set found_rst_types = ''
foreach rst ( $rst_file_names )
  @ n = $n + 1
  if(-e $FNDDIR/$rst ) then
    set found_rst_files = `echo $found_rst_files $rst`
    set found_rst_types = `echo $found_rst_types $rst_files[$n]`
  endif
end

#######################################################################
#            Copy and Link Restarts for Conversion Run
#######################################################################

echo "Copying original restarts into $ORGDIR"

foreach rst ( $rst_file_names )
  if(-e $FNDDIR/$rst ) then
    @CPEXEC $FNDDIR/$rst $ORGDIR
    /bin/ln -s $ORGDIR/$rst .
  endif
end

@CPEXEC $FNDDIR/cap_restart $ORGDIR

>>>COUPLED<<<@CPEXEC $CNVDIR/RESTART/* INPUT

#######################################################################
#             Set Experiment Run Parameters that were altered
#######################################################################

set       NX = `grep "^ *NX:" AGCM.rc | cut -d':' -f2`
set       NY = `grep "^ *NY:" AGCM.rc | cut -d':' -f2`

# Check for Over-Specification of CPU Resources
# ---------------------------------------------
  if ($?PBS_NODEFILE) then
     set  NCPUS = `cat $PBS_NODEFILE | wc -l`
     @    NPES  = $NX * $NY
        if( $NPES > $NCPUS ) then
             echo "CPU Resources are Over-Specified"
             echo "--------------------------------"
             echo "Allotted NCPUs: $NCPUS"
             echo "Specified  NX : $NX"
             echo "Specified  NY : $NY"
             exit 6
        endif
     endif
  endif

#######################################################################
#                     Testing Saltwater Restart
#######################################################################

if ( -x $GEOSBIN/rs_numtiles.x ) then

   set N_SALT_TILES_EXPECTED = `grep '^ *0' tile.data | wc -l`
   set N_SALT_TILES_FOUND = `$RUN_CMD 1 $GEOSBIN/rs_numtiles.x saltwater_internal_rst | grep Total | awk '{print $3}'`

   if ( $N_SALT_TILES_EXPECTED != $N_SALT_TILES_FOUND ) then
      echo "Error! Found $N_SALT_TILES_FOUND tiles in saltwater. Expect to find $N_SALT_TILES_EXPECTED tiles."
      echo "Your restarts are probably for a different ocean."
      exit 7
   endif

endif

##################################################################
#                Do the conversion with GEOSgcm.x
##################################################################

       @  NPES = $NX * $NY

echo "Running GEOSgcm.x to do the conversion ..."

set LOGFILE = "$CNVDIR/GEOSgcm.log"
/bin/rm $LOGFILE >& /dev/null

# Assume gcm_setup set these properly for the local platform
/bin/rm -f EGRESS
@SETENVS
$RUN_CMD $NPES ./GEOSgcm.x >& $LOGFILE
if( -e EGRESS ) then
   set rc = 0
else
   set rc = -1
endif

if ( $rc != 0 ) then
   /bin/cat $LOGFILE
   echo " "
   echo "GEOSgcm.x failed and returned with exit code $rc"
   exit $rc
else
   echo "Conversion successful!"
endif
 
#######################################################################
#             Now copy the checkpoints into $RSTDIR
#######################################################################

set numrst = `echo $found_rst_types | wc -w`
set numchk = `echo $chk_files | wc -w`

@ n = 1 
@ z = $numchk + 1 
while ( $n <= $numrst )
   if ( -e $found_rst_files[$n] ) then
       @ m = 1 
       while ( $m <= $numchk )
       if(    $chk_files[$m] == $found_rst_types[$n] || ) then
           /bin/mv $chk_file_names[$m] $RSTDIR/$found_rst_files[$n]$toext
           @ m = $numchk + 999 
       else
           @ m = $m + 1 
       endif
       end 
       wait
       if( $m == $z ) then
           echo "Warning!!  Could not find CHECKPOINT/RESTART match for:  " $chk_files[$n]
           exit
       endif
   endif
@ n = $n + 1 
end

# Copy over cap_restart as well
# -----------------------------
cp cap_restart $RSTDIR/

echo "Converted restarts moved into ${RSTDIR}"

exit 0
