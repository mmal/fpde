module module_mesh_sfd3pt
  use mesh_module

  ! everything except the type should be private
  private

  type, public, extends( mesh ) :: mesh_sfd3pt
     real :: h
   contains
     ! overloaded procedures go here (if needed)
     procedure :: init
     procedure :: derivative
     procedure :: calculate_derivatives
     ! generic :: init => init_sfd3pt
  end type mesh_sfd3pt

contains

  subroutine init(m, nx, nf, maxrk, xmin, xmax)
    class(mesh_sfd3pt), intent(inout) :: m
    integer, intent(in) :: nx,nf,maxrk
    real, intent(in) :: xmin, xmax
    integer :: i

    call m % mesh % Init( nx, nf, maxrk, xmin, xmax)

    m % h = (xmax-xmin)/(nx-1)

    ! setup a uniform grid
    forall( i = 1:nx )&
         m % x(i) = xmin + (i-1) * m % h

  end subroutine init

  function derivative( m, i, j, k )
    class(mesh_sfd3pt), intent(inout) :: m
    integer, intent(in) :: i,j,k
    real :: derivative

    call m % calculate_derivatives( i )
    derivative = m % df( i, j, k )

  end function derivative

  recursive subroutine calculate_derivatives( m, i )
    class(mesh_sfd3pt), target, intent(inout) :: m
    integer :: i,j,k
    real, pointer :: f(:,:)

    if( m % df_calculated( i ) ) then
       return
    else
       m % df_calculated( i ) = .true.
    end if


    if( i > 1) then
       call m % calculate_derivatives(i-1)
       f => m % df( :, : , i)
    else
       f => m % f
    end if


    forall( j = 1 : m % nf, &
            k = 2 : m % nx - 1 )
       m%df(k,j,i)=(f(k+1,j)-f(k-1,j))/m%h/2.
    end forall

    forall( j = 1 : m % nf )
       m%df(1,   j,i)=(f(2,   j)-f(1,     j))/m%h
       m%df(m%nx,j,i)=(f(m%nx,j)-f(m%nx-1,j))/m%h
    end forall

  end subroutine calculate_derivatives


end module module_mesh_sfd3pt