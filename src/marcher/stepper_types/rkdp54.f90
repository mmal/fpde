! Domand-Prince 5(4)
! @todo referencje
module class_ode_stepper_rkpd54

   use class_ode_stepper
   use class_ode_system

   private

   type, public, extends( ode_stepper ) :: ode_stepper_rkpd54
      ! workspace
      real, pointer, contiguous :: k1(:), k2(:), k3(:), k4(:), k5(:), k6(:), k7(:), y0(:), ytmp(:), yerr1(:)
      !
      real :: c(7) = (/ 0.0, 1.0/5.0, 3.0/10.0, 4.0/5.0, 8.0/9.0, 1.0, 1.0 /)

      real :: a2(1) = (/ 1.0/5.0 /)
      real :: a3(2) = (/ 3.0/40.0, 9.0/40.0 /)
      real :: a4(3) = (/ 44.0/45.0, -56.0/15.0, 32.0/9.0 /)
      real :: a5(4) = (/ 19372.0/6561.0, -25360.0/2187.0, 64448.0/6561.0, -212.0/729.0 /)
      real :: a6(5) = (/ 9017.0/3168.0, -355.0/33.0, 46732.0/5247.0, 49.0/176.0, -5103.0/18656.0 /)
      real :: a7(6) = (/ 35.0/384.0, 0.0, 500.0/1113.0, 125.0/192.0, -2187.0/6784.0, 11.0/84.0 /)

      real :: b(7) = (/ 35.0/384.0, 0.0, 500.0/1113.0, 125.0/192.0, -2187.0/6784.0, 11.0/84.0, 0.0 /)

      real :: ec(7) = (/  -71.0/57600.0, 0.0, 71.0/16695.0, -71.0/1920.0, 17253.0/339200.0, -22.0/525.0, 1.0/40.0 /)

      ! automatic stiff detection constants
      real :: d(6) = (/ -0.08536, 0.088, -0.0096, 0.0052, 0.00576, -0.004 /)
      real :: r0 = 3.3, t1_tol = 1.0, t2_tol = 0.7
      real :: stiff_t1, stiff_t2
      integer :: stiff_n
      logical :: stiff_last

   contains
      procedure :: init
      procedure :: apply
      procedure :: reset
      procedure :: free
   end type ode_stepper_rkpd54

