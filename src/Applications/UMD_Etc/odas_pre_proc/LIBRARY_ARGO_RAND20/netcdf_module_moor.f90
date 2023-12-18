MODULE NETCDF_MODULE_MOOR
  
  IMPLICIT NONE
  PUBLIC :: write_netcdf, append_netcdf, read_netcdf_init, read_netcdf_init_date, read_netcdf, write_obserr, read_netcdf_date, write_grid

  CONTAINS 
  ! .................................................................
    SUBROUTINE write_obserr(fname_out,maxnobs,nobs,nlevs,inst_error,&
               var_id,miss,date_time,lon,lat,npts,qc_flag,data_id,inst_id, &
               qc_prf,depth,field,qc_lev,obs_error,    &
               title,source,svar,history_obserr)
  ! .................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'
 
    character*256, intent(in) :: fname_out
    integer,       intent(in) :: maxnobs, nobs, nlevs, var_id
    real,          intent(in) :: miss, inst_error
    character*64,  intent(in) :: title, source, history_obserr
    character*4,   intent(in) :: svar

    integer,       intent(in) :: date_time(nobs), inst_id(nobs), npts(nobs)
    integer,       intent(in) :: qc_flag(nobs)
    real,          intent(in) :: qc_prf(nobs)
    real,          intent(in) :: lon(nobs), lat(nobs)
    
    real,          intent(in) :: depth(nlevs,nobs)
    ! Read Daily Data File 
      !integer, parameter   :: im = 1440, jm = 720,  maxnobs = im*jm
      !real,    parameter   :: res = 0.25

    real,          intent(in) :: field(nlevs,nobs)
    real,          intent(in) :: qc_lev(nlevs,nobs)
    real,          intent(in) :: obs_error(nlevs,nobs)    
    integer,       intent(in) :: data_id(nobs)

    integer        :: i, j
    real           :: t(nobs,nlevs)

    integer           :: ncid, status
    integer           :: N_PROFdim,   N_PROFid
    integer           :: N_LEVSdim,   N_LEVSid
    integer           :: SCALARdim,   SCALARid
    integer           :: DATA_IDdim(2), DATA_IDid

    integer           :: VAR_IDid   
    integer           :: DATE_TIMEid, INST_IDid, NPTSid
    integer           :: QC_FLAGid
    integer           :: QC_PRFid, INST_ERRORid, MISSid
    integer           :: LONid, LATid 
    integer           :: startN_PROF, countN_PROF
    integer           :: startVAR(2), countVAR(2), VARdim(2)

    integer           :: DEPTHid, FIELDid, QC_LEVid, OBS_ERRORid
    
    real(kind=8)      :: N_PROF(nobs)

    character*64      :: history, conventions, version
    character*64      :: field_conventions,field_longname, field_units
    character*8       :: current_date


   ! *****************************************************************!
     if (svar(1:3)=='SLA') then
        field_conventions = 'Ocean Satellite Observed Sea Surface Height'
        field_longname    = 'Altimeter Sea Surface Height Anomaly'
        field_units       = 'm'
     elseif (svar(1:3)=='TEM') then
        field_conventions = 'Ocean In Situ Observed Temperature Profile'
        field_longname    = 'Profile Potential Temperature'
        field_units       = 'degC'
     elseif (svar(1:3)=='SAL') then
        field_conventions = 'Ocean In Situ Observed Salinity Profile'
        field_longname    = 'Profile Salinity'
        field_units       = 'psu'
     elseif (svar(1:3)=='SSS') then
        field_conventions = 'Ocean Derived Surface Salinity'
        field_longname    = 'Sea Surface Salinity'
        field_units       = 'psu'
     elseif (svar(1:3)=='SST') then
        field_conventions = 'Ocean Derived Sea Surface Temperature'
        field_longname    = 'Sea Surface Temperature'
        field_units       = 'C'
     elseif (svar(1:3)=='ICE') then
        field_conventions = 'Ocean Derived Ice Concentration'
        field_longname    = 'Ice Concentration'
        field_units       = ''
     endif

    call DATE_AND_TIME(current_date)

    history     = 'Created on ' // current_date // ' by Robin Kovach'   
    conventions = 'COARDS'
    version     = 'netcdf-3.5.1'

    startN_PROF =  1
    countN_PROF = nobs

    startVAR = (/ 1,1 /)
    countVAR = (/ nlevs,nobs /)
    
    DO i = 1, nobs
       N_PROF(i)       = i
    ENDDO

   ! Create netcdf file and ncid
     status = nf_create(trim(fname_out), nf_write, ncid)
   
   ! Define Dimensions
     status = nf_def_dim(ncid,'N_PROF', nf_unlimited, N_PROFdim)
     status = nf_def_dim(ncid,'N_LEVS', nlevs,        N_LEVSdim)
     status = nf_def_dim(ncid,'SCALAR', 1,            SCALARdim)

   ! Define Variables
   ! ................
   ! Scalars
   ! .....................................................................................
     status = nf_def_var(ncid, 'VAR_ID',       nf_int,   1, SCALARdim,  VAR_IDid)
     status = nf_def_var(ncid, 'INST_ERROR',   nf_real,  1, SCALARdim,  INST_ERRORid)
     status = nf_def_var(ncid, 'MISSING',      nf_real,  1, SCALARdim,  MISSid)

   ! 1D Vectors
   ! .................................................................................

     status = nf_def_var(ncid, 'DATA_ID',      nf_int,     1, N_PROFdim,   DATA_IDid)
     status = nf_def_var(ncid, 'N_PROF',       nf_double,  1, N_PROFdim,   N_PROFid)
     status = nf_def_var(ncid, 'DATE_TIME',    nf_int,     1, N_PROFdim,   DATE_TIMEid)
     status = nf_def_var(ncid, 'LON',          nf_real,    1, N_PROFdim,   LONid)
     status = nf_def_var(ncid, 'LAT',          nf_real,    1, N_PROFdim,   LATid)
     status = nf_def_var(ncid, 'NPTS',         nf_int,     1, N_PROFdim,   NPTSid)
     status = nf_def_var(ncid, 'QC_FLAG',      nf_int,     1, N_PROFdim,   QC_FLAGid)
     status = nf_def_var(ncid, 'INST_ID',      nf_int,     1, N_PROFdim,   INST_IDid)
     status = nf_def_var(ncid, 'QC_PRF',       nf_real,    1, N_PROFdim,   QC_PRFid)
 
   ! 2D Vectors
   ! .................................................................
     VARdim(1) = N_LEVSdim
     VARdim(2) = N_PROFdim     
     if (svar(1:3)=='SLA') then
        status = nf_def_var(ncid,'SLA',     nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='TEM') then
        status = nf_def_var(ncid,'TEMP',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='SAL') then
        status = nf_def_var(ncid,'SALT',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='SSS') then
        status = nf_def_var(ncid,'SALT',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='SST') then
        status = nf_def_var(ncid,'TEMP',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='ICE') then
        status = nf_def_var(ncid,'ICE',    nf_real, 2, VARdim, FIELDid)
     endif
     status = nf_def_var(ncid,'OBS_ERROR', nf_real, 2, VARdim, OBS_ERRORid)
     status = nf_def_var(ncid,'DEPTH',     nf_real, 2, VARdim, DEPTHid)
     status = nf_def_var(ncid,'QC_LEV',    nf_real, 2, VARdim, QC_LEVid)
 
   ! ATTRIBUTES
   ! ....................................................................................................
     status = nf_put_att_text(ncid, nf_global, 'title',        len_trim(title), title)
     status = nf_put_att_text(ncid, nf_global, 'source',       len_trim(source), source)    
     status = nf_put_att_text(ncid, nf_global, 'history',      len_trim(history), history)
    ! Read Daily Data File 
      !integer, parameter   :: im = 1440, jm = 720,  maxnobs = im*jm
      !real,    parameter   :: res = 0.25

     status = nf_put_att_text(ncid, nf_global, 'history_obserr',len_trim(history_obserr), history_obserr)
     status = nf_put_att_text(ncid, nf_global, 'Conventions',  len_trim(conventions), conventions)
     status = nf_put_att_text(ncid, nf_global, 'Version',      len_trim(version),  version)
 
     status = nf_put_att_text(ncid, VAR_IDid, 'long_name',   28, 'Variable Identification Code')
     status = nf_put_att_text(ncid, VAR_IDid, 'conventions', len_trim(field_conventions), &
                 field_conventions)

     status = nf_put_att_text(ncid, INST_ERRORid, 'long_name',   16, 'Instrument Error')
     
     status = nf_put_att_text(ncid, MISSid,       'long_name',   18, 'Missing Data Value')

     status = nf_put_att_text(ncid, DATA_IDid,    'long_name',   22, 'Unique Data Identifier')

     status = nf_put_att_text(ncid, DATE_TIMEid,  'long_name',   23, 'Date of the Observation')
     status = nf_put_att_text(ncid, DATE_TIMEid,  'conventions', 10, 'yyyymmddhh')

     status = nf_put_att_text(ncid, LONid,        'long_name',    9, 'Longitude')
     status = nf_put_att_text(ncid, LONid,        'units',       12, 'degrees_east')

     status = nf_put_att_text(ncid, LATid,        'long_name',    8, 'Latitude')
     status = nf_put_att_text(ncid, LATid,        'units',       13, 'degrees_north')

     status = nf_put_att_text(ncid, NPTSid,       'long_name',   32, 'Number of Data Levels in Profile')

     status = nf_put_att_text(ncid, QC_FLAGid,    'long_name',   15, 'QC Profile Flag')
     status = nf_put_att_text(ncid, QC_FLAGid,    'conventions',  9, 'No QC : 0')

     status = nf_put_att_text(ncid, INST_IDid,    'long_name',  30, 'Instrument Identification Code')

     status = nf_put_att_text(ncid, QC_PRFid,     'long_name',   28, 'Profile Quality Control Flag')
     status = nf_put_att_text(ncid, QC_PRFid,     'conventions', 20, 'standard quality : 1')

     status = nf_put_att_text(ncid, QC_LEVid,     'long_name',   26, 'Level Quality Control Flag')
     status = nf_put_att_text(ncid, QC_LEVid,     'conventions', 20, 'standard quality : 1')

     status = nf_put_att_text(ncid, FIELDid,      'long_name',     len_trim(field_longname), field_longname)
     status = nf_put_att_text(ncid, FIELDid,      'units',         len_trim(field_units), field_units)
     status = nf_put_att_real(ncid, FIELDid,      'missing_value', nf_real, 1, 9.99e11)
     status = nf_put_att_real(ncid, FIELDid,      '_FillValue',    nf_real, 1, 9.99e11)
 
     status = nf_put_att_text(ncid, OBS_ERRORid,  'long_name',     17, 'Observation Error')
     status = nf_put_att_text(ncid, OBS_ERRORid,  'units',         len_trim(field_units), field_units)
     status = nf_put_att_real(ncid, OBS_ERRORid,  'missing_value', nf_real, 1, 9.99e11)
     status = nf_put_att_real(ncid, OBS_ERRORid,  '_FillValue',    nf_real, 1, 9.99e11)

     status = nf_put_att_text(ncid, DEPTHid,      'long_name',     13, 'Profile Depth')
     status = nf_put_att_text(ncid, DEPTHid,      'units',         6, 'meters')
     status = nf_put_att_real(ncid, DEPTHid,      'missing_value', nf_real, 1, 9.99e11)
     status = nf_put_att_real(ncid, DEPTHid,      '_FillValue',    nf_real, 1, 9.99e11)

   ! Leave Define Mode
     status = nf_enddef(ncid)

   ! Write Variables
   ! ..........................................................................................
     status = nf_put_vara_double (ncid, N_PROFid,       startN_PROF, countN_PROF, N_PROF)
     status = nf_put_var_int     (ncid, VAR_IDid,                                 var_id)
     status = nf_put_var_real    (ncid, INST_ERRORid,                             inst_error)
     status = nf_put_var_real    (ncid, MISSid,                                   miss)
    
     status = nf_put_vara_text   (ncid, DATA_IDid,      startN_PROF, countN_PROF, data_id)
     status = nf_put_vara_int    (ncid, DATE_TIMEid,    startN_PROF, countN_PROF, date_time)
     status = nf_put_vara_real   (ncid, LONid,          startN_PROF, countN_PROF, lon)
     status = nf_put_vara_real   (ncid, LATid,          startN_PROF, countN_PROF, lat)
     status = nf_put_vara_int    (ncid, NPTSid,         startN_PROF, countN_PROF, npts)
     status = nf_put_vara_int    (ncid, QC_FLAGid,      startN_PROF, countN_PROF, QC_FLAG)
     status = nf_put_vara_int    (ncid, INST_IDid,      startN_PROF, countN_PROF, inst_id)
     status = nf_put_vara_real   (ncid, QC_PRFid,       startN_PROF, countN_PROF, qc_prf)
     status = nf_put_vara_real   (ncid, FIELDid,        startVAR,    countVAR,    field)
     status = nf_put_vara_real   (ncid, DEPTHid,        startVAR,    countVAR,    depth)
     status = nf_put_vara_real   (ncid, QC_LEVid,       startVAR,    countVAR,    qc_lev)
     status = nf_put_vara_real   (ncid, OBS_ERRORid,    startVAR,    countVAR,    obs_error)
     
   ! Close Dataset
     status = nf_close(ncid)

  return
  END SUBROUTINE write_obserr

  ! .................................................................
    SUBROUTINE write_netcdf(fname_out,maxnobs,nobs,nlevs,inst_error,&
               var_id,miss,date_time,lon,lat,npts,qc_flag,data_id,inst_id, &
               qc_prf,depth,field,qc_lev,obs_error,title,source,svar)
  ! .................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'
 
    character*256, intent(in) :: fname_out
    integer,       intent(in) :: maxnobs, nobs, nlevs, var_id
    real,          intent(in) :: miss, inst_error
    character*64,  intent(in) :: title, source
    character*4,   intent(in) :: svar

    integer,       intent(in) :: date_time(nobs), inst_id(nobs), npts(nobs)
    integer,       intent(in) :: qc_flag(nobs)
    real,          intent(in) :: qc_prf(nobs)
    real,          intent(in) :: lon(nobs), lat(nobs)
    
    real,          intent(in) :: depth(nlevs,nobs)
    real,          intent(in) :: field(nlevs,nobs)
    real,          intent(in) :: qc_lev(nlevs,nobs)
    real,          intent(in) :: obs_error(nlevs,nobs)    
    integer,       intent(in) :: data_id(nobs)

    integer        :: i, j
    real           :: t(nobs,nlevs)


    integer           :: ncid, status
    integer           :: N_PROFdim,   N_PROFid
    integer           :: N_LEVSdim,   N_LEVSid
    integer           :: SCALARdim,   SCALARid
    integer           :: DATA_IDdim(2), DATA_IDid

    integer           :: VAR_IDid   
    integer           :: DATE_TIMEid, INST_IDid, NPTSid
    integer           :: QC_FLAGid
    integer           :: QC_PRFid, INST_ERRORid, MISSid
    integer           :: LONid, LATid 
    integer           :: startN_PROF, countN_PROF
    integer           :: startVAR(2), countVAR(2), VARdim(2)

    integer           :: DEPTHid, FIELDid, QC_LEVid, OBS_ERRORid
    
    real(kind=8)      :: N_PROF(nobs)

    character*64      :: history, conventions, version
    character*64      :: field_conventions,field_longname, field_units
    character*8       :: current_date

   ! *****************************************************************!
     if (svar(1:3)=='SLA') then
        field_conventions = 'Ocean Satellite Observed Sea Surface Height'
        field_longname    = 'Altimeter Sea Surface Height Anomaly'
        field_units       = 'm'
     elseif (svar(1:3)=='TEM') then
        field_conventions = 'Ocean Observed Temperature Profile'
        field_longname    = 'Profile Potential Temperature'
        field_units       = 'degC'
     elseif (svar(1:3)=='SAL') then
        field_conventions = 'Ocean Observed Salinity Profile'
        field_longname    = 'Profile Salinity'
        field_units       = 'psu'
     elseif (svar(1:3)=='SSS') then
        field_conventions = 'Ocean Derived Surface Salinity'
        field_longname    = 'Sea Surface Salinity'
        field_units       = 'psu'
     elseif (svar(1:3)=='SST') then
        field_conventions = 'Ocean Derived Sea Surface Temperature'
        field_longname    = 'Sea Surface Temperature'
        field_units       = 'C'
     elseif (svar(1:3)=='ICE') then
        field_conventions = 'Ocean Derived Ice Concentration'
        field_longname    = 'Ice Concentration'
        field_units       = ''
     endif

    call DATE_AND_TIME(current_date)

    history     = 'Created on ' // current_date // ' by Robin Kovach'
    conventions = 'COARDS'
    version     = 'netcdf-3.5.1'

    startN_PROF =  1
    countN_PROF = nobs

    startVAR = (/ 1,1 /)
    countVAR = (/ nlevs,nobs /)
    
    DO i = 1, nobs
       N_PROF(i)       = i
    ENDDO

    !print *, shape(field), shape(obs_error)

   ! Create netcdf file and ncid
     status = nf_create(trim(fname_out), nf_write, ncid)
     !print *, 'create ', status
   
   ! Define Dimensions
     status = nf_def_dim(ncid,'N_PROF', nf_unlimited, N_PROFdim)
     status = nf_def_dim(ncid,'N_LEVS', nlevs,        N_LEVSdim)
     status = nf_def_dim(ncid,'SCALAR', 1,            SCALARdim)

   ! Define Variables
     !print *, 'define variables'   
   ! ................
   ! Scalars
   ! .....................................................................................
     status = nf_def_var(ncid, 'VAR_ID', nf_int,   1, SCALARdim,  VAR_IDid)
     status = nf_def_var(ncid, 'INST_ERROR',   nf_real,  1, SCALARdim,  INST_ERRORid)
     status = nf_def_var(ncid, 'MISSING',      nf_real,  1, SCALARdim,  MISSid)

   ! 1D Vectors
   ! .................................................................................
     status = nf_def_var(ncid, 'N_PROF',       nf_double,  1, N_PROFdim,   N_PROFid)
     status = nf_def_var(ncid, 'DATA_ID',      nf_int,     1, N_PROFdim,   DATA_IDid)
     status = nf_def_var(ncid, 'DATE_TIME',    nf_int,     1, N_PROFdim,   DATE_TIMEid)
     status = nf_def_var(ncid, 'LON',          nf_real,    1, N_PROFdim,   LONid)
     status = nf_def_var(ncid, 'LAT',          nf_real,    1, N_PROFdim,   LATid)
     status = nf_def_var(ncid, 'NPTS',         nf_int,     1, N_PROFdim,   NPTSid)
     status = nf_def_var(ncid, 'QC_FLAG',      nf_int,     1, N_PROFdim,   QC_FLAGid)
     status = nf_def_var(ncid, 'INST_ID',      nf_int,     1, N_PROFdim,   INST_IDid)
     status = nf_def_var(ncid, 'QC_PRF',       nf_real,    1, N_PROFdim,   QC_PRFid)
 
   ! 2D Vectors
   ! .................................................................
     VARdim(1) = N_LEVSdim
     VARdim(2) = N_PROFdim     
     if (svar(1:3)=='SLA') then
        status = nf_def_var(ncid,'SLA',     nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='TEM') then
        status = nf_def_var(ncid,'TEMP',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='SAL') then
        status = nf_def_var(ncid,'SALT',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='SSS') then
        status = nf_def_var(ncid,'SALT',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='SST') then
        status = nf_def_var(ncid,'TEMP',    nf_real, 2, VARdim, FIELDid)
     elseif (svar(1:3)=='ICE') then
        status = nf_def_var(ncid,'ICE',    nf_real, 2, VARdim, FIELDid)
     endif
     status = nf_def_var(ncid,'OBS_ERROR',  nf_real, 2, VARdim, OBS_ERRORid)
     !print *, 'obserr id ', status
     status = nf_def_var(ncid,'DEPTH',      nf_real, 2, VARdim, DEPTHid)
     status = nf_def_var(ncid,'QC_LEV',     nf_real, 2, VARdim, QC_LEVid)

 
   ! ATTRIBUTES
   ! ....................................................................................................
     !print *, 'write attributes'
     status = nf_put_att_text(ncid, nf_global, 'title',        len_trim(title), title)
     status = nf_put_att_text(ncid, nf_global, 'source',       len_trim(source), source)    
     status = nf_put_att_text(ncid, nf_global, 'history',      len_trim(history), history)
     status = nf_put_att_text(ncid, nf_global, 'Conventions',  len_trim(conventions), conventions)
     status = nf_put_att_text(ncid, nf_global, 'Version',      len_trim(version),  version)
 
     status = nf_put_att_text(ncid, VAR_IDid, 'long_name',   28, 'Variable Identification Code')
     status = nf_put_att_text(ncid, VAR_IDid, 'conventions', len_trim(field_conventions), &
                 field_conventions)

     status = nf_put_att_text(ncid, INST_ERRORid, 'long_name',   16, 'Instrument Error')
     
     status = nf_put_att_text(ncid, MISSid,       'long_name',   18, 'Missing Data Value')

     status = nf_put_att_text(ncid, DATA_IDid,    'long_name',   22, 'Unique Data Identifier')

     status = nf_put_att_text(ncid, DATE_TIMEid,  'long_name',   23, 'Date of the Observation')
     status = nf_put_att_text(ncid, DATE_TIMEid,  'conventions', 10, 'yyyymmddhh')

     status = nf_put_att_text(ncid, LONid,        'long_name',    9, 'Longitude')
     status = nf_put_att_text(ncid, LONid,        'units',       12, 'degrees_east')

     status = nf_put_att_text(ncid, LATid,        'long_name',    8, 'Latitude')
     status = nf_put_att_text(ncid, LATid,        'units',       13, 'degrees_north')

     status = nf_put_att_text(ncid, NPTSid,       'long_name',   32, 'Number of Data Levels in Profile')

     status = nf_put_att_text(ncid, QC_FLAGid,    'long_name',   15, 'QC Profile Flag')
     status = nf_put_att_text(ncid, QC_FLAGid,    'conventions',  9, 'No QC : 0')

     status = nf_put_att_text(ncid, INST_IDid,    'long_name',  30, 'Instrument Identification Code')

     status = nf_put_att_text(ncid, QC_PRFid,     'long_name',   28, 'Profile Quality Control Flag')
     status = nf_put_att_text(ncid, QC_PRFid,     'conventions', 20, 'standard quality : 1')

     status = nf_put_att_text(ncid, QC_LEVid,     'long_name',   26, 'Level Quality Control Flag')
     status = nf_put_att_text(ncid, QC_LEVid,     'conventions', 20, 'standard quality : 1')

     status = nf_put_att_text(ncid, FIELDid,      'long_name',     len_trim(field_longname), field_longname)
     status = nf_put_att_text(ncid, FIELDid,      'units',         len_trim(field_units), field_units)
     status = nf_put_att_real(ncid, FIELDid,      'missing_value', nf_real, 1, 9.99e11)
     status = nf_put_att_real(ncid, FIELDid,      '_FillValue',    nf_real, 1, 9.99e11)
 
     status = nf_put_att_text(ncid, OBS_ERRORid,  'long_name',     17, 'Observation Error')
     status = nf_put_att_text(ncid, OBS_ERRORid,  'units',         len_trim(field_units), field_units)
     status = nf_put_att_real(ncid, OBS_ERRORid,  'missing_value', nf_real, 1, 9.99e11)
     status = nf_put_att_real(ncid, OBS_ERRORid,  '_FillValue',    nf_real, 1, 9.99e11)

     status = nf_put_att_text(ncid, DEPTHid,      'long_name',     13, 'Profile Depth')
     status = nf_put_att_text(ncid, DEPTHid,      'units',         6, 'meters')
     status = nf_put_att_real(ncid, DEPTHid,      'missing_value', nf_real, 1, 9.99e11)
     status = nf_put_att_real(ncid, DEPTHid,      '_FillValue',    nf_real, 1, 9.99e11)

   ! Leave Define Mode
     status = nf_enddef(ncid)

   ! Write Variables
   ! ..........................................................................................
     !print *, 'write variables'

     status = nf_put_vara_double (ncid, N_PROFid,       startN_PROF, countN_PROF, N_PROF)
     status = nf_put_var_int     (ncid, VAR_IDid,                                 var_id)
     status = nf_put_var_real    (ncid, INST_ERRORid,                             inst_error)
     status = nf_put_var_real    (ncid, MISSid,                                   miss) 
     status = nf_put_vara_int    (ncid, DATA_IDid,      startN_PROF, countN_PROF, data_id) 
     status = nf_put_vara_int    (ncid, DATE_TIMEid,    startN_PROF, countN_PROF, date_time)

     status = nf_put_vara_real   (ncid, LONid,          startN_PROF, countN_PROF, lon)
     status = nf_put_vara_real   (ncid, LATid,          startN_PROF, countN_PROF, lat) 
     status = nf_put_vara_int    (ncid, NPTSid,         startN_PROF, countN_PROF, npts)
 
     status = nf_put_vara_int    (ncid, QC_FLAGid,      startN_PROF, countN_PROF, qc_flag)
     status = nf_put_vara_int    (ncid, INST_IDid,      startN_PROF, countN_PROF, inst_id)

     status = nf_put_vara_real   (ncid, QC_PRFid,       startN_PROF, countN_PROF, qc_prf)
     !print *, 'qc_prf ', status
     status = nf_put_vara_real   (ncid, FIELDid,        startVAR,    countVAR,    field)
     !print *, 'field ', status
     status = nf_put_vara_real   (ncid, DEPTHid,        startVAR,    countVAR,    depth)
     !print *, 'depth ', status
     status = nf_put_vara_real   (ncid, QC_LEVid,       startVAR,    countVAR,    qc_lev)
     !print *, 'qclev ', status
     !print *, minval(obs_error), maxval(obs_error,mask=obs_error/=miss)
     status = nf_put_vara_real   (ncid, OBS_ERRORid,    startVAR,    countVAR,    obs_error)
     !print *, 'obserr ', status
 
   ! Close Dataset
     status = nf_close(ncid)

  return
  END SUBROUTINE write_netcdf


  ! .................................................................
    SUBROUTINE append_netcdf(fname_out,maxnobs,nobs,nlevs,inst_error,  &
               var_id,miss,date_time,lon,lat,npts,qc_flag,data_id,inst_id, &
               qc_prf,depth,field,qc_lev,obs_error,svar)
  ! .................................................................
    IMPLICIT NONE
    !INCLUDE '/opt/netcdf-3.5.1/include/netcdf.inc'
    INCLUDE 'netcdf.inc'

    character*256, intent(in) :: fname_out
    integer,       intent(in) :: maxnobs, nobs, nlevs, var_id
    real,          intent(in) :: miss, inst_error
    character*4,   intent(in) :: svar

    integer,       intent(in) :: date_time(nobs), inst_id(nobs), npts(nobs)
    integer,       intent(in) :: qc_flag(nobs)    	
    real,          intent(in) :: qc_prf(nobs)
    real,          intent(in) :: lon(nobs), lat(nobs)
    
    real,          intent(in) :: depth(nlevs,nobs)
    real,          intent(in) :: field(nlevs,nobs)
    real,          intent(in) :: qc_lev(nlevs,nobs)  
    real,          intent(in) :: obs_error(nlevs,nobs)     
    integer,       intent(in) :: data_id(nobs)    

    integer        :: i, j
    real           :: t(nobs,nlevs)

    integer           :: ncid, status
    integer           :: N_PROFdim,   N_PROFid, N_PROFlen
    integer           :: N_LEVSdim,   N_LEVSid
    integer           :: SCALARdim,   SCALARid
    integer           :: DATA_IDdim(2), DATA_IDid

    integer           :: VAR_IDid, INST_ERRORid, MISSid
    integer           :: DATE_TIMEid, INST_IDid, NPTSid
    integer           :: QC_FLAGid
    integer           :: QC_PRFid
    integer           :: LONid, LATid 
    integer           :: startN_PROF, countN_PROF
    integer           :: startVAR(2), countVAR(2), VARdim(2)
    integer           :: ndims, nvars, ngatts, unlimdimid

    integer           :: DEPTHid, FIELDid, QC_LEVid, OBS_ERRORid
    real(kind=8)      :: N_PROF(nobs)

    character*64      :: title, source, history, conventions, version
    character*64      :: field_conventions,field_longname, field_units
    character*8       :: current_date


   ! *****************************************************************!

    call DATE_AND_TIME(current_date)
    history     = 'Updated on ' // current_date // ' by Robin Kovach'

   ! Open netcdf file and ncid
     status = nf_open(trim(fname_out), nf_write, ncid)

     status = nf_inq(ncid, ndims, nvars, ngatts, unlimdimid)

     status = nf_inq_dimid(ncid,'N_PROF',N_PROFdim)
     status = nf_inq_dimlen(ncid,N_PROFdim,N_PROFlen)

     !N_PROF      = N_PROFlen + 1.
     startN_PROF = N_PROFlen + 1.
     countN_PROF = nobs

     startVAR = (/ 1,startN_PROF /)
     countVAR = (/ nlevs,nobs /)

     DO i = 1, nobs
        N_PROF(i)       = i + N_PROFlen
        if ( N_PROF(i) > 1e20) then
	   print *, 'error', i,  N_PROF(i)
           stop
        endif
     ENDDO
     !print *, nobs, N_PROFlen, minval(N_PROF), maxval(N_PROF), minval(date_time)


   ! Get Variable Id's, Dimensions Id's from Names
   ! ..............................................
     status = nf_inq_varid(ncid, 'N_PROF',       N_PROFid)
     status = nf_inq_varid(ncid, 'DATA_ID',      DATA_IDid)
     status = nf_inq_varid(ncid, 'DATE_TIME',    DATE_TIMEid)
     status = nf_inq_varid(ncid, 'LON',          LONid)
     status = nf_inq_varid(ncid, 'LAT',          LATid)
     status = nf_inq_varid(ncid, 'NPTS',         NPTSid)
     status = nf_inq_varid(ncid, 'QC_FLAG',      QC_FLAGid)
     status = nf_inq_varid(ncid, 'INST_ID',      INST_IDid)
     status = nf_inq_varid(ncid, 'QC_PRF',       QC_PRFid)     
     if (svar(1:3)=='TEM') then
        status = nf_inq_varid(ncid, 'TEMP',      FIELDid)
     elseif (svar(1:3)=='SAL') then
        status = nf_inq_varid(ncid, 'SALT',      FIELDid)
     elseif (svar(1:3)=='SSS')  then
        status = nf_inq_varid(ncid, 'SALT',       FIELDid)
     elseif (svar(1:3)=='SST')  then
        status = nf_inq_varid(ncid, 'TEMP',       FIELDid)
     elseif (svar(1:3)=='ICE')  then
        status = nf_inq_varid(ncid, 'ICE',       FIELDid)
     endif
 
     status = nf_inq_varid(ncid, 'OBS_ERROR',    OBS_ERRORid)
     status = nf_inq_varid(ncid, 'DEPTH',        DEPTHid)
     status = nf_inq_varid(ncid, 'QC_LEV',       QC_LEVid)

     status = nf_put_att_text(ncid, nf_global, 'history', len_trim(history), history)

     !print *, minval(date_time), maxval(date_time), startN_PROF, countN_PROF

   ! Write Variables
   ! ..........................................................................................
     status = nf_put_vara_double (ncid, N_PROFid,       startN_PROF, countN_PROF, N_PROF)
     !print *, 'nprof  ',status, minval(N_PROF)
     status = nf_put_vara_int    (ncid, DATA_IDid,      startN_PROF, countN_PROF, data_id)
     !print *, 'dataid ',status, minval(data_id)
     status = nf_put_vara_int    (ncid, DATE_TIMEid,    startN_PROF, countN_PROF, date_time)
     !print *, 'date   ',status, minval(date_time)
     status = nf_put_vara_real   (ncid, LONid,          startN_PROF, countN_PROF, lon)
     status = nf_put_vara_real   (ncid, LATid,          startN_PROF, countN_PROF, lat)
     status = nf_put_vara_int    (ncid, NPTSid,         startN_PROF, countN_PROF, npts)
     status = nf_put_vara_int    (ncid, QC_FLAGid,      startN_PROF, countN_PROF, QC_FLAG)
     status = nf_put_vara_int    (ncid, INST_IDid,      startN_PROF, countN_PROF, inst_id)
     status = nf_put_vara_real   (ncid, QC_PRFid,       startN_PROF, countN_PROF, qc_prf)
     status = nf_put_vara_real   (ncid, FIELDid,        startVAR,    countVAR,    field)
     status = nf_put_vara_real   (ncid, DEPTHid,        startVAR,    countVAR,    depth)
     status = nf_put_vara_real   (ncid, QC_LEVid,       startVAR,    countVAR,    qc_lev)
     status = nf_put_vara_real   (ncid, OBS_ERRORid,    startVAR,    countVAR,    obs_error)
     
   ! Close Dataset
     status = nf_close(ncid)

  return
  END SUBROUTINE append_netcdf


  ! .................................................................
    SUBROUTINE read_netcdf_init(fname,N_PROF_len, N_LEVS_len, moor)
  ! .................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'

    character*256, intent(in)  :: fname
    integer,       intent(out) :: N_PROF_len, N_LEVS_len
    character*78              :: fname_trim_ram
    character*76              :: fname_trim_tao
    character*79              :: fname_trim_pir
    character*69              :: fname_trim_mbt
    character*64              :: fname_trim_nbt
!   character*65              :: fname_trim_arg
    character*100             :: fname_trim_arg
    character*3                :: moor
    integer :: ncid, status, ndims, nvars
    integer :: N_PROF_id, N_LEVS_id

  ! ******************************************************************

  ! Open Dataset
  ! ............................
  if (moor=='RAM') then
    fname_trim_ram = adjustr(fname)
    status = nf_open(fname_trim_ram, 0, ncid)
  endif
  if (moor=='TAO') then
    fname_trim_tao = adjustr(fname)
    status = nf_open(fname_trim_tao, 0, ncid)
  endif
  if (moor=='PIR') then
    fname_trim_pir = adjustr(fname)
    status = nf_open(fname_trim_pir, 0, ncid)
  endif
  if (moor=='MBT') then
    fname_trim_mbt = adjustr(fname)
    status = nf_open(fname_trim_mbt, 0, ncid)
  endif
  if (moor=='NBT') then
    fname_trim_nbt = adjustr(fname)
    status = nf_open(fname_trim_nbt, 0, ncid)
  endif
  if (moor=='ARG') then
    fname_trim_arg = adjustr(fname)
    status = nf_open(fname_trim_arg, 0, ncid)
  endif

    if (status>0) then
      N_PROF_len = 0
      N_LEVS_len = 0
      status = nf_close(ncid)
      return
     endif

  ! Inquire about Dataset
  ! .................................
    status = nf_inq_ndims(ncid,ndims)
    status = nf_inq_nvars(ncid,nvars)
    
  ! Inquire about Dimensions
  ! .....................................................
    status = nf_inq_dimid(ncid,'N_PROF',N_PROF_id)
    status = nf_inq_dimlen(ncid,N_PROF_id,N_PROF_len)

    status = nf_inq_dimid(ncid,'N_LEVS',N_LEVS_id)
    status = nf_inq_dimlen(ncid,N_LEVS_id,N_LEVS_len)

    status = nf_close(ncid)

    !print *, N_PROF_len, N_LEVS_len

  return
  END SUBROUTINE read_netcdf_init


  ! .................................................................
    SUBROUTINE read_netcdf_init_date(fname_in,syear0,smon0,max_nobs,max_npts,N_PROF_len,N_LEVS_len, &
                                     date_time2, lon2, lat2, npts2, qc_flag2, data_id2, inst_id2,  &
                                     qc_prf2, depth2, field2, qc_lev2, obs_error2, factor2)
  ! .................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'

    character*256, intent(in)    :: fname_in
    character*4,   intent(in)    :: syear0
    character*2,   intent(in)    :: smon0
    integer,       intent(in)    :: max_nobs, max_npts
    integer,       intent(inout) :: N_PROF_len, N_LEVS_len

   ! VARIABLES
    integer, allocatable, dimension(:)     :: DATE_TIME, DATA_ID
    real,    allocatable, dimension(:)     :: LON, LAT, QC_PRF, FACTOR
    integer, allocatable, dimension(:)     :: NPTS, QC_FLAG, INST_ID
    real,    allocatable, dimension(:,:)   :: FIELD, DEPTH, OBS_ERROR, QC_LEV

    integer, dimension(max_nobs), intent(out)           :: DATE_TIME2, DATA_ID2
    real,    dimension(max_nobs), intent(out)           :: LON2, LAT2, QC_PRF2, FACTOR2
    integer, dimension(max_nobs), intent(out)           :: NPTS2, QC_FLAG2, INST_ID2
    real,    dimension(max_npts, max_nobs), intent(out) :: FIELD2, DEPTH2, OBS_ERROR2, QC_LEV2

    integer          :: VARid, VARtype, VARdims, VARatt, VARdimid 
    character*12     :: VARname

    integer :: ncid, status, ndims, nvars, good_obs, nobs, i
    integer :: N_PROF_id, N_LEVS_id

    character*10 :: sdate
    character*4  :: syear
    character*2  :: smon

  ! ******************************************************************

  ! Open Dataset
  ! ............................
    status   = nf_open(trim(fname_in), 0, ncid)

  ! Inquire about Dataset
  ! .................................
    status = nf_inq_ndims(ncid,ndims)
    status = nf_inq_nvars(ncid,nvars)
   
  ! Inquire about Dimensions
  ! .....................................................
    status = nf_inq_dimid(ncid,'N_PROF',N_PROF_id)
    status = nf_inq_dimlen(ncid,N_PROF_id,N_PROF_len)

    status = nf_inq_dimid(ncid,'N_LEVS',N_LEVS_id)
    status = nf_inq_dimlen(ncid,N_LEVS_id,N_LEVS_len)

    allocate ( DATA_ID(N_PROF_len), DATE_TIME(N_PROF_len), LON(N_PROF_len), LAT(N_PROF_len), FACTOR(N_PROF_len) )
    allocate ( NPTS(N_PROF_len), QC_FLAG(N_PROF_len), INST_ID(N_PROF_len),  QC_PRF(N_PROF_len) )
    allocate ( FIELD(N_LEVS_len,N_PROF_len), OBS_ERROR(N_LEVS_len,N_PROF_len) )
    allocate ( DEPTH(N_LEVS_len,N_PROF_len), QC_LEV(N_LEVS_len,N_PROF_len) )

    !print *, N_PROF_len, maxval(NPTS(1:N_PROF_len))
    DO VARid=1, nvars
      status = nf_inq_var(ncid,VARid,VARname,VARtype, &
                          VARdims,VARdimid,VARatt)

      if (VARname(1:len_trim(VARname))=='DATA_ID')      status = nf_get_var_int(ncid ,VARid, DATA_ID)
      if (VARname(1:len_trim(VARname))=='DATE_TIME')    status = nf_get_var_int(ncid , VARid, DATE_TIME)
      if (VARname(1:len_trim(VARname))=='LON')          status = nf_get_var_real(ncid ,VARid, LON)
      if (VARname(1:len_trim(VARname))=='LAT')          status = nf_get_var_real(ncid ,VARid, LAT)
      if (VARname(1:len_trim(VARname))=='NPTS')         status = nf_get_var_int(ncid , VARid, NPTS)
      if (VARname(1:len_trim(VARname))=='QC_FLAG')      status = nf_get_var_int(ncid , VARid, QC_FLAG)
      if (VARname(1:len_trim(VARname))=='INST_ID')      status = nf_get_var_int(ncid , VARid, INST_ID)
      if (VARname(1:len_trim(VARname))=='QC_PRF')       status = nf_get_var_real(ncid , VARid, QC_PRF)
      
      if (VARname(1:len_trim(VARname))=='TEMP')         status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SALT')         status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='OBS_ERROR')    status = nf_get_var_real(ncid ,VARid, OBS_ERROR)      
      if (VARname(1:len_trim(VARname))=='DEPTH')        status = nf_get_var_real(ncid ,VARid, DEPTH)
      if (VARname(1:len_trim(VARname))=='QC_LEV')       status = nf_get_var_real(ncid ,VARid, QC_LEV)

    ENDDO
    status = nf_close(ncid)

  nobs = N_PROF_len
  good_obs = 0
  !print *, 'NPTS2 ',maxval(NPTS2)

  do i=1,nobs
    write (sdate,'(I10)') DATE_TIME(i)
    smon  = sdate(5:6)
    syear = sdate(1:4)
    if (smon == smon0 .and. syear == syear0 .and. QC_PRF(i) == 1) then
      good_obs = good_obs + 1
           !print *, good_obs
           DATE_TIME2(good_obs) = DATE_TIME(i)
	   LON2(good_obs)       = LON(i)
	   LAT2(good_obs)       = LAT(i)
	   NPTS2(good_obs)      = NPTS(i)
	   QC_FLAG2(good_obs)   = QC_FLAG(i)
	   DATA_ID2(good_obs)   = DATA_ID(i)
	   INST_ID2(good_obs)   = INST_ID(i)
	   QC_PRF2(good_obs)    = QC_PRF(i)
	   DEPTH2(:,good_obs)   = DEPTH(:,i)
	   FIELD2(:,good_obs)   = FIELD(:,i)
	   QC_LEV2(:,good_obs)  = QC_LEV(:,i)	   
           OBS_ERROR2(:,good_obs) = OBS_ERROR(:,i)
           FACTOR2(good_obs)      = NPTS(i) + DEPTH(NPTS(i)-1,i)/100

    endif
  enddo
  nobs = good_obs
  N_PROF_len = nobs
  
  deallocate ( DATE_TIME, LON, LAT, NPTS, QC_FLAG, DATA_ID, INST_ID, QC_PRF, FIELD, QC_LEV, OBS_ERROR, FACTOR)

  return
  END SUBROUTINE read_netcdf_init_date




  ! ..................................................................................
    SUBROUTINE read_netcdf (fname,max_nobs,max_npts,inst_error, &
               var_id,missing,date_time,lon,lat,npts,qc_flag,data_id,inst_id,  &
               qc_prf,depth,field,qc_lev,obs_error,     &
               title,source,history,conventions,moor)
  ! ..................................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'
   
    integer,       intent(in) :: max_nobs, max_npts
    character*256, intent(in) :: fname
    character*78              :: fname_trim_ram
    character*76              :: fname_trim_tao
    character*79              :: fname_trim_pir
    character*69              :: fname_trim_mbt
    character*64              :: fname_trim_nbt
!   character*65              :: fname_trim_arg
    character*100             :: fname_trim_arg
    character*3                :: moor

 ! DATASET INFORMATION
   integer          :: status, ncid
   integer          :: ndims, nvars, ngatts, unlimdimid

   integer          :: RECid, RECnum
   character*12     :: RECname
   
   integer          :: VARid, VARtype, VARdims, VARatt
   character*12     :: VARname

   integer          :: N_PROF, N_LEVS
   
   integer, allocatable, dimension(:) :: VARdimlen, VARdimid 

!  GLOBAL ATTRIBUTES
   character*64                     :: HISTORY, CONVENTIONS
   character*64                     :: TITLE, SOURCE

!  VARIABLES
   integer                          :: VAR_ID
   real                             :: INST_ERROR, MISSING
   
   integer, dimension(max_nobs)     :: DATE_TIME, DATA_ID
   real,    dimension(max_nobs)     :: LON, LAT, QC_PRF
   integer, dimension(max_nobs)     :: NPTS, QC_FLAG, INST_ID
   real,    dimension(max_npts,max_nobs) :: FIELD, DEPTH, OBS_ERROR, QC_LEV

! OPEN NETCDF FILE AND GET DATASET INFO
! .........................................
  !print *, len(adjustr(fname))
  if (moor=='RAM') then
    fname_trim_ram = adjustr(fname)
    status = nf_open(fname_trim_ram, 0, ncid)
  endif
  if (moor=='TAO') then
    fname_trim_tao = adjustr(fname)
    status = nf_open(fname_trim_tao, 0, ncid)
  endif
  if (moor=='PIR') then
    fname_trim_pir = adjustr(fname)
    status = nf_open(fname_trim_pir, 0, ncid)
  endif
  if (moor=='MBT') then
    fname_trim_mbt = adjustr(fname)
    status = nf_open(fname_trim_mbt, 0, ncid)
  endif
  if (moor=='NBT') then
    fname_trim_nbt = adjustr(fname)
    status = nf_open(fname_trim_nbt, 0, ncid)
  endif
  if (moor=='ARG') then
    fname_trim_arg = adjustr(fname)
    status = nf_open(fname_trim_arg, 0, ncid)
  endif

  if (status>0) then
      status = nf_close(ncid)
      print *, 'ERROR in reading file '
      return
    endif

  status = nf_inq(ncid,ndims,nvars,ngatts,unlimdimid)

  allocate( VARdimlen(ndims-1), VARdimid(ndims-1))

 ! Get Dimension Id, Name, Length
    DO RECid=1, ndims
      status = nf_inq_dim(ncid,RECid,RECname,VARdimlen(RECid))
    ENDDO

