from netCDF4 import Dataset
import numpy as np
import time
import sys


def param(inst,var):
        param.MISSING = '9.99e11'

        if (inst=='AVISO') & (var=='U'):
            param.VAR= 'U'
            param.VAR_ID     = 103
            param.INST_ID    = 517
            param.INST_ERROR = 0.04
            param.UNITS      = 'm/s'
            param.LONG_NAME  = 'Geostrophic velocity anomalies: zonal component'
            param.SOURCE     = 'ftp.aviso.oceanobs.com'
            param.TITLE      = 'AVISO Geostrophic Velocity Anomalies (m/s)'

        if (inst=='AVISO') & (var=='V'):
            param.VAR= 'V'
            param.VAR_ID     = 104
            param.INST_ID    = 517
            param.INST_ERROR = 0.04
            param.UNITS      = 'm/s'
            param.LONG_NAME  = 'Geostrophic velocity anomalies: meridional component'
            param.SOURCE     = 'ftp.aviso.oceanobs.com'
            param.TITLE      = 'AVISO Geostrophic Velocity Anomalies (m/s)'

        if (inst=='AVISO') & (var=='SLA'):
            param.VAR= 'SLA'
            param.VAR_ID     = 105
            param.INST_ID    = 517
            param.INST_ERROR = 0.02
            param.UNITS      = 'm'
            param.LONG_NAME  = 'Sea Level Anomaly'
            param.SOURCE     = 'ftp.aviso.oceanobs.com'
            param.TITLE      = 'AVISO Sea Level Anomaly (m)'

        if (inst=='AVISO') & (var=='ADT'):
            param.VAR= 'ADT'
            param.VAR_ID     = 109
            param.INST_ID    = 517
            param.INST_ERROR = 0.02
            param.UNITS      = 'm'
            param.LONG_NAME  = 'Absolute Dynamic Topography'
            param.SOURCE     = 'ftp.aviso.oceanobs.com'
            param.TITLE      = 'AVISO Absolute Dynamic Topography (m)'

        if (inst=='REYN') & (var=='T'):
            param.VAR= 'TEMP'
            param.VAR_ID     = 101
            param.INST_ID    = 516
            param.INST_ERROR = 0.01
            param.UNITS      = 'C'
            param.LONG_NAME  = 'Sea Surface Temperature'
            param.SOURCE     = 'ftp://eclipse.ncdc.noaa.gov/pub/OI-daily-v2/'
            param.TITLE      = 'REYN-OI V2 Gridded Daily SST'

        if (inst=='OSTIA') & (var=='T'):
            param.VAR= 'TEMP'
            param.VAR_ID     = 101
            param.INST_ID    = 525
            param.INST_ERROR = 0.01
            param.UNITS      = 'C'
            param.LONG_NAME  = 'Sea Surface Temperature'
            param.SOURCE     = '/archive/input/dao_ops/obs/flk/ukmet_sst/netcdf/OSTIA/'
            param.TITLE      = 'OSTIA Gridded Daily SST'

        if (inst=='REYN') & (var=='ICE'):
            param.VAR= 'ICE'
            param.VAR_ID     = 106
            param.INST_ID    = 523
            param.INST_ERROR = 0.05
            param.UNITS      = '%'
            param.LONG_NAME  = 'Ice Concentration'
            param.SOURCE     = 'ftp://eclipse.ncdc.noaa.gov/pub/OI-daily-v2/'
            param.TITLE      = 'REYN-OI V2 Gridded Daily ICE at North Pole'

        if (inst=='OSTIA') & (var=='ICE'):
            param.VAR= 'ICE'
            param.VAR_ID     = 106
            param.INST_ID    = 526
            param.INST_ERROR = 0.05
            param.UNITS      = '%'
            param.LONG_NAME  = 'Ice Concentration'
            param.SOURCE     = '/archive/input/dao_ops/obs/flk/ukmet_sst/netcdf/OSTIA/'
            param.TITLE      = 'OSTIA Gridded Daily ICE'

        if (inst=='NSIDC') & (var=='ICE'):
            param.VAR= 'ICE'
            param.VAR_ID     = 106
            param.INST_ID    = 518
            param.INST_ERROR = 0.05
            param.UNITS      = '%'
            param.LONG_NAME  = 'Ice Concentration'
            param.SOURCE     = 'http://nsidc.org/data/nsidc-0051.html'
            param.TITLE      = 'NSIDC Gridded Daily ICE'

        if (inst=='IB') & (var=='HICE'):
            param.VAR= 'HICE'
            param.VAR_ID     = 107
            param.INST_ID    = 527
            param.INST_ERROR = 0.05
            param.UNITS      = 'm'
            param.LONG_NAME  = 'Ice Thickness'
            param.SOURCE     = '/gpfsm/dnb02/bzhao/ObservationData/IB/Y2012/'
            param.TITLE      = 'Ice-Bridge Data'


        if (inst=='CRYOSAT') & (var=='HICE'):
            param.VAR= 'HICE'
            param.VAR_ID     = 107
            param.INST_ID    = 530
            param.INST_ERROR = 0.05
            param.UNITS      = 'm'
            param.LONG_NAME  = 'Ice Thickness'
            param.SOURCE     = 'CryoSat-2 sea ice thickness and ancillary data'
            param.TITLE      = 'CryoSat Ice Thickness'


        if (inst=='WOA18-ARGO') & (var=='TEMP'):
            param.VAR= 'TEMP'
            param.VAR_ID     = 101
            param.INST_ID    = 557
            param.INST_ERROR = 0.5
            param.UNITS      = 'C'
            param.LONG_NAME  = 'TEMPERATURE'
            param.SOURCE     = 'WOA18 data subsampled at Argo locations'
            param.TITLE      = 'WAO18 Temperature at Argo'

        if (inst=='WOA18-ARGO') & (var=='SALT'):
            param.VAR= 'SALT'
            param.VAR_ID     = 102
            param.INST_ID    = 557
            param.INST_ERROR = 0.5
            param.UNITS      = 'PSU'
            param.LONG_NAME  = 'SALINITY'
            param.SOURCE     = 'WOA18 data subsampled at Argo locations'
            param.TITLE      = 'WAO18 Salinity at Argo'


        if (inst=='WOA18-NA') & (var=='TEMP'):
            param.VAR= 'TEMP'
            param.VAR_ID     = 101
            param.INST_ID    = 558
            param.INST_ERROR = 0.5
            param.UNITS      = 'C'
            param.LONG_NAME  = 'TEMPERATURE'
            param.SOURCE     = 'WOA18 data subsampled at North Atlantic Ocean'
            param.TITLE      = 'WAO18 Temperature at North Atlantic'

        if (inst=='WOA18-NA') & (var=='SALT'):
            param.VAR= 'SALT'
            param.VAR_ID     = 102
            param.INST_ID    = 558
            param.INST_ERROR = 0.5
            param.UNITS      = 'PSU'
            param.LONG_NAME  = 'SALINITY'
            param.SOURCE     = 'WOA18 data subsampled at North Atlantic Ocean'
            param.TITLE      = 'WAO18 Salinity at North Atlantic'




        return param


