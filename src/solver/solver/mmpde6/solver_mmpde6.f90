module class_solver_mmpde6

  use pretty_print

  use class_solver_standard
  use class_solver_data
  use class_solver

  use class_mesh

  use class_ode_marcher
  use class_ode_stepper
  use class_ode_system
  use class_ode_step_control

  use mesh_factory

  use utils_greens

  ! used to initialize mesh points
  use class_solver_simple_data
  use class_solver_simple
  use class_module
  use class_module_print_data
  use class_module_solver_stop
  use class_trigger
  use class_trigger_timed
  use class_trigger_always
  use class_trigger_dfdt_norm
  use class_trigger_f_control

  private

  type, public, extends(solver_standard) :: solver_mmpde6
     ! initialization parameters
     procedure(calculate_monitor_interface), pointer &
          :: calculate_monitor => null()
     procedure(g_interface), pointer :: g => null()
     procedure(initial_interface), pointer, nopass &
          :: initial => null()
   ! end of initialization parameters
     real, pointer :: tau => null()
     ! physical mesh is used to calculate d/dx of f(:,:)
     class(mesh), pointer :: physical => null()
     ! physical2 mesh is used to calculate d/dx of d/dt of f(:,:)
     class(mesh), pointer :: physical2 => null()
     real, contiguous, pointer :: monitor(:) => null()
     ! greens function for -D^2 ( so that G is positive definite )
     real, contiguous, pointer :: greens(:,:) => null()
     ! integer :: total_nf
     ! spacing of the computational mesh
     real :: h = 0.
     real, contiguous, pointer :: temporary(:) => null()

   contains
     procedure :: set_pointers
     ! procedure :: g
     ! procedure :: calculate_monitor
     procedure :: init
     procedure :: calculate_dfdx
     procedure :: solve
     procedure :: free
     procedure :: info
     procedure :: set_dxdt
     procedure :: initialize_mesh
  end type solver_mmpde6

  abstract interface
     subroutine calculate_monitor_interface(s)
       import :: solver_mmpde6
       class(solver_mmpde6) :: s
     end subroutine calculate_monitor_interface

     real function g_interface(s)
       import :: solver_mmpde6
       class(solver_mmpde6) :: s
     end function g_interface

     subroutine initial_interface(x, f, params)
       real, intent(in)   :: x(:)
       real, intent(out)   :: f(:,:)
       class(*), pointer  :: params
     end subroutine initial_interface
  end interface

  public&
       calculate_monitor_interface, &
       g_interface, &
       initial_interface

