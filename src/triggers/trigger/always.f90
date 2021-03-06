module class_trigger_always

  use class_trigger

  private

  type, public, extends(trigger) :: trigger_always
     ! initialization data goes here
     logical :: test_result = .false.
     ! end of initialization data
   contains
     procedure :: info
     procedure :: start
     procedure :: stop
     procedure :: test
     procedure :: init
  end type trigger_always

contains

  function init(this) result(r)
    class(trigger_always) :: this
    logical :: r

    ! call common initialization for triggers
    if( this % trigger % init() ) then
       ! we proceede with trigger-specific initialization. For this
       ! particular trigger there is no data to initialize other than
       ! test_result and name, so we return true
       this % name = "trigger_always"
       r = .true.
    else
       ! if init has failed we return false
       r = .false.
    end if

  end function init

  function start(t) result(r)
    class(trigger_always) :: t
    logical :: r
    r = .true.
  end function start

  function stop(t) result(r)
    class(trigger_always) :: t
    logical :: r
    r = .true.
  end function stop

  function test(t) result(r)
    class(trigger_always), target :: t
    logical :: r
    r = t % test_result
  end function test

  subroutine info(t)
    class(trigger_always) :: t
    print *, "I:trigger%test_result=", t%test_result
  end subroutine info


end module class_trigger_always

