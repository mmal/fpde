program mesh_factory_test

  use mesh_factory
  use class_mesh

  use stepper_factory
  use class_ode_stepper

  class(mesh), pointer :: m
  class(ode_stepper), pointer :: s

  m => mesh_new("sfd3pt")
  if( associated(m) ) then
     m % nx = 10
     m % nf = 10
     m % x1 = 1.
     call m % init
     call m % info
     call m % free
  end if

  m => mesh_new("nmfdsah")
  if( .not. associated(m) ) then
     print *, "m == null()"
  end if

  s => stepper_new("rk4cs")
  call s % init(1)
  print *, s % name

end program mesh_factory_test
