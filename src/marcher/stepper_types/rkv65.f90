! Verner 6 (5)
!
! Method also known as DVERK in
! other numerical coedes.
!
module class_ode_stepper_rkv65

   use class_ode_stepper
   use class_ode_system

   private

   type, public, extends( ode_stepper ) :: ode_stepper_rkv65
      ! workspace
      real, pointer, contiguous :: k(:,:), y0(:), ytmp(:)
      !
      real :: c(8)   = [ 0., 1./6., 4./15., 2./3., 5./6., 1., 1./15., 1. ]
      !
      real :: a(8,8) = [ &
           [ 0.,0.,0.,0.,0.,0.,0.,0. ], &
           [ 1./6.,0.,0.,0.,0.,0.,0.,0. ], &
           [ 4./75.,16./75.,0.,0.,0.,0.,0.,0. ], &
           [ 5./6.,-(8./3.),5./2.,0.,0.,0.,0.,0. ], &
           [ -(165./64.),55./6.,-(425./64.),85./96.,0.,0.,0.,0. ], &
           [ 12./5.,-8.,4015./612.,-(11./36.),88./255.,0.,0.,0. ], &
           [ -(8263./15000.),124./75.,-(643./680.),-(81./250.),2484./10625.,0.,0.,0. ], &
           [ 3501./1720., -300./43., 297275./52632., -319./2322., 24068./84065., 0., \
3850./26703., 0. ] &
           ]
      !
      real :: b(8)  = [  3./40., 0., 875./2244., 23./72., 264./1955., 0., 125./11592., 43./616. ]
      !
      real :: ec(8) = [ 1./160., 0., 125./17952., -(1./144.), 12./1955., 3./44., -(125./11592.), -(43./616.) ]

      integer :: stages
   contains
      procedure :: init
      procedure :: apply
      procedure :: reset
      procedure :: free
   end type ode_stepper_rkv65

contains

   subroutine init(s, dim)
      class(ode_stepper_rkv65), intent(inout) :: s
      integer :: dim

      s % dim = dim
      s % can_use_dydt_in = .true.
      s % gives_exact_dydt_out = .true.
      s % gives_estimated_yerr = .true.
      s % method_order = 6
      s % name = "rkv65"
      s % stages = 8
      s % status = 1

      ! allocate workspace vectors
      allocate( s % k( s % stages, dim ) )
      allocate( s % y0( dim ) )
      allocate( s % ytmp( dim ) )
   end subroutine init

   subroutine apply( s, dim, t, h, y, yerr, dydt_in, dydt_out, sys, status )
      class(ode_stepper_rkv65), intent(inout) :: s
      integer, intent(in) :: dim
      real, intent(in)  :: t, h
      real, pointer, intent(inout) :: y(:), yerr(:)
      real, pointer, intent(in)  :: dydt_in(:)
      real, pointer, intent(inout) :: dydt_out(:)
      class(ode_system)  :: sys
      integer, optional :: status

      ! local variables
      integer :: i, j
      real, pointer :: k_ptr(:)

      ! Wykonujemy kopie wektora y na wypadek wystapiena bledow
      ! zwracanych przez funkcje sys % fun (prawej strony rownan).
      ! W przypadku ich wystapienia nalezy przywrocic oryginalna
      ! zawartosc wektora y poprzez: y = s % y0, oraz zwrocic
      ! status.
      s % y0 = y

      ! krok k1

      ! pochodne na wejsciu
      ! sprawdzamy czy metoda moze wykorzystac podane
      ! na wejsciu pochodne
      if ( s % can_use_dydt_in .and. associated(dydt_in) ) then
         ! jesli tak to zapisujemy je do s%k(1,:)
         s % k(1,:) = dydt_in
      else
         ! w przeciwnym wypadku musimy je wyliczyc
         k_ptr => s % k(1,:)
         call sys % fun( t, s % y0, k_ptr, sys % params, sys % status )
         if ( sys % status /= 1 ) then
            s % status = sys % status
            return
         end if
      end if

      do i=2, s % stages

         s % ytmp = y 
         do j=1, i-1
            s % ytmp = s % ytmp + &
                 h * s % a(j,i) * s % k(j,:) ! a(j,i) ze wzgledu na sposob w jaki Fortran
                                             ! przechowywuje w pamieci macierze dwuwymiarowe
         end do

         k_ptr => s % k(i,:)

         call sys % fun( t + (s % c(i))*h, s % ytmp, k_ptr, sys % params, sys % status )
         if ( sys % status /= 1 ) then
            s % status = sys % status
            return
         end if
         
      end do

      ! suma koncowa
      s % ytmp = 0.0
      do i=1, s % stages
         s % ytmp = s%ytmp + s%b(i) * s%k(i,:)
      end do
      y = y + h * s % ytmp

      ! pochodne na wyjsciu
      if ( s % gives_exact_dydt_out .and. associated(dydt_out) ) then
         ! wyliczamy pochodne
         call sys % fun( t+h, y, dydt_out, sys % params, sys % status )
         if ( sys % status /= 1 ) then
            s % status = sys % status
            
            ! poniewaz wektor y zostal juz nadpisany
            ! musimy go odzyskac z kopi zrobionej na
            ! poczaktu subrutyny
            y = s % y0
            return
         end if
      end if

      ! estymowany blad - roznica pomiedzy p-tym a pb-tym rzedem
      yerr = 0.0
      do i=1, s % stages
         yerr = yerr + h * s % ec(i) * s % k(i,:)
      end do

      ! pomyslnie zakonczono subrutyne
      s % status = 1

      k_ptr => null()

   end subroutine apply

   subroutine reset( s )
      class(ode_stepper_rkv65), intent(inout) :: s

      s % k = 0.0
      s % y0 = 0.0
      s % ytmp = 0.0


      s % status = 1
   end subroutine reset

   subroutine free( s )
      class(ode_stepper_rkv65), intent(inout) :: s

      deallocate( s % k )
      deallocate( s % y0 )
      deallocate( s % ytmp )
   end subroutine free

end module class_ode_stepper_rkv65