! Get Global Attributes
  status = nf_get_att_text(ncid, nf_global, 'title',        TITLE)
  status = nf_get_att_text(ncid, nf_global, 'source',       SOURCE)    
  status = nf_get_att_text(ncid, nf_global, 'history',      HISTORY)
  status = nf_get_att_text(ncid, nf_global, 'Conventions',  CONVENTIONS)
 

 ! Get Variable Id, Name, Type, Dim, Dimid, Att, and Value
 ! .......................................................
   DO VARid=1, nvars
      status = nf_inq_var(ncid,VARid,VARname,VARtype, &
                          VARdims,VARdimid,VARatt)

      if (VARname(1:len_trim(VARname))=='VAR_ID')       status = nf_get_var_int  (ncid, VARid, VAR_ID)
      if (VARname(1:len_trim(VARname))=='INST_ERROR')   status = nf_get_var_real (ncid, VARid, INST_ERROR)
      if (VARname(1:len_trim(VARname))=='MISSING')      status = nf_get_var_real (ncid, VARid, MISSING)
      
      if (VARname(1:len_trim(VARname))=='DATA_ID')      status = nf_get_var_int(ncid ,VARid, DATA_ID)
      if (VARname(1:len_trim(VARname))=='DATE_TIME')    status = nf_get_var_int(ncid , VARid, DATE_TIME)
      if (VARname(1:len_trim(VARname))=='LON')          status = nf_get_var_real(ncid ,VARid, LON)
      if (VARname(1:len_trim(VARname))=='LAT')          status = nf_get_var_real(ncid ,VARid, LAT)
      if (VARname(1:len_trim(VARname))=='NPTS')         status = nf_get_var_int(ncid , VARid, NPTS)
      if (VARname(1:len_trim(VARname))=='QC_FLAG')  status = nf_get_var_int(ncid , VARid, QC_FLAG)
      if (VARname(1:len_trim(VARname))=='INST_ID')       status = nf_get_var_int(ncid , VARid, INST_ID)
      if (VARname(1:len_trim(VARname))=='QC_PRF')      status = nf_get_var_real(ncid , VARid, QC_PRF)
      
      if (VARname(1:len_trim(VARname))=='TEMP')         status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SALT')         status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SLA')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SSS')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SST')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='ICE')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='OBS_ERROR')    status = nf_get_var_real(ncid ,VARid, OBS_ERROR)      
      if (VARname(1:len_trim(VARname))=='DEPTH')        status = nf_get_var_real(ncid ,VARid, DEPTH)
      if (VARname(1:len_trim(VARname))=='QC_LEV')       status = nf_get_var_real(ncid ,VARid, QC_LEV)
      !print *, VARid, status, VARname
   ENDDO
  
   status = nf_close(ncid)

  return
  END SUBROUTINE read_netcdf


 ! ..................................................................................
    SUBROUTINE read_netcdf_month (fname,imon,max_nobs,max_npts,inst_error, &
               var_id,missing,date_time,lon,lat,npts,qc_flag,data_id,inst_id,  &
               qc_prf,depth,field,qc_lev,obs_error,     &
               title,source,history,conventions)
  ! ..................................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'

    integer,       intent(in) :: max_nobs, max_npts, imon
    character*256, intent(in) :: fname

 ! DATASET INFORMATION
   integer          :: status, ncid
   integer          :: ndims, nvars, ngatts, unlimdimid

   integer          :: RECid, RECnum
   character*12     :: RECname
   
   integer          :: VARid, VARtype, VARdims, VARatt
   character*12     :: VARname

   integer          :: N_PROF, N_LEVS
   
   integer, allocatable, dimension(:) :: VARdimlen, VARdimid 

