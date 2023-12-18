#!/bin/csh
#
##########################################################################################
#
# This script runs one seasonal forecast 
# It performs the following tasks for a given date, ensemble number and queue:
#    runs setup utility
#    checks for IC to be available
#    places IC to run directory
#    For ensemble members 6-9 it generates perturbations (UNDER CONSTRUCTION)
#
##########################################################################################
# INPUT:
#  icdate	initial date of the forecast (YYYYMMDD)
#  ENSM		ensemble number (1,6:9), reserved for 9-month duration forecast
#  doS2S        choice of queue (0-gmaofcst; 1-s2s preops; 2-gmaodev; 3-high)
#
# PREREQUISITES:
# 1) The environmental variable GEOSS2S is set to:
# /discover/nobackup/projects/gmao/m2oasf/aogcm/g5fcst/forecast/production/geos-s2s
# 2) Directories $GEOSS2S/util and $GEOSS2S/util/submitted are required
# 3) Files required to be in $GEOSS2S/util are:
#    submit_forecastSEASONAL.sh 
#    do_one_forecast.sh
#    monitor_hindcastSEASONAL.sh
#    fvcore_pert.sh 
#    moist_pert.sh
#    perturb_atm.sh
# 
# $GEOSS2S/util is the location of the run to be submitted 
# $GEOSS2S/runh is the home directory of the run (will be generated by setup)
# $GEOSS2S/runx is the work directory of the run (will be generated by setup)
# $ARCHIVE/GEOS_S2S is the archive directory of the run
#########################################################################################


###########################################
#   ENTER THE IC DATE AND ENSEMBLE NUMBER
###########################################

set icdate = $1
set ENSM = $2
set doS2S = $3
set EMISQFEDCL = TRUE

###########################################
#   SET BUILD, RUN AND ARCHIVE LOCATIONS 
###########################################
set BUILD = '/discover/nobackup/projects/gmao/m2oasf/build'
set FCSTSRC = "${BUILD}/geos-s2s/GEOSodas/src"
set FCSTBASE = "$GEOSS2S"

##########################################
#   CHECK RESTARTS AVAILABILITY 
##########################################
set EXPYR = `echo $icdate | cut -c1-4`
set EXPMO = `echo $icdate | cut -c5-6`
set EXPDD = `echo $icdate | cut -c7-8`
if ($EXPMO == '01') set EXPID='jan'$EXPDD
if ($EXPMO == '02') set EXPID='feb'$EXPDD
if ($EXPMO == '03') set EXPID='mar'$EXPDD
if ($EXPMO == '04') set EXPID='apr'$EXPDD
if ($EXPMO == '05') set EXPID='may'$EXPDD
if ($EXPMO == '06') set EXPID='jun'$EXPDD
if ($EXPMO == '07') set EXPID='jul'$EXPDD
if ($EXPMO == '08') set EXPID='aug'$EXPDD
if ($EXPMO == '09') set EXPID='sep'$EXPDD
if ($EXPMO == '10') set EXPID='oct'$EXPDD
if ($EXPMO == '11') set EXPID='nov'$EXPDD
if ($EXPMO == '12') set EXPID='dec'$EXPDD

#Dates of initial conditions at 21z
@ icdatem1 = $icdate - 1
@ iym1 = $EXPYR - 1
if ($EXPID == 'jan01') set icdatem1 = ${iym1}1231
if ($EXPID == 'apr01') set icdatem1 = ${EXPYR}0331
if ($EXPID == 'may01') set icdatem1 = ${EXPYR}0430

set EXPNMO = `echo ${EXPID} | cut -c1-3`
set RST = TRUE
if ( $EXPYR == 2016 ) then 
   set loca = GMAO2016FCST
else
   set loca = GMAOFCST
endif

if ( $loca == GMAO2016FCST ) then
   set RESTARTS = "/discover/nobackup/projects/gmao/m2oasf/aogcm/g5odas/restart/REINIT/${EXPNMO}"
   if ( ! -e $RESTARTS/restarts.e${icdatem1}_21z.tar ) set RST = FALSE
