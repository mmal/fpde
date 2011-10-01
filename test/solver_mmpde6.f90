program test_solver_mmpde6

  use pretty_print

  use class_solver_data
  use class_solver
  use class_solver_standard
  use class_solver_mmpde6

  use class_module
  use class_module_print_data
  use class_trigger
  use class_trigger_timed
  use class_trigger_always

  integer, parameter :: nx = 21
  integer :: i
  real :: pi, h, xi(nx), dxdt(nx)
  real, pointer :: x(:), m(:)
  type(solver_mmpde6) :: s

  s % t0 = 0.
  s % t1 = 1.
  s % nx = nx
  s % nf = 1
  s % rk = 2
  s % stepper_id = "rk4cs"
  s % rhs => my_rhs1
  s % dt = 1.e-5
  s % x0 = 0.
  s % x1 = 1.
  s % calculate_monitor => calculate_monitor
  s % initial => initial
  s % g => g

  h = (1.)/real(nx-1)

  call s % init

  call s % add(&
       module_print_data(file_name = "data/test"),&
       trigger_always(test_result = .true.),&
       trigger_timed(dt=.01))

  call s % solve

contains

  subroutine initial( x, f, params )
    real, intent(in)   :: x(:)
    real, intent(out)   :: f(:,:)
    class(*), pointer  :: params

    pi = acos(-1.)
    f(:,1) = sin(2*pi*x)**4
  end subroutine initial


  subroutine my_rhs1( s )
    class(solver) :: s
    integer :: i

    ! call s % calculate_dfdx( 2 )

    s % dfdt(:,1) = s % dfdx(:,1,2)
    ! s % dfdt(:,2) = s % dfdx(:,1,2)

    s % dfdt(1,:) = 0.
    s % dfdt(s%nx,:) = 0.

  end subroutine my_rhs1

  real function g(s)
    class(solver_mmpde6) :: s
    real :: u_tx_0, u_x_0

    ! @todo physical2 % derivative is not working
    ! ! use the previously calculated value of u_x(x=0)
    ! u_x_0 = s % dfdx(1,1,1)
    ! ! calculate u_xt(x=0)
    ! u_tx_0 = s % physical2 % derivative( 1, 1, 1 )

    ! the value of g is custom suited to the problem
    g = 1. ! (abs(u_x_0) + 1.)/(abs(u_tx_0) + 1.)

  end function g

  subroutine calculate_monitor(s)
    class(solver_mmpde6) :: s
    real, pointer ::  dfdx(:,:,:)

    ! print *, "DEBUG: calculate_monitor"

    dfdx => s % dfdx

    ! M(u) = |f_x| + sqrt(|f_xx|)
    s % monitor(:) = abs(dfdx(:,1,1)) + sqrt(abs(dfdx(:,1,2)))

  end subroutine calculate_monitor



end program test_solver_mmpde6