!  GLOBAL ATTRIBUTES
   character*64                     :: HISTORY, CONVENTIONS
   character*64                     :: TITLE, SOURCE

!  VARIABLES
   integer                          :: VAR_ID
   real                             :: INST_ERROR, MISSING
   
   integer, dimension(max_nobs)     :: DATE_TIME, DATA_ID
   real,    dimension(max_nobs)     :: LON, LAT, QC_PRF
   integer, dimension(max_nobs)     :: NPTS, QC_FLAG, INST_ID
   real,    dimension(max_npts,max_nobs) :: FIELD, DEPTH, OBS_ERROR, QC_LEV

! OPEN NETCDF FILE AND GET DATASET INFO
! .........................................
  status = nf_open(trim(fname), nf_write, ncid)
  status = nf_inq(ncid,ndims,nvars,ngatts,unlimdimid)

  allocate( VARdimlen(ndims-1), VARdimid(ndims-1))

 ! Get Dimension Id, Name, Length
    DO RECid=1, ndims
      status = nf_inq_dim(ncid,RECid,RECname,VARdimlen(RECid))
    ENDDO

! Get Global Attributes
  status = nf_get_att_text(ncid, nf_global, 'title',        TITLE)
  status = nf_get_att_text(ncid, nf_global, 'source',       SOURCE)    
  status = nf_get_att_text(ncid, nf_global, 'history',      HISTORY)
  status = nf_get_att_text(ncid, nf_global, 'Conventions',  CONVENTIONS)
 

 ! Get Variable Id, Name, Type, Dim, Dimid, Att, and Value
 ! .......................................................
   DO VARid=1, nvars
      status = nf_inq_var(ncid,VARid,VARname,VARtype, &
                          VARdims,VARdimid,VARatt)

      if (VARname(1:len_trim(VARname))=='VAR_ID')       status = nf_get_var_int  (ncid, VARid, VAR_ID)
      if (VARname(1:len_trim(VARname))=='INST_ERROR')   status = nf_get_var_real (ncid, VARid, INST_ERROR)
      if (VARname(1:len_trim(VARname))=='MISSING')      status = nf_get_var_real (ncid, VARid, MISSING)
      
      if (VARname(1:len_trim(VARname))=='DATA_ID')      status = nf_get_var_int(ncid ,VARid, DATA_ID)
      if (VARname(1:len_trim(VARname))=='DATE_TIME')    status = nf_get_var_int(ncid , VARid, DATE_TIME)
      if (VARname(1:len_trim(VARname))=='LON')          status = nf_get_var_real(ncid ,VARid, LON)
      if (VARname(1:len_trim(VARname))=='LAT')          status = nf_get_var_real(ncid ,VARid, LAT)
      if (VARname(1:len_trim(VARname))=='NPTS')         status = nf_get_var_int(ncid , VARid, NPTS)
      if (VARname(1:len_trim(VARname))=='QC_FLAG')  status = nf_get_var_int(ncid , VARid, QC_FLAG)
      if (VARname(1:len_trim(VARname))=='INST_ID')       status = nf_get_var_int(ncid , VARid, INST_ID)
      if (VARname(1:len_trim(VARname))=='QC_PRF')      status = nf_get_var_real(ncid , VARid, QC_PRF)
      
      if (VARname(1:len_trim(VARname))=='TEMP')         status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SALT')         status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SLA')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SSS')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='SST')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='ICE')          status = nf_get_var_real(ncid ,VARid, FIELD)
      if (VARname(1:len_trim(VARname))=='OBS_ERROR')    status = nf_get_var_real(ncid ,VARid, OBS_ERROR)      
      if (VARname(1:len_trim(VARname))=='DEPTH')        status = nf_get_var_real(ncid ,VARid, DEPTH)
      if (VARname(1:len_trim(VARname))=='QC_LEV')       status = nf_get_var_real(ncid ,VARid, QC_LEV)
      !print *, VARid, status, VARname
   ENDDO
  
   status = nf_close(ncid)

  return
  END SUBROUTINE read_netcdf_month
  ! ..................................................................................
    SUBROUTINE read_netcdf_date (fname,max_nobs,max_npts,date_time)
  ! ..................................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'
    
    integer,       intent(in) :: max_nobs, max_npts
    character*256, intent(in) :: fname

 ! DATASET INFORMATION
   integer          :: status, ncid
   integer          :: ndims, nvars, ngatts, unlimdimid

   integer          :: RECid, RECnum
   character*12     :: RECname
   
   integer          :: VARid, VARtype, VARdims, VARatt
   character*12     :: VARname

   integer          :: N_PROF, N_LEVS
   
   integer, allocatable, dimension(:) :: VARdimlen, VARdimid 

  
   integer, dimension(max_nobs)     :: DATE_TIME

! OPEN NETCDF FILE AND GET DATASET INFO
! .........................................
  status = nf_open(trim(fname), nf_write, ncid)
  status = nf_inq(ncid,ndims,nvars,ngatts,unlimdimid)

  allocate( VARdimlen(ndims-1), VARdimid(ndims-1))

 ! Get Dimension Id, Name, Length
    DO RECid=1, ndims
      status = nf_inq_dim(ncid,RECid,RECname,VARdimlen(RECid))
    ENDDO

 
 ! Get Variable Id, Name, Type, Dim, Dimid, Att, and Value
 ! .......................................................
   DO VARid=1, nvars
      status = nf_inq_var(ncid,VARid,VARname,VARtype, &
                          VARdims,VARdimid,VARatt)

      if (VARname(1:len_trim(VARname))=='DATE_TIME')    status = nf_get_var_int(ncid , VARid, DATE_TIME)
   ENDDO
  
   status = nf_close(ncid)

  return
  END SUBROUTINE read_netcdf_date

  ! .................................................................
    SUBROUTINE write_grid(fname_out,im,jm,lon,lat)
  ! .................................................................
    IMPLICIT NONE
    INCLUDE 'netcdf.inc'
 
    character*7,   intent(in) :: fname_out
    integer,       intent(in) :: im,jm
    real,          intent(in) :: lon(jm,im), lat(jm,im)

    integer           :: ncid, status
    integer           :: N_IMdim,   N_IMid
    integer           :: N_JMdim,   N_JMid
    integer           :: DATA_IDdim(2), DATA_IDid

    integer           :: LONid, LATid 
    integer           :: startVAR(2), countVAR(2), VARdim(2)


   ! *****************************************************************!

    startVAR = (/ 1,1 /)
    countVAR = (/ jm,im /)
    
   ! Create netcdf file and ncid
     status = nf_create(trim(fname_out), nf_write, ncid)
   
   ! Define Dimensions
     status = nf_def_dim(ncid,'IM', im, N_IMdim)
     status = nf_def_dim(ncid,'JM', jm, N_JMdim)

   ! Define Variables
   ! ................

     VARdim(1) = N_JMdim
     VARdim(2) = N_IMdim     

     status = nf_def_var(ncid,'LAT',  nf_real, 2, VARdim, LATid)
     status = nf_def_var(ncid,'LON',  nf_real, 2, VARdim, LONid)
 
   ! Leave Define Mode
     status = nf_enddef(ncid)

   ! Write Variables
   ! ..........................................................................................
     status = nf_put_vara_real   (ncid, LONid,          startVAR, countVAR, lon)
     status = nf_put_vara_real   (ncid, LATid,          startVAR, countVAR, lat)

   ! Close Dataset
     status = nf_close(ncid)

  return
  END SUBROUTINE write_grid




END MODULE NETCDF_MODULE_MOOR