contains

  !>
  !!
  !! @param s
  !!
  !! @return
  !!
  subroutine init(s)
    class(solver_mmpde6), target :: s
    integer :: nx,nf,rk,total_nf
    real :: xmin,xmax,h
    class(solver), pointer :: initial_solver

    if( trim(s%name) == "" ) then
       s % name = "solver_mmpde6"
    end if


    if( s % rk > 2) then
       print *, "ERROR: ", trim(s%name), ": this sovler works only for 0 < rk < 2, setting rk = 2"
       s % rk = 2
    end if

    if( .not. associated( s % rhs ) ) then
       ! @todo report error
       print *, "ERROR: ", trim(s%name), ": rhs has not been set"
    end if

    if( .not. associated( s % g ) ) then
       ! @todo report error
       print *, "ERROR: ", trim(s%name), ": g has not been set"
    end if

    if( .not. associated( s % calculate_monitor ) ) then
       ! @todo report error
       print *, "ERROR: ", trim(s%name),&
            ": calculate_monitor has not been set"
    end if

    if( .not. associated( s % initial ) ) then
       ! @todo report error
       print *, "ERROR: ", trim(s%name),&
            ": initial has not been set"
    end if

    nx = s % nx
    nf = s % nf
    rk = s % rk
    xmin = s % x0
    xmax = s % x1
    s % h = (s%x1-s%x0)/real(nx-1)
    h = s % h

    ! the length of the y(:) vector, used to initialize
    ! sovler_standard
    s % ny =  nx * (nf + 1) + 1
    s % param_solver => s
    call s % set_rhs_marcher( solver_mmpde6_rhs_for_marcher )

    call s % solver_standard % init

    s % physical => mesh_new("afd5pt")
    s % physical2 => mesh_new("afd5pt")
    ! s % computational => mesh_new("sfd3pt")

    ! physical mesh to hold function values and data points
    call s % physical % init( nx, nf, rk, xmin, xmax )

    ! physical2 mesh is used to calculate d/dx of d/dt of f used for
    ! the dilation transform described by g(). It is required to
    ! calculate only the first spatial derivative at most
    call s % physical2 % init( nx, nf, 1, xmin, xmax)

    ! allocate the memory for computational time
    allocate( s % data_scalars(1) )
    ! set the initial value of computational time
    s % tau => s % data_scalars(1)
    s % tau = 0.

    ! deallocate the memory allocated by meshes
    deallocate( s%physical%f,  s%physical%x )
    deallocate( s%physical2%f, s%physical2%x )

    ! allocate memory for monitor(:)
    allocate( s % monitor( nx ) )
    s % data_block(1:nx,1:1) => s % monitor(1:nx)

    ! allocate temporary table
    allocate( s % temporary( nx ) )

    ! allocate and calculate the greens function
    allocate( s % greens( nx, nx ) )
    call discrete_greens( s % greens, xmax - xmin )

    ! set the appropriate interface pointers to current values
    call s % set_pointers( tau = s % tau, y = s % y )

    ! after setting the pointers set time to t0
    s % t = s % t0

    s % x = [(xmin + (xmax-xmin)*(i-1)*h, i = 1, nx)]

    call s % initialize_mesh

  end subroutine init

  !>
  !! tries to relax a mesh by solving an mmpde6 with constant monitor
  !! function
  !!
  !! @param s
  !!
  !! @return
  !!
  subroutine initialize_mesh(s)
    class(solver_mmpde6), target :: s
    class(solver_simple), pointer :: si
    type(solver_simple_data) :: data
    ! type(module_print_data) :: m
    logical :: r

    data = solver_simple_data( &
         mesh_id = "sfd3pt",   &
         stepper_id = "rkf45",    &
         nx      = s % nx,         &
         nf      = 1,          &
         x0      = 0.,         &
         x1      = 1.,         &
         t0      = 0.,         &
         t1      = 10.,         &
         h0      = 1.e-4,      &
         rhs     = null())           !what does it mean?
    ! @todo any way to squeeze this into initialization expression?
    data % rhs => initial_rhs

    si => data % generate_solver()
    si % params => s

    ! call si % info
    call si % add(&
         module_print_data(file_name = "mmpde/init"), &
         trigger_timed( dt = 1.e-2) )
    ! stop if stationary state reached
    call si % add(&
         module_solver_stop(),&
         trigger_timed( dt = 2.e-2 ), &
         trigger_dfdt_norm( min = 1.e-10 ) )
    ! stop if mesh points are out of control
    call si % add(&
         module_solver_stop(),&
         trigger_timed( dt = 2.e-2 ), &
         trigger_f_control(&
         max = 2.*(s % x1 - s % x0),&
         center = .5*(s % x1 + s % x0)) )

    si % f(:,1) = s % x
    call si % sync_dfdt(si % dydt)
    call si % solve
    call si % free
    s % x = si % f(:,1)
    ! @bug, see initial_rhs()
    call s % initial( s % x, s % f, null() )

  end subroutine initialize_mesh


  !> function calculating the rhs for mesh initialization solver
  !!
  !! @param s solver used to solve the initialization problem
  !!
  !! @return
  !!
  subroutine initial_rhs(s)
    class(solver) :: s

    ! some pointer juggling, we interprete s % params as
    ! solver_mmpde6, so we can use a procedure associated with s %
    ! initial
    select type( s6 => s % params )
    class is( solver_mmpde6 )
       ! s6 % x should now point to the area inside s6 % y, so the
       ! assignment below actually changes s6 % y
       s6 % x = s % f(:,1)
       ! this sets up the values of s % f using a user supplied
       ! subroutine initial we pass s % f(:,1) as the points of the
       ! mesh
       !
       ! important @bug: no parameters are passed, the call should be:
       ! call s6 % initial( s % x, s % f, s6 % params )
       ! but results in a compiler error
       call s6 % initial( s6 % x, s6 % f, null() )
       ! now s % f is set up, so we proceed to calculate the derivatives
       call s6 % calculate_dfdx(2)
       ! now monitor function is being calculated and its values
       ! stored in s6 % monitor(:)
       call s6 % calculate_monitor
       ! we now
       call s6 % set_dxdt( s % dfdt(:,1) )
    class default
       print *, "ERROR: solver_mmpde6: initial_rhs: ",&
            "parameter type mismatch"
    end select

  end subroutine initial_rhs

  !>
  !!
  !! @param s
  !! @param tau
  !! @param y
  !! @param dydt
  !!
  !! @return
  !!
  subroutine set_pointers( s, tau, y, dydt )
    class(solver_mmpde6) :: s
    real, target, optional, intent(in) :: y(:), dydt(:)
    real, target, optional, intent(in) :: tau
    integer :: nx,nf,rk
    nx = s % nx
    nf = s % nf
    rk = s % rk
    ! print *, "DEBUG: solver_mmpde6: set_pointers"

    if( present( tau ) ) then
       s % tau => tau
    end if

    if( present( y ) ) then
       ! f is assigned in the following way
       ! f(:, 1:nf) are, as expected functions introduced by user
       s % x( 1 : nx ) => y( nx * nf + 1 : nx * (nf + 1) )
       s % f( 1 : nx, 1 : nf ) => y( 1 : nx * nf )
       s % t => y( nx * ( nf + 1 ) + 1 )

       ! physical mesh differentiates over physical domain
       s % physical % x( 1 : nx ) => y( nx * nf+ 1 : nx * (nf + 1) )
       s % physical % f( 1 : nx, 1 : nf ) => y( 1 : nx * nf )

       ! we update the physical2 mesh domain (should be the same as
       ! the s % physical mesh domain)
       s % physical2 % x( 1 : nx ) => y( nx * nf + 1 : nx * (nf + 1) )

       ! we also update the interface poitners to the spatial
       ! derivatives
       s % dfdx(1:nx,1:nf,1:rk) => s % physical % df
    end if

    if( present( dydt ) ) then
       ! in rhs we want to set only the actual independent variables
       ! defined by the user, i.e. the incrementation of f(:,1:nx).
       s % dfdt( 1 : nx, 1 : nf ) => dydt( 1 : nx * nf)

       ! physical2 mesh differentiates the dfdt, i.e. dydt
       s % physical2 % f( 1 : nx, 1 : nf ) => dydt( 1 : nx * nf )
    end if

  end subroutine set_pointers


  !>
  !!
  !! @param s
  !! @param i
  !!
  !! @return
  !!
  subroutine calculate_dfdx( s, i )
    class(solver_mmpde6) :: s
    integer :: i
    integer :: j

    ! print *, "DEBUG: solver_mmpde6: calculate_dfdx"

    do j = 1, i
       call s % physical % calculate_derivatives( j )
    end do

  end subroutine calculate_dfdx


  ! dydt's real name should be dydtau, as we calculate here the
  ! temporal derivative over computational time
  subroutine solver_mmpde6_rhs_for_marcher( t, y, dydt, s, status )
    real, intent(in) :: t       !computational time!
    real, pointer, intent(in) :: y(:)    !input data vector
    real, pointer, intent(out) :: dydt(:) !output data vector
    real, pointer    :: m(:), x(:), dxdt(:), dxdt_tmp(:), greens(:,:)
    real, pointer    :: dfdt(:,:), dfdx(:,:,:)
    class(solver_mmpde6) :: s
    integer, optional :: status
    integer :: nx, nf, i, j
    real :: g, epsilon, h


    nx = s % nx
    nf = s % nf
    h  = s % h

    ! initial pointer setup
    call s % set_pointers( tau = t, y = y, dydt = dydt )

    ! temporary pointers, introduced for convenience
    m => s % monitor
    x => y( nx * nf + 1 : nx * (nf + 1) )
    dxdt => dydt( nx * nf + 1 : nx * (nf + 1) )
    dxdt_tmp => s % temporary
    greens => s % greens
    dfdt => s % dfdt
    dfdx => s % dfdx

    ! after setting pointers we calculate the required spatial
    ! derivatives

    call s % calculate_dfdx( s % rk )


    !!!!!!!!!!! calculate d/dt of f and store it in the appropriate
    !!!!!!!!!!! part of dydt

    ! calling rhs after set_pointers sets a part of dydt (see the
    ! definition of set_pointers)
    call s % rhs
    ! after calling rhs dydt( 1 : nx * (total_nf - 2)) is set


    !!!!!!!!!!! now calculate the Sundman transform g()

    ! calculate g right after calling s % rhs, order matters
    g = s % g()

    ! we also set the value of d/datu of t to a trivial 1.
    dydt( nx*nf + 1 ) = 1.


    !!!!!!!!!!! proceed to calculating dx/dt

    ! first calculate the values of the monitor function
    call s % calculate_monitor

    call s % set_dxdt( dxdt )


    ! multiply the dxdt by the greens function
    dxdt_tmp = 0.

    forall( i = 1 : nx )
       dxdt_tmp(i) = dxdt_tmp(i) + sum(dxdt(:)*greens(i,:))
    end forall

    dxdt = 1.e-10/epsilon(g) * dxdt_tmp

    ! @todo add -x_t*f_x to the rhs
    forall( i = 1 : nf )
       dfdt(:,i) = dfdt(:,i) - dxdt(:) * dfdx(:,i,1)
    end forall

    ! now the whole dydt vector should be set up to the almost
    ! appropriate values, all is left is to multiply it by the
    ! dilation g()
    dydt = g * dydt

    do i = 1, 2*nx+1
       ! print n_format(size(dydt),"f10.5"), dydt
       print *, y(i), dydt(i)
    end do
    print *, ""
    print *, ""
    print *, ""


  end subroutine solver_mmpde6_rhs_for_marcher

  !>
  !!
  !! @param s
  !! @param dxdt
  !!
  !! @return
  !!
  subroutine set_dxdt(s, dxdt)
    class(solver_mmpde6) :: s
    real, intent(out) :: dxdt(:)
    real, pointer :: m(:), x(:)
    real :: h
    integer :: nx, i

    ! short names for convenience
    x => s % x
    m => s % monitor
    h  = s % h
    nx = s % nx

    ! than use a symmetric discretization of (m*x_xi)_xi from [Budd and
    ! Williams 2009]
    ! the forall loop should run over all d/dt of x(2:nx-1) values
    ! according to pointer association in set_pointers
    forall( i = 2 : nx - 1 ) &
         dxdt( i ) = ( ( m(i+1) + m(i) ) * ( x(i+1) - x(i) ) &
         -   ( m(i) + m(i-1) ) * ( x(i) - x(i-1))) &
         /(2.*h**2)
    ! the boundary conditions for the mesh are (theese are imposed by
    ! greens function multiplication above, but we emphasize them
    ! here)
    dxdt(  1 ) = 0.
    dxdt( nx ) = 0.

  end subroutine set_dxdt


  !>
  !!
  !! @param g
  !!
  !! @return
  !!
  ! this function was found to be giving best results, see Biernat and
  ! Bizon [2011]
  real function epsilon(g)
    real :: g
    epsilon = 100. * sqrt(g) + .05

  end function epsilon


  !>
  !!
  !! @param s
  !!
  !! @return
  !!
  subroutine solve( s )
    class(solver_mmpde6) :: s

    ! sync pointers
    call s % set_pointers( tau = s % tau, y = s % y )

    call s % start

    ! call the modules
    ! call s % step

    do while( .true. )
    ! do while( s % n_iter < 2 )
       print *, ""
       print *, "####iteration: ", s % n_iter
       print *, s % tau
       call s % marcher % apply( &
            s   = s % stepper,   &
            c   = s % step_control, &
            sys = s % system,    &
            t   = s % tau,         &
            t1  = 1.e10,        & !@bug, constant value
            h   = s % dt,         &
            y   = s % y )
       ! @todo: neater error handling

       if ( s % marcher % status /= 1 ) then
          print *, "marcher error, status=",  s % marcher % status
          ! @todo change exit to an error report
          return
       else

          ! increment the iteration number
          s % n_iter = s % n_iter + 1

          ! sync pointers first
          call s % set_pointers( tau = s % t, y = s % y )

          ! @todo: extra calculation, probably not needed
          call s % rhs

          call s % step

          ! check the status after running triggers
          if( trim(s % status) == "stopped" .or. &
               trim(s % status) == "error" ) then
             return
          end if

       endif
    end do

    call s % stop

  end subroutine solve


  !>
  !!
  !! @param s
  !!
  !! @return
  !!
  ! @todo better free for solver_mmpde6
  subroutine free( s )
    class(solver_mmpde6) :: s

    call s % solver_standard % free

    ! the pointer in the argument below is moved around pretty much
    ! during execution of solve() and should be nullified in order not
    ! to point at some yet to be freed memory area
    call s % physical % free
    call s % stepper % free
    call s % marcher % free

    ! @bug not all of the arrays are freed
    ! deallocate( s % system, s % t, s % dfdt, s % y )
    ! deallocate( s % system, s % t, s % dfdt )

  end subroutine free


  !>
  !!
  !! @param s
  !!
  !! @return
  !!
  subroutine info( s )
    class(solver_mmpde6) :: s

    call s % solver_standard % info

    ! print *, "DEBUG: solver_mmpde6: info"
  end subroutine info


end module class_solver_mmpde6
