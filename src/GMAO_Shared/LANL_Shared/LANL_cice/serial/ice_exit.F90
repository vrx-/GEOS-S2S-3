!=======================================================================
!
!BOP
!
! !MODULE: ice_exit - exit the model
!
! !DESCRIPTION:
!
! Exit the model.
!
! !REVISION HISTORY:
!  SVN:$Id: ice_exit.F90,v 1.1.1.1 2009/06/30 20:22:44 f4mjs Exp $
!
! authors William H. Lipscomb (LANL)
!         Elizabeth C. Hunke (LANL)
! 2006 ECH: separated serial and mpi functionality
!
! !INTERFACE:
!
      module ice_exit
!
! !USES:
!
      use ice_kinds_mod
!
!EOP
!
      implicit none

!=======================================================================

      contains

!=======================================================================
!BOP
!
! !ROUTINE: abort_ice - abort the model
!
! !INTERFACE:
!
      subroutine abort_ice(error_message)
!
! !DESCRIPTION:
!
!  This routine aborts the ice model and prints an error message.
!
! !REVISION HISTORY:
!
! same as module
!
! !USES:
!
      use ice_fileunits
      use ice_communicate
#ifdef CCSM
      use shr_sys_mod
#endif
!
!
! !INPUT/OUTPUT PARAMETERS:
!
      character (len=*), intent(in) :: error_message
!
!EOP
!
#ifdef CCSM
      call shr_sys_abort(error_message)
#else
      write (nu_diag,*) error_message
      call flush_fileunit(nu_diag)
      stop
#endif

      end subroutine abort_ice

!=======================================================================
!BOP
!
! !IROUTINE: end_run - ends run
!
! !INTERFACE:
!
      subroutine end_run
!
! !DESCRIPTION:
!
! Ends parallel run by calling MPI_FINALIZE.
! Does nothing in serial runs.
!
! !REVISION HISTORY:
!
! author: ?
!
! !USES:
!
! !INPUT/OUTPUT PARAMETERS:
!
!
!EOP
!
      end subroutine end_run

!=======================================================================

      end module ice_exit

!=======================================================================