contains

   subroutine init(s, dim)
      class(ode_stepper_rkpd54), intent(inout) :: s
      integer :: dim

      s % dim = dim
      s % can_use_dydt_in = .true.
      s % gives_exact_dydt_out = .true.
      s % gives_estimated_yerr = .true. ! @todo
      s % method_order = 4
      s % name = "rkpd54"
      s % status = 1

      s % test_for_stiffness = .false. ! by default do not detect stiffness
      s % stiff_status = .false. ! by default, at start, IVP is not stiff
      s % stiff_n = 0
      s % stiff_last = .false.

      ! allocate workspace vectors
      allocate( s % k1( dim ) )
      allocate( s % k2( dim ) )
      allocate( s % k3( dim ) )
      allocate( s % k4( dim ) )
      allocate( s % k5( dim ) )
      allocate( s % k6( dim ) )
      allocate( s % k7( dim ) )
      allocate( s % y0( dim ) )
      allocate( s % ytmp( dim ) )
      allocate( s % yerr1( dim ) )
   end subroutine init

   subroutine apply( s, dim, t, h, y, yerr, dydt_in, dydt_out, sys, status )
      class(ode_stepper_rkpd54), intent(inout) :: s
      integer, intent(in) :: dim
      real, intent(in)  :: t, h
      real, pointer, intent(inout) :: y(:), yerr(:)
      real, pointer, intent(in)  :: dydt_in(:)
      real, pointer, intent(inout) :: dydt_out(:)
      class(ode_system)  :: sys

      integer, optional :: status

      ! Wykonujemy kopie wektora y na wypadek wystapiena bledow
      ! zwracanych przez funkcje sys % fun (prawej strony rownan).
      ! W przypadku ich wystapienia nalezy przywrocic oryginalna
      ! zawartosc wektora y poprzez: y = s % y0, oraz zwrocic
      ! status.
      s % y0 = y

      ! @todo sprawdznie czy zostal podane pochodne wejsciowe
      ! if ( dydt_in /= null() ) then
      !    ! wykorzystujemy juz wyliczone pochodne,
      !    ! kopiujemy je do s%k
      !    s % k = dydt_in
      ! else
      !    ! wyliczamy pochodne
      !    call sys % fun( t, s % y0, s % k, sys % params )
      ! end if


      ! krok k1

      ! pochodne na wejsciu
      ! @todo narazie zakladam ze jezel s % can_use_dydt_in == .true.
      ! to pochodne musza zostac podane na wejsciu
      if ( s % can_use_dydt_in ) then
         ! wykorzystujemy juz wyliczone pochodne,
         ! kopiujemy je do s%k1
         s % k1 = dydt_in
      else
         ! wyliczamy pochodne
         call sys % fun( t, s % y0, s % k1, sys % params, sys % status )
         if ( sys % status /= 1 ) then
            s % status = sys % status
            return
         end if
      end if


      ! krok k2
      s % ytmp = y + h*(s % a2(1))*(s % k1)
      call sys % fun( t + (s % c(2))*h, s % ytmp, s % k2, sys % params, sys % status )
      if ( sys % status /= 1 ) then
         s % status = sys % status
         return
      end if

      ! krok k3
      s % ytmp = y + h*( (s % a3(1) * s % k1) + (s % a3(2) * s % k2) )
      call sys % fun( t + (s % c(3))*h, s % ytmp, s % k3, sys % params, sys % status )
      if ( sys % status /= 1 ) then
         s % status = sys % status
         return
      end if

      ! krok k4
      s % ytmp = y + h*( (s % a4(1) * s % k1) + (s % a4(2) * s % k2) + (s % a4(3) * s % k3))
      call sys % fun( t + (s % c(4))*h, s % ytmp, s % k4, sys % params, sys % status )
      if ( sys % status /= 1 ) then
         s % status = sys % status
         return
      end if


      ! krok k5
      s % ytmp = y + h*( (s % a5(1) * s % k1) + (s % a5(2) * s % k2) + (s % a5(3) * s % k3) + (s % a5(4) * s % k4))
      call sys % fun( t + (s % c(5))*h, s % ytmp, s % k5, sys % params, sys % status )
      if ( sys % status /= 1 ) then
         s % status = sys % status
         return
      end if

      ! krok k6
      s % ytmp = y + h*( (s % a6(1) * s % k1) + (s % a6(2) * s % k2) + (s % a6(3) * s % k3) + (s % a6(4) * s % k4) &
           + (s % a6(5) * s % k5))
      call sys % fun( t + (s % c(6))*h, s % ytmp, s % k6, sys % params, sys % status )
      if ( sys % status /= 1 ) then
         s % status = sys % status
         return
      end if

      ! krok k7 i suma koncowa
      s % ytmp = y + h*( (s % a7(1) * s % k1) + (s % a7(2) * s % k2) + (s % a7(3) * s % k3) + (s % a7(4) * s % k4) &
           + (s % a7(5) * s % k5) + (s % a7(6) * s % k6))
      call sys % fun( t + (s % c(7))*h, s % ytmp, s % k7, sys % params, sys % status )
      if ( sys % status /= 1 ) then
         s % status = sys % status
         return
      end if

      ! suma koncowa
      s % ytmp = s%b(1) * s%k1 + s%b(2) * s%k2 + s%b(3) * s%k3 + &
              s%b(4) * s%k4 + s%b(5) * s%k5 + s%b(6) * s%k6 + s%b(7) * s%k7
      y = y + h * s % ytmp

      ! pochodne na wyjsciu

      ! @todo narazie zakladam ze jezel s % gives_exact_dydt_out == .true.
      ! to pochodne musza zostac podane na wejsciu
      if ( s % gives_exact_dydt_out ) then
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
      yerr = h * ( s%ec(1) * s%k1 + s%ec(2) * s%k2 + s%ec(3) * s%k3 &
           + s%ec(4) * s%k4 + s%ec(5) * s%k5 + s%ec(6) * s%k6 + s%ec(7) * s%k7)

      ! if the user wants to detect stiffness
      if ( s % test_for_stiffness ) then
         s % yerr1 = h * ( s%d(1) * s%k1 + s%d(2) * s%k2 + s%d(3) * s%k3 &
              + s%d(4) * s%k4 + s%d(5) * s%k5 + s%d(6) * s%k6 )
         
         s % stiff_t1 = norm2( s % yerr1 ) / norm2( yerr )

         s % yerr1 = h * ( (s%a7(1)-s%a6(1))*s%k1 + (s%a7(2)-s%a6(2))*s%k2 + &
              (s%a7(3)-s%a6(3))*s%k3 + (s%a7(4)-s%a6(4))*s%k4 + &
              (s%a7(5)-s%a6(5))*s%k5 + s%a7(6)*s%k6 )

         s % stiff_t2 = h * norm2( s % k7 - s % k6 )/norm2( s % yerr1 )/s % r0

         ! print '(E13.6,E13.6,E13.6,E13.6)', t, s % stiff_t1, s % stiff_t2

         ! test if stiff_t1 and stiff_t2 are out of the bounds
         if ( s % stiff_t1 .lt. s % t1_tol .and. s % stiff_t2 .gt. s % t2_tol ) then
            ! the problem is expected to be stiff
            if ( s % stiff_last ) then
               s % stiff_n = s % stiff_n + 1
            else
               s % stiff_n = 1
               s % stiff_last = .true.
            end if

            if ( s % stiff_n .ge. 16 ) then
               ! the problem is classified as stiff
               s % stiff_status = .true.
            end if
         end if

      end if
      ! pomyslnie zakonczono subrutyne
      s % status = 1

   end subroutine apply

   subroutine reset( s )
      class(ode_stepper_rkpd54), intent(inout) :: s

      s % k1 = 0.0
      s % k2 = 0.0
      s % k3 = 0.0
      s % k4 = 0.0
      s % k5 = 0.0
      s % k6 = 0.0
      s % k7 = 0.0
      s % y0 = 0.0
      s % ytmp = 0.0
      s % yerr1 = 0.0

      s % stiff_status = .false.
      s % stiff_n = 0
      s % stiff_last = .false.

      s % status = 1
   end subroutine reset

   subroutine free( s )
      class(ode_stepper_rkpd54), intent(inout) :: s

      deallocate( s % k1 )
      deallocate( s % k2 )
      deallocate( s % k3 )
      deallocate( s % k4 )
      deallocate( s % k5 )
      deallocate( s % k6 )
      deallocate( s % k7 )
      deallocate( s % y0 )
      deallocate( s % ytmp )
      deallocate( s % yerr1 )
   end subroutine free

end module class_ode_stepper_rkpd54