else
   set RESTARTS = '/gpfsm/dnb42/projects/p17/production/geos5/exp/S2S-2_1_ANA_001/hindcast_restarts'
   if ( ! -e $RESTARTS/RESTART/${icdatem1}_2100z.ocean_temp_salt.res.nc ) set RST = FALSE
endif
if ( $RST == FALSE ) then
   echo "RESTARTS $icdatem1 NOT AVAILABLE, EXIT"
   exit
endif

set QUEUENAME = 'gmaofcst'
if ( ${doS2S} == 1 ) set QUEUENAME = 's2s'
if ( ${doS2S} == 2 ) set QUEUENAME = 'gmaodev'
if ( ${doS2S} == 3 ) set QUEUENAME = 'high'

set DOSUBX = TRUE
if ( $ENSM == 1 ) set DOSUBX = FALSE
if ( $ENSM > 5 ) set DOSUBX = FALSE

set ARCHDIRN = `grep 'setenv MASDIR /archive/u' $FCSTSRC/GMAO_Shared/GEOS_Util/post/gcmpost_CPLFCSTfull.script | cut -d'/' -f5`

set ARCHDIR = "/archive/u/$USER}/${ARCHDIRN}/seasonal"
if ( $DOSUBX == TRUE ) set ARCHDIR = "/archive/u/${USER}/${ARCHDIRN}/subseasonal"

set descr = `ls -l ${BUILD}/geos-s2s | cut -d'>' -f2 | cut -d'/' -f1`
echo "ENTERED $icdate for ensemble $ENSM; SUBSEASONAL=$DOSUBX"
echo "RUN QUEUE: $QUEUENAME"
echo "DESCRIPTION: ${BUILD} $descr"
echo "LOCATION IS $loca"

###########################################
#   RUN THE SETUP UTILITY               
###########################################

#source $FCSTSRC/g5_modules
module purge
module load comp/intel-15.0.2.164
module load mpi/impi-5.0.3.048
module load lib/mkl-15.0.2.164
module load other/comp/gcc-4.6.3-sp1
module load other/SIVO-PyD/spd_1.20.0_gcc-4.6.3-sp1_mkl-15.0.0.090
module load other/git-2.3.1
module load other/cdo

set filesetup = 'gcm_CPLFCST360S2Sallsetup'
cd $FCSTBASE/util
if (! -e submitted/ens${ENSM}gcm_setup$icdate) then
   echo " SET UP THE EXPERIMENT FOR $icdate"
   cd $FCSTSRC/Applications/GEOSgcm_App
   /bin/rm -f $FCSTBASE/util/sedfile
cat > $FCSTBASE/util/sedfile << EOF
s/@FCSTIC/$icdate/g
s/@FCSTXX/$descr/g
s/@FCSTMEMBER/$ENSM/g
s/@FCSTSUBX/$DOSUBX/g
s/@FCSTQUEUENAME/$QUEUENAME/g
s/@FCSTARCHIVE/$ARCHDIRN/g
s/@FCSTEMISQFED/$EMISQFEDCL/g
EOF
   sed -f $FCSTBASE/util/sedfile $filesetup > $FCSTBASE/util/gcm_setup$icdate
else
   echo 'SETTING EXIST, EXITING'
   exit
endif
cd $FCSTBASE/util
chmod 750 $FCSTBASE/util/gcm_setup$icdate
$FCSTBASE/util/gcm_setup$icdate

###########################################
#   SET THE cap_restart AND LOCATION
###########################################

set caprestart=${icdatem1}' 210000'
set runhdir="$FCSTBASE/runh/$EXPYR/$EXPID/ens$ENSM"
set runxdir="$FCSTBASE/runx/$EXPYR/$EXPID/ens$ENSM"

echo $caprestart > $runhdir/cap_restartIC
/bin/cp -p  $runhdir/cap_restartIC $runxdir/cap_restart

/bin/mv gcm_setup$icdate submitted/ens${ENSM}gcm_setup$icdate

