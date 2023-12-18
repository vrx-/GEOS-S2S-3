  PROGRAM read_pir
 
! COMPILE WITH: make read_pir
! RUN WITH    : read_pir.exe svar
!
! svar = 'TEMP', 'SALT'
!
! Reformats pir data from ascii to netcdf and extracts data by year
! Working with the daily averaged data from the pir web page
! Outputs yearly netcdf files
!
! Updated Oct 2013 for Discover
   
   USE MISC_MODULE 
   USE ZEUS_CLOCKS
   USE PMEL_MODULE
   USE NETCDF_MODULE_ODAS2
   
   IMPLICIT NONE
  
   !integer :: yrbeg  = 1997
   integer :: yrbeg  = 2018
   integer :: yrend  = 2022
   integer :: monbeg = 12
   integer :: monend = 1
   
   real    :: ming = 100
   real    :: maxg = 0
   real    :: meang
 
   real,         parameter     :: miss         = 999.e9
   integer,      parameter     :: miss_flag    = 9
 
   integer,      parameter     :: nlevs        = 30
   integer,      parameter     :: maxstns      = 100
   integer,      parameter     :: inst_id      = 502
   real,         parameter     :: tqc_prf      = 1
   integer,      parameter     :: qc_flag      = 0
   character*64                :: title 
   character*64                :: source
   character*64                :: desc
!  character*65               :: dir 
   character*256              :: dir 
   character*256               :: fout
 
   integer                     :: nobs, var_id, fl
   real                        :: inst_error
   integer,      parameter     :: maxdays = 428, maxnobs = maxdays*maxstns
   integer                     :: ibas_gen(maxstns), ibas_spc(maxstns)
   character*8                 :: sdate
   character*10                :: sdate_time
   character*4                 :: svar
   character*4		       :: syyyy
   character*4		       :: eyyyy

   
type pir_struct
      integer            :: date, date_time
      integer            :: qc_flag, data_id
      real               :: tqc_prf
      integer            :: inst_id, npts
      character*8        :: stn_name
      real	         :: lon, lat
   end type pir_struct
   type (pir_struct), dimension(maxnobs) :: pir

   real               :: depth(nlevs,maxnobs)
   real               :: temp(nlevs,maxnobs)
   real               :: tqc_lev(nlevs,maxnobs) = 1.0
   real               :: obs_err(nlevs,maxnobs) = 0.5

   ! WMO Stuff
   character*6, dimension(maxstns) :: pir_wmo1, pir_wmo2, pir_stn
   integer,     dimension(maxstns) :: pir_data_id,data_id
   character*8, dimension(maxstns) :: stn_name
   integer                         :: markpir, ipir
   integer, parameter              :: UNIT_PIR_WMO  = 100
   integer, parameter              :: UNIT_PIR_LIST = 110
   integer, parameter              :: UNIT_STAT     = 120
   character*13, parameter         :: fname_pir = 'pir_wmo.ascii'

   real, dimension(maxstns)        :: lon, lat

   real, allocatable, dimension(:,:,:) :: temps  ! big array of temperatures
   real, allocatable, dimension(:,:)   :: tdummy ! array for single mooring

   real, allocatable, dimension(:,:,:) :: depths ! big array of depths
   real, allocatable, dimension(:,:)   :: tdeps !  array for single mooring
   
   integer, allocatable :: nidate(:)

   integer     :: ndat, nd, ieof, month, mon, hh
   integer     :: i, j, k, m, ndata, iyear, year0, year2
   real        :: flag, xlon, xlat

   character*256    :: fname_in
   character*256   :: fname_out, fname_stats, fname
   integer         :: markout
   logical         :: exist
 
   data fname_stats/'latest_data'/

   call GETARG (1, svar)
   call GETARG (2, syyyy)
   call GETARG (3, eyyyy)

   read (syyyy, *) yrbeg
   read (eyyyy, *) yrend

   if (svar=='TEMP') then
     title   = 'PMEL Pirata Temperature Profiles'
     source  = 'ftp.pmel.noaa.gov'
     desc    = 'PMEL Pirata Temperature Profiles'
!    dir     = '/gpfsm/dnb04/projects/p71/aogcm/g5odas/obs/assim/PIRATA/V3/FINAL/'
!     dir     = '/gpfsm/dnb78s2/projects/p26/ehackert/TAO_PIRATA_RAMA_processing/MOOR/PIRATA/V3/FINAL/'
     dir     = '/discover/nobackup/lren1/pre_proc/NRT/MOOR/PIRATA/V3/FINAL/'
     !print *, len(dir)
     !stop
     var_id  = 101
     tqc_lev(nlevs,maxnobs) = 1.0
     obs_err(nlevs,maxnobs) = 0.5
     inst_error             = 0.09 ! 0.02 after 2002
     data fname_out/'T_PIR_1980.nc'/

   elseif (svar=='SALT') then
     title   = 'PMEL Pirata Salinity Profiles'
     source  = 'ftp.pmel.noaa.gov'
     desc    = 'PMEL Pirata Salinity Profiles'