########################################################################
def write_nc_2D(fname,param,N_PROF,DATA_ID,DATE_TIME,LON,LAT,NPTS,QC_FLAG,INST_ID,QC_PRF,DATA,OBS_ERROR,DEPTH,QC_LEV):

     tm,zm = np.shape(DATA)
     #print 'Write ', tm

     ncfile = Dataset(fname,'w',format='NETCDF3_CLASSIC')

     ncfile.createDimension('N_PROF',None)
     ncfile.createDimension('N_LEVS',zm)
     ncfile.createDimension('SCALAR',1)

     ncfile.title       = param.TITLE 
     ncfile.source      = param.SOURCE
     ncfile.history     = 'Updated on '+(time.strftime("%Y%m%d"))
     ncfile.Conventions = 'COARDS'
     ncfile.Version     = 'netcdf-4.0'

     t    = ncfile.createVariable('VAR_ID',np.dtype('i4').char,('SCALAR'))
     t[:] = param.VAR_ID   
     t.long_name = 'Variable Identification Code'

     t    = ncfile.createVariable('INST_ERROR',np.dtype('float32').char,('SCALAR'))
     t[:] = param.INST_ERROR   
     t.long_name = 'Instrument Error'

     t    = ncfile.createVariable('MISSING',np.dtype('float32').char,('SCALAR'))
     t[:] = param.MISSING    
     t.long_name = 'Missing Data Value'

     t    = ncfile.createVariable('N_PROF',np.dtype('double').char,('N_PROF'))
     t[:] = N_PROF   

     t    = ncfile.createVariable('DATA_ID',np.dtype('i4').char,('N_PROF'))
     t[:] = DATA_ID    
     t.long_name = 'Unique Data Identifier'

     t    = ncfile.createVariable('DATE_TIME',np.dtype('i4').char,('N_PROF'))
     t[:] = DATE_TIME    
     t.long_name = 'Date of Observation: YYYYMMDDhh'

     t    = ncfile.createVariable('LON',np.dtype('float32').char,('N_PROF'))
     t[:] = LON  
     t.long_name = 'Longitude'
     t.units     = 'degrees-east'

     t    = ncfile.createVariable('LAT',np.dtype('float32').char,('N_PROF'))
     t[:] = LAT    
     t.long_name = 'Latitude'
     t.units     = 'degrees-north'

     t    = ncfile.createVariable('NPTS',np.dtype('i4').char,('N_PROF'))
     t[:] = NPTS    
     t.long_name = 'Number of Data Levels in Profile'

     t    = ncfile.createVariable('QC_FLAG',np.dtype('i4').char,('N_PROF'))
     t[:] = QC_FLAG    
     t.long_name   = 'QC Profile Flag'
     t.conventions = 'No QC : 0'

     t    = ncfile.createVariable('INST_ID',np.dtype('i4').char,('N_PROF'))
     t[:] = INST_ID   
     t.long_name = 'Instrument Identification Code' 

     t    = ncfile.createVariable('QC_PRF',np.dtype('float32').char,('N_PROF'))
     t[:] = QC_PRF
     t.long_name   = 'Profile Quality Control Flag'
     t.conventions = 'Standard Quality : 1'

     t    = ncfile.createVariable(param.VAR,np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:] = DATA   
     t.units = param.UNITS
     t.long_name     = param.LONG_NAME
     #t.missing_value = np.float32(param.MISSING) #Matt fix
     t.missing_value = param.MISSING

     t    = ncfile.createVariable('OBS_ERROR',np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:] = OBS_ERROR
     t.long_name     = 'Observation Error'
     #t.missing_value = np.float32(param.MISSING)
     t.missing_value = param.MISSING

     t    = ncfile.createVariable('DEPTH',np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:] = DEPTH
     t.units = 'meters'
     t.long_name     = 'Profile Depth'
     #t.missing_value = np.float32(param.MISSING)
     t.missing_value = param.MISSING

     t    = ncfile.createVariable('QC_LEV',np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:] = QC_LEV
     t.long_name   = 'Level Quality Control Flag'
     t.conventions = 'Standard Quality : 1'

     ncfile.close()

########################################################################
def append_nc_2D(fname,param,N_PROF,DATA_ID,DATE_TIME,LON,LAT,NPTS,QC_FLAG,INST_ID,QC_PRF,DATA,OBS_ERROR,DEPTH,QC_LEV):

     ncfile  = Dataset(fname,'a')

     ncfile.history     = 'Updated on '+(time.strftime("%Y%m%d"))

     n_prof0    = ncfile.variables['N_PROF']
     data_id0   = ncfile.variables['DATA_ID']
     date_time0 = ncfile.variables['DATE_TIME']
     lon0       = ncfile.variables['LON']
     lat0       = ncfile.variables['LAT']
     npts0      = ncfile.variables['NPTS']
     qc_flag0   = ncfile.variables['QC_FLAG']
     inst_id0   = ncfile.variables['INST_ID']
     qc_prf0    = ncfile.variables['QC_PRF']
     data0      = ncfile.variables[param.VAR]
     obs_error0 = ncfile.variables['OBS_ERROR']
     depth0     = ncfile.variables['DEPTH']
     qc_lev0    = ncfile.variables['QC_LEV']

     tm0,zm0 = np.shape(data0)  
     tm,zm   = np.shape(DATA)  

     #print '     Existing ',tm0, ' Appending ',tm, np.shape(N_PROF)[0]

     n_prof0[tm0:tm+tm0]    = N_PROF[:]
     data_id0[tm0:tm+tm0]   = DATA_ID[:] 
     date_time0[tm0:tm+tm0] = DATE_TIME[:]
     lon0[tm0:tm+tm0]       = LON[:]
     lat0[tm0:tm+tm0]       = LAT[:]
     npts0[tm0:tm+tm0]      = NPTS[:]
     qc_flag0[tm0:tm+tm0]   = QC_FLAG[:]
     inst_id0[tm0:tm+tm0]   = INST_ID[:]
     qc_prf0[tm0:tm+tm0]    = QC_PRF[:]
     data0[tm0:tm+tm0]      = DATA[:]
     obs_error0[tm0:tm+tm0] = OBS_ERROR[:]
     depth0[tm0:tm+tm0]     = DEPTH[:]
     qc_lev0[tm0:tm+tm0]    = QC_LEV[:]


     ncfile.close()