if ( $loca == GMAO2016FCST ) then
echo "Use vegdyn from MERRA2 - by default forecast setting uses coupled run vegdyn"
cd $runhdir
/bin/mv gcm_run.j tmp_run.j
set CPLVEGDYN = "/discover/nobackup/yvikhlia/coupled/Forcings/a180x1080_o720x410/vegdyn.data"
set MERVEGDYN = "/discover/nobackup/projects/gmao/t2ssp/h54/c180_o05/restart/MERRA2/OutData/vegdyn_internal_rst"
cat tmp_run.j | sed -e "s|${CPLVEGDYN}|${MERVEGDYN}|g" > gcm_run.j
endif


###########################################
#   PLACE THE RESTARTS TO EXP DIRECTORY
###########################################
echo "GET THE INITIAL CONDITIONS (restarts) IN PLACE"
echo "$RESTARTS"
/bin/rm -f ${runhdir}/ICNA
cd $runxdir
/bin/rm -rf RESTART
@ nerr = 0

if ( $loca == GMAOFCST ) then
 echo "GET ${EXPYR} OCEAN RESTARTS FOR ${icdatem1}_21z"
 if ( ! -e tmp ) mkdir tmp
 cd tmp
 cp -p $RESTARTS/*.${icdatem1}_2100z.bin ./
 set fnames = `ls -1 *${icdatem1}_2100z.bin | cut -d "_" -f-2`
 foreach fname ( $fnames )
  /bin/mv ${fname}_checkpoint.${icdatem1}_2100z.bin ${runxdir}/${fname}_rst
 end
 set nfiles = `ls -1 ${runxdir}/*_rst | wc -l`
 if ( $nfiles != 21 ) then
    echo "NUMBER ATM RESTARTS WRONG"
    @ nerr = $nerr + 1
 endif
 cp -p $RESTARTS/RESTART/${icdatem1}_2100z.ocean*.nc ./
 set fnames = `ls -1 ${icdatem1}_2100z.ocean_*.nc | cut -c16-`
 mkdir -p ${runxdir}/RESTART
 foreach fname ( $fnames )
  /bin/mv ${icdatem1}_2100z.${fname} ${runxdir}/RESTART/${fname}
 end
 set nfiles = `ls -1 ${runxdir}/RESTART/*.nc | wc -l`
 if ( $nfiles != 13 ) then
    echo "NUMBER OCN RESTARTS WRONG"
    @ nerr = $nerr + 1
 endif
 if ( $nerr > 0 ) then
    touch ${runhdir}/ICNA
    exit
 endif
 cd ${runxdir}
 /bin/rmdir tmp
 set rss = $status
 if ( $rss > 0 ) exit
endif

if ( $loca == GMAO2016FCST ) then
 if ( -e tmp ) /bin/rm -rf tmp
 mkdir tmp
 cd tmp
 echo "GET 2016 RESTARTS FROM $RESTARTS/restarts.e${icdatem1}_21z.tar"
 tar xvf $RESTARTS/restarts.e${icdatem1}_21z.tar
 cd $runxdir
 /bin/mv tmp/RESTART ./
 /bin/mv tmp/seaice_import_rst ./
 /bin/mv tmp/seaice_internal_rst ./
 /bin/mv tmp/saltwater_import_rst ./
 /bin/mv tmp/saltwater_internal_rst ./
 echo "GET MERRA2 RESTARTS FROM jmarshak m2oasf/restart/OutData/${icdate}/restarts.e${icdatem1}_21z.tar"
 tar xvf /discover/nobackup/projects/gmao/m2oasf/restart/OutData/${icdate}/restarts.e${icdatem1}_21z.tar
 /bin/rm -rf tmp
 set nfiles = `ls -1 ${runxdir}/*_rst | wc -l`
 if ( $nfiles != 18 ) then
    echo "NUMBER ATM RESTARTS WRONG"
    ls -l ${runxdir}/*_rst
    @ nerr = $nerr + 1
 endif
 set mfiles = `ls -1 ${runxdir}/RESTART/*.nc | wc -l`
 if ( $mfiles != 13 ) then
    echo "NUMBER OCN RESTARTS WRONG"
    ls -l ${runxdir}/RESTART
    @ nerr = $nerr + 1
 endif
 if ( $nerr > 0 ) then
    touch ${runhdir}/ICNA
    exit
 endif
endif


if ( ( $DOSUBX == FALSE ) & ( $ENSM > 5 ) )  then
   echo "SEASONAL: GET PERTURBED RESTARTS FOR ENSEMBLE $ENSM"
   echo "ATM grid: fvcore moist "
   echo "MOM grid: ocean_temp_salt ocean_velocity ocean_sbc seaice"
   echo "TILES   : saltwater"
   mkdir -p $FCSTBASE/runx/$EXPYR/$EXPID/OutData/perts
   cd $FCSTBASE/runx/$EXPYR/$EXPID/OutData/perts
   if ( ! -e DONEPERT ) $GEOSS2S/pert/make_pert_rst.sh $icdate $ENSM
   wait
   sleep 5
   if ( ! -e DONEPERT ) then
      echo "PERTURBATION PROBLEM for $icdate $ENSM, EXIT"
      exit
   endif
   if ( $ENSM == 6 ) then
      /bin/rm -f ${runxdir}/RESTART/ocean_sbc.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_temp_salt.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_velocity.res.nc
      /bin/rm -f ${runxdir}/fvcore_internal_rst
      /bin/rm -f ${runxdir}/moist_internal_rst
      /bin/rm -f ${runxdir}/seaice_internal_rst
      /bin/rm -f ${runxdir}/saltwater_internal_rst
      /bin/cp ndata/*nc ${runxdir}/RESTART
      /bin/cp ndata/*_rst ${runxdir}
   endif
   if ( $ENSM == 7 ) then
      /bin/rm -f ${runxdir}/RESTART/ocean_sbc.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_temp_salt.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_velocity.res.nc
      /bin/rm -f ${runxdir}/fvcore_internal_rst
      /bin/rm -f ${runxdir}/moist_internal_rst
      /bin/rm -f ${runxdir}/seaice_internal_rst
      /bin/rm -f ${runxdir}/saltwater_internal_rst
      /bin/cp pdata/*nc ${runxdir}/RESTART
      /bin/cp pdata/*_rst ${runxdir}
   endif
   if ( $ENSM == 8 ) then
      /bin/rm -f ${runxdir}/RESTART/ocean_sbc.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_temp_salt.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_velocity.res.nc
      /bin/cp ndata/*nc ${runxdir}/RESTART
   endif
   if ( $ENSM == 9 ) then
      /bin/rm -f ${runxdir}/fvcore_internal_rst
      /bin/rm -f ${runxdir}/moist_internal_rst
      /bin/rm -f ${runxdir}/seaice_internal_rst
      /bin/rm -f ${runxdir}/saltwater_internal_rst
      /bin/cp pdata/*_rst ${runxdir}
   endif
   if ( $ENSM == 10 ) then
      /bin/rm -f ${runxdir}/RESTART/ocean_sbc.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_temp_salt.res.nc
      /bin/rm -f ${runxdir}/RESTART/ocean_velocity.res.nc
      /bin/cp pdata/*nc ${runxdir}/RESTART
   endif
   if ( $ENSM == 11 ) then
      /bin/rm -f ${runxdir}/fvcore_internal_rst
      /bin/rm -f ${runxdir}/moist_internal_rst
      /bin/rm -f ${runxdir}/seaice_internal_rst
      /bin/rm -f ${runxdir}/saltwater_internal_rst
      /bin/cp ndata/*_rst ${runxdir}
   endif
      
   cd ${runxdir}
   set arst = `ls -1 *_rst | wc -l`
   set orst = `ls -1 RESTART/*.nc  | wc -l`
   if ( ($arst == 21) & ( $orst == 13) ) then
    /bin/rm -f $runhdir/NO_PERT
   else
    echo "PERTURBATION NOT GENERATED FOR $cdate ${ENSM}"
    touch $runhdir/NO_PERT
   endif
endif

wait

###########################################
#   SUBMIT THE RUN
###########################################
cd $runhdir
if ( ! -e $runhdir/NO_PERT) then
   echo qsub gcm_run.j
   qsub gcm_run.j
endif

echo 'DONE'
exit