!    dir     = '/gpfsm/dnb04/projects/p71/aogcm/g5odas/obs/assim/PIRATA/V3/FINAL/'
!     dir     = '/gpfsm/dnb78s2/projects/p26/ehackert/TAO_PIRATA_RAMA_processing/MOOR/PIRATA/V3/FINAL/'
     dir     = '/discover/nobackup/lren1/pre_proc/NRT/MOOR/PIRATA/V3/FINAL/'     
     var_id  = 102
     tqc_lev(nlevs,maxnobs) = 1.0
     obs_err(nlevs,maxnobs) = 0.2
     inst_error             = 0.1
     data fname_out/'S_PIR_1980.nc'/
   endif
 
! ******************************************************************
  temp    = miss
  depth   = miss

  markout      = scan(fname_out,'1980')

! Open pir WMO numbers ascii file
! pir_wmo1 is pirname from ftp site, pir_wmo2 is real wmo number
! ..............................................................
  OPEN (UNIT_PIR_WMO, file=fname_pir, status='old', form='formatted')
  ieof = 0
  ipir = 1
  DO WHILE (ieof == 0)
     read (UNIT_PIR_WMO, '(a6,1x,a6,1x,i8)',iostat = ieof) &
          pir_wmo1(ipir),pir_wmo2(ipir), pir_data_id(ipir)
     if (ieof /= 0) exit
     print *, '*',pir_wmo1(ipir),'*',pir_wmo2(ipir),'*',pir_data_id(ipir)   
     ipir = ipir + 1             
  ENDDO
  CLOSE (UNIT_PIR_WMO)
  ipir = ipir - 1

      
! Work one year at a time, Work out how large the time arrays
! ...........................................................
  mon = 2

  DO iyear=yrbeg,yrend

     inst_error = 0.09
     if (iyear >= 2002) then
       inst_error = 0.02
     endif
     if (svar=='SALT') then
       inst_error = 0.1
     endif

     year0 = iyear-1
     year2 = iyear+1

     write(fname_out(markout:markout+3),'(i4)') iyear

     nd = 0
     do month=monbeg,12
        nd = nd + Z_DAYSINM(month,year0)
     enddo
     nd = nd + 337 + Z_DAYSINM(mon,iyear)
     do month=1,monend
        nd = nd + Z_DAYSINM(month,year2)
     enddo

     !print *, nd, ' days in ', monbeg, '/', year0, ' to ', monend, '/', year2

     allocate ( nidate(nd) )
     allocate ( temps(maxstns,nlevs,nd) )
     allocate ( tdummy(nlevs,1:nd) )
     allocate ( depths(maxstns,nlevs,nd) )
     allocate ( tdeps(nlevs,1:nd) )
       
     temps = miss

     ! CALL make_dates
     ! ..........................
       call make_dates(year0, monbeg, year2, monend, nidate)
       if (svar=='TEMP') then
         open(UNIT_PIR_LIST,file='pir_temp_files.list',form='formatted',status='old')
       elseif (svar=='SALT') then
         open(UNIT_PIR_LIST,file='pir_salt_files.list',form='formatted',status='old')
       endif
       
       !open(UNIT_pir_LIST,file='pir_files.list',form='formatted',status='old')
       DO k=1,maxstns
          read(UNIT_pir_LIST,fmt='(a)',end=999) fname_in
          markpir = scan(trim(fname_in),'.')
          
          print *, k, trim(fname_in)
          fl = markpir + 5
          !print *, fname_in(markpir-7 : markpir-4)
          
!          if ( markpir == 78 ) then
!             fl = 83
!             pir_stn(k) = fname_in(markpir-7 : markpir-4)
!             print *, fl, pir_stn(k)
!             
!          elseif ( markpir == 79 ) then
!             fl = 84
!             pir_stn(k) = fname_in(markpir-8 : markpir-4)
!             !print *, fl, pir_stn(k)
             
!         elseif ( markpir == 80 ) then
!             fl = 85
!             pir_stn(k) = fname_in(markpir-9 : markpir-4)
             !print *, fl, pir_stn(k)
             
!         elseif ( markpir == 81 ) then
!             fl = 86
!             pir_stn(k) = fname_in(markpir-10 : markpir-4)
             !print *, fl, pir_stn(k)
             
!         elseif ( markpir == 82 ) then
!             fl = 87
!             pir_stn(k) = fname_in(markpir-11 : markpir-4)
             !print *, fl, pir_stn(k)
             