########################################################################
def write_nc_3D(fname,param,N_PROF,DATA_ID,DATE_TIME,LON,LAT,NPTS,QC_FLAG,INST_ID,QC_PRF,DATA,OBS_ERROR,DEPTH,QC_LEV):

     tm,zm = np.shape(DATA)
     #print 'Write ', tm

     ncfile = Dataset(fname,'w',format='NETCDF3_CLASSIC')

     ncfile.createDimension('N_PROF',None)
     ncfile.createDimension('N_LEVS',zm)
     ncfile.createDimension('SCALAR',1)

     ncfile.title       = param.TITLE
     ncfile.source      = param.SOURCE
     ncfile.history     = 'Updated on '+(time.strftime("%Y%m%d"))
     ncfile.Conventions = 'COARDS'
     ncfile.Version     = 'netcdf-4.0'

     t    = ncfile.createVariable('VAR_ID',np.dtype('i4').char,('SCALAR'))
     t[:] = param.VAR_ID
     t.long_name = 'Variable Identification Code'

     t    = ncfile.createVariable('INST_ERROR',np.dtype('float32').char,('SCALAR'))
     t[:] = param.INST_ERROR
     t.long_name = 'Instrument Error'

     t    = ncfile.createVariable('MISSING',np.dtype('float32').char,('SCALAR'))
     t[:] = param.MISSING
     t.long_name = 'Missing Data Value'

     t    = ncfile.createVariable('N_PROF',np.dtype('double').char,('N_PROF'))
     t[:] = N_PROF

     t    = ncfile.createVariable('DATA_ID',np.dtype('i4').char,('N_PROF'))
     t[:] = DATA_ID
     t.long_name = 'Unique Data Identifier'

     t    = ncfile.createVariable('DATE_TIME',np.dtype('i4').char,('N_PROF'))
     t[:] = DATE_TIME
     t.long_name = 'Date of Observation: YYYYMMDDhh'

     t    = ncfile.createVariable('LON',np.dtype('float32').char,('N_PROF'))
     t[:] = LON
     t.long_name = 'Longitude'
     t.units     = 'degrees-east'

     t    = ncfile.createVariable('LAT',np.dtype('float32').char,('N_PROF'))
     t[:] = LAT
     t.long_name = 'Latitude'
     t.units     = 'degrees-north'

     t    = ncfile.createVariable('NPTS',np.dtype('i4').char,('N_PROF'))
     t[:] = NPTS
     t.long_name = 'Number of Data Levels in Profile'

     t    = ncfile.createVariable('QC_FLAG',np.dtype('i4').char,('N_PROF'))
     t[:] = QC_FLAG
     t.long_name   = 'QC Profile Flag'
     t.conventions = 'No QC : 0'

     t    = ncfile.createVariable('INST_ID',np.dtype('i4').char,('N_PROF'))
     t[:] = INST_ID
     t.long_name = 'Instrument Identification Code'

     t    = ncfile.createVariable('QC_PRF',np.dtype('float32').char,('N_PROF'))
     t[:] = QC_PRF
     t.long_name   = 'Profile Quality Control Flag'
     t.conventions = 'Standard Quality : 1'

     t    = ncfile.createVariable(param.VAR,np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:,:] = DATA
     t.units = param.UNITS
     t.long_name     = param.LONG_NAME
     #t.missing_value = np.float32(param.MISSING) #Matt fix
     t.missing_value = param.MISSING

     t    = ncfile.createVariable('OBS_ERROR',np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:,:] = OBS_ERROR
     t.long_name     = 'Observation Error'
     #t.missing_value = np.float32(param.MISSING)
     t.missing_value = param.MISSING

     t    = ncfile.createVariable('DEPTH',np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:,:] = DEPTH
     t.units = 'meters'
     t.long_name     = 'Profile Depth'
     #t.missing_value = np.float32(param.MISSING)
     t.missing_value = param.MISSING

     t    = ncfile.createVariable('QC_LEV',np.dtype('float32').char,('N_PROF','N_LEVS'))
     t[:,:] = QC_LEV
     t.long_name   = 'Level Quality Control Flag'
     t.conventions = 'Standard Quality : 1'

     ncfile.close()

