module class_solver_data

  use utils_array_operations

  character(len=30), public, parameter :: &
       solver_started = "started",     &
       solver_stopped = "stopped",     &
       solver_error = "error"


  private

  type, public :: solver_data
     real, pointer                     :: t => null()
     real                              :: dt = 1.e-10
     real                              :: t0 = 0.,t1 = 0.
     real, contiguous, pointer         :: x    (:) => null()
     real, contiguous, pointer         :: f    (:,:) => null()
     real, contiguous, pointer         :: dfdt (:,:) => null()
     real, contiguous, pointer         :: dfdx (:,:,:) => null()
     ! below are pointers to the scalar data defined by a solver and a
     ! user, which are available to modules.
     real, contiguous, pointer         :: data_block (:,:) => null()
     character(len=30), pointer        :: data_block_names (:) => null()
     real, contiguous, pointer         :: data_scalars (:) => null()
     character(len=30), pointer        :: data_scalars_names (:) => null()
     real, contiguous, pointer         :: user_data_scalars (:) => null()
     character(len=30), pointer        :: user_data_scalars_names (:) => null()
     real                              :: x0=0., x1=1.
     integer                           :: nx = 0, nf = 0, rk = 0
     integer                           :: n_iter = 0
     class(*), pointer                 :: params => null()
     character(len=20)                 :: time_started = ""
     ! solver name
     character(len=30)                 :: name = ""
     ! interface supported by any solver
     integer                           :: rhs_status = 0
     character(len=30)                 :: status = "stopped"
   contains
     procedure                         :: calculate_dfdx
     procedure                         :: pointwise_dfdx
     procedure                         :: start
     procedure                         :: set_data_lengths
  end type solver_data

contains

  subroutine calculate_dfdx( s, i )
    class(solver_data) :: s
    integer :: i

    print *, "calculate_dfdx not defined for ", trim(s % name)

  end subroutine calculate_dfdx

  real function pointwise_dfdx( s, i, j, k )
    class(solver_data) :: s
    integer :: i, j, k
    pointwise_dfdx = -1.

    print *, "pointwise_dfdx not defined for ", trim(s % name)

  end function pointwise_dfdx

  !>
  !!
  !! @param s
  !!
  !! @return
  subroutine start(s)
    class(solver_data) :: s

    ! we name the unnamed data_scalars and user_data_scalars using the
    ! names s1,s2, ... and u1,u2, ... respectively
    call fill_data_names(s, var="s", user_var="u")

  end subroutine start

  !> @bug: does not seem to work now
  !!
  !! @param s
  !! @param lds
  !! @param ldsn
  !! @param luds
  !! @param ludsn
  !!
  !! @return
  !!
  subroutine set_data_lengths( s, lds, ldsn, luds, ludsn )
    class(solver_data) :: s
    integer, optional, intent(out) :: lds, ldsn, luds, ludsn
    real, pointer :: scalars(:), u_scalars(:)
    character(len=30), pointer :: names(:), u_names(:)

    scalars   => s % data_scalars
    names     => s % data_scalars_names
    u_scalars => s % user_data_scalars
    u_names   => s % user_data_scalars_names

    if( associated(scalars) ) then
       if(present(lds)) lds=size(scalars)
       if( associated(names) ) then
          if(present(ldsn)) ldsn=size(names)
       else
          if(present(ldsn))ldsn=0
       end if
    else
       if(present(lds))lds=0
       if(present(ldsn))ldsn=0
    end if


    if( associated(u_scalars) ) then
       if(present(luds))luds=size(u_scalars)
       if( associated(u_names) ) then
          if(present(ludsn)) ludsn=size(u_names)
       else
          if(present(ludsn))ludsn=0
       end if
    else
       if(present(luds))luds=0
       if(present(ludsn))ludsn=0
    end if

  end subroutine set_data_lengths

  !>
  !!
  !! @param s
  !! @param var
  !! @param user_var
  !!
  !! @return
  !!
  subroutine fill_data_names( s, var, user_var )
    class(solver_data) :: s
    character(len=*), intent(in) :: var, user_var
    integer :: lds, ldsn, luds, ludsn, i
    character(len=30) :: name

    call s % set_data_lengths( lds, ldsn, luds, ludsn)

    call character_array_realloc(s%data_scalars_names,lds)
    do i = ldsn+1, lds
       write(name,"(a,i1)") trim(var), i
       s % data_scalars_names(i) = name
    end do


    call character_array_realloc(s%user_data_scalars_names,luds)
    do i = ludsn+1, luds
       write(name,"(a,i1)") trim(user_var), i
       s % user_data_scalars_names(i) = name
    end do

  end subroutine fill_data_names



end module class_solver_data