!         elseif ( markpir == 70 ) then
!             fl = 75
!             pir_stn(k) = fname_in(markpir-8 : markpir-4)
             !print *, '70 ', pir_stn(k)
!         elseif ( markpir == 71 ) then
!             fl = 76
!             pir_stn(k) = fname_in(markpir-9 : markpir-4)
             !print *, '71 ', pir_stn(k)
!         elseif ( markpir == 72 ) then
!             fl = 77
!             pir_stn(k) = fname_in(markpir-10 : markpir-4)
             !print *, '72 ', pir_stn(k)         
             
!          else
!            print *, trim(fname_in), ' ', markpir, '*',pir_stn(k),'*' 
!            print *, 'stopping'
!            stop     
!          endif        

          !print *, trim(fname_in), ' ', markpir, '*',pir_stn(k),'*' 
                 
   
          do i=1,ipir
             if ( pir_stn(k) == pir_wmo1(i) ) then
                stn_name(k) = pir_wmo2(i)
                data_id(k)  = pir_data_id(i)
                !print *, pir_stn(k),' ', stn_name(k), data_id(k)
             endif
          enddo

          call read_raw_pmel(trim(fname_in), nlevs, tdeps, nidate, &
                            flag, xlat, xlon, nd, tdummy, miss,svar,fl)

          lat(k) = xlat
          lon(k) = xlon
          if (xlon < 0.) lon(k) = xlon+360.
          temps(k,1:nlevs,1:nd)= tdummy(1:nlevs,1:nd)
          depths(k,1:nlevs,1:nd)= tdeps(1:nlevs,1:nd)
       ENDDO ! maxstns
 
   999  close(UNIT_PIR_LIST)

  ! For each year,
  ! Loop through days and stations,getting data with ndat>0
  ! Put data in pir structure by nobs=nd*maxstns
       nobs = 0
       DO i=1,nd
          ndata = 0
          do m=1,maxstns
             ndat = count(temps(m,1:nlevs,i) < miss )
             if (ndat > 0) then
                nobs = nobs + 1                
                ndata = ndata + ndat
                pir(nobs)%date            = nidate(i)
                ! Add hour interger (12 noon)
                   write (sdate,'(I8)') nidate(i)
                   sdate_time = sdate // '12'
                   read (sdate_time,*) pir(nobs)%date_time
 
                pir(nobs)%lon             = lon(m)
                if (pir(nobs)%lon > 180) then
                  pir(nobs)%lon =  pir(nobs)%lon- 360
                endif

                pir(nobs)%lat             = lat(m)
                pir(nobs)%npts            = ndat
                pir(nobs)%qc_flag         = qc_flag
                pir(nobs)%data_id         = data_id(m)
                pir(nobs)%inst_id         = inst_id
                pir(nobs)%tqc_prf         = tqc_prf
                depth(1:ndat,nobs)        = depths(m,1:ndat,i)
                temp(1:ndat,nobs)         = temps(m,1:ndat,i)
                tqc_lev(1:ndat,nobs)      = 1
		obs_err(1:ndat,nobs)      = 0.5
	     endif
          enddo  ! m, number of stations
          !print *,  nidate(i), ': ',ndata,'  observations'          
       ENDDO     ! nd, number of days in year                    
       !print *,  nobs, ' observations in ', iyear

       deallocate ( nidate)
       deallocate ( temps, tdummy, depths, tdeps )

 
     ! Write netCDF File
     ! ..................................................
       fname = trim(fname_out)
       if (svar=='SALT') then
         fname = 'S' // fname_out(2:14)
       endif
       fout = trim(dir) // trim(fname)
       inquire (file=trim(fout), exist=exist) 
       !print *, trim(fout), nd, nobs
       ! *, '   ',trim(fname), nd, nobs

 
       IF (exist) then    
          call append_netcdf(fout,maxnobs,nobs,nlevs,inst_error, &
               var_id,miss,pir%date_time, &
               pir%lon,pir%lat,pir%npts,&
               pir%qc_flag,pir%data_id,pir%inst_id, &
               pir%tqc_prf,depth,temp,tqc_lev,obs_err,svar)
       ELSE 
          call write_netcdf(fout,maxnobs,nobs,nlevs,inst_error, &
               var_id,miss,pir%date_time, &
               pir%lon,pir%lat,pir%npts, &
               pir%qc_flag,pir%data_id,pir%inst_id, &
               pir%tqc_prf,depth,temp,tqc_lev,obs_err,title,source,svar) 
       ENDIF

  ENDDO  !  iyear

  ! print *, pir(nobs)%date
  !print *, fout
  open(UNIT_STAT, file=fname_stats, status='unknown', form='formatted')
  write(UNIT_STAT, '(i8)') pir(nobs)%date
  close(UNIT_STAT)


  END PROGRAM read_pir


