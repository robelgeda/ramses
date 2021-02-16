! This is a subroutine to compute the boris timestep.
subroutine BorisKick(kick,nn,dt,ctm,ts,b,u,v)
  use amr_parameters
  use hydro_parameters
  implicit none
  integer ::kick ! kick number
  integer ::nn ! number of cells
  real(dp) ::dt ! timestep
  real(dp) ::ctm ! charge-to-mass ratio
  real(dp) ::ts ! stopping time
  real(dp),dimension(1:nvector,1:nvar+3) ::b ! magnetic field components
  real(dp),dimension(1:nvector,1:nvar+3) ::u ! fluid velocity
  real(dp),dimension(1:nvector,1:nvar+3) ::v ! grain velocity
  ! real(dp),dimension(1:nvector,1:nvar+3),save ::vo ! velocity output
  !real(dp),dimension(1:nvector,1:nvar+3),save ::q   ! Primitive variables
  integer ::i ! Just an index
  if (kick==1) then
    do i=1,nn
      v(i,1) = v(i,1) + (2*ctm*dt*(-(b(i,2)*b(i,2)*ctm*dt*v(i,1))&
                + b(i,2)*(b(i,1)*ctm*dt*v(i,2)&
                - 2*v(i,3)) + b(i,3)*(-(b(i,3)*ctm*dt*v(i,1)) + 2*v(i,2)&
                + b(i,1)*ctm*dt*v(i,3))))/(4 +&
                (b(i,1)*b(i,1) + b(i,2)*b(i,2) + b(i,3)*b(i,3))*ctm*ctm*dt*dt)
      v(i,2) = v(i,2) + (2*ctm*dt*(-(b(i,3)*b(i,3)*ctm*dt*v(i,2)) &
                + b(i,1)*(b(i,2)*ctm*dt*v(i,1)&
                - b(i,1)*ctm*dt*v(i,2) + 2*v(i,3)) + b(i,3)*(-2*v(i,1)&
                + b(i,2)*ctm*dt*v(i,3))))/(4&
                + (b(i,1)*b(i,1) + b(i,2)*b(i,2) + b(i,3)*b(i,3))*ctm*ctm*dt*dt)
      v(i,3) = v(i,3) + (2*ctm*dt*(2*b(i,2)*v(i,1) &
                + b(i,1)*b(i,3)*ctm*dt*v(i,1) - 2*b(i,1)*v(i,2)&
                + b(i,2)*b(i,3)*ctm*dt*v(i,2) - (b(i,1)*b(i,1)&
                + b(i,2)*b(i,2))*ctm*dt*v(i,3)))/(4 +&
                (b(i,1)*b(i,1) + b(i,2)*b(i,2) + b(i,3)*b(i,3))*ctm*ctm*dt*dt)
    end do
  else
    do i=1,nn
      v(i,1) = (v(i,1) - 0.5*dt*(ctm*(u(i,2)*b(i,3)-u(i,3)*b(i,2))&
                -u(i,1)/ts))/(1.+0.5*dt/ts)
      v(i,2) = (v(i,2) - 0.5*dt*(ctm*(u(i,3)*b(i,1)-u(i,1)*b(i,3))&
                -u(i,2)/ts))/(1.+0.5*dt/ts)
      v(i,3) = (v(i,3) - 0.5*dt*(ctm*(u(i,1)*b(i,2)-u(i,2)*b(i,1))&
                -u(i,3)/ts))/(1.+0.5*dt/ts)
  end if
end subroutine BorisKick
