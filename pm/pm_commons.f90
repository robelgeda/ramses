module pm_commons

  use amr_parameters
  use pm_parameters
  use random

  implicit none

  ! Sink particle related arrays
  real(dp),allocatable,dimension(:)::msink,c2sink,oksink_new,oksink_all
  real(dp),allocatable,dimension(:)::tsink,tsink_new,tsink_all
  real(dp),allocatable,dimension(:)::msink_new,msink_all
  real(dp),allocatable,dimension(:)::mseed,mseed_new,mseed_all
  real(dp),allocatable,dimension(:)::xmsink
  real(dp),allocatable,dimension(:)::dMsink_overdt,dMBHoverdt
  real(dp),allocatable,dimension(:)::rho_gas,volume_gas,eps_sink
  real(dp),allocatable,dimension(:,:)::vel_gas
  real(dp),allocatable,dimension(:)::delta_mass,delta_mass_new,delta_mass_all
  real(dp),allocatable,dimension(:)::wden,weth,wvol,wdiv,wden_new,weth_new,wvol_new,wdiv_new
  real(dp),allocatable,dimension(:,:)::wmom,wmom_new
  real(dp),allocatable,dimension(:,:)::vsink,vsink_new,vsink_all
  real(dp),allocatable,dimension(:,:)::fsink,fsink_new,fsink_all
  real(dp),allocatable,dimension(:,:,:)::vsnew,vsold
  real(dp),allocatable,dimension(:,:,:)::fsink_partial,sink_jump
  real(dp),allocatable,dimension(:,:)::lsink,lsink_new,lsink_all!sink angular momentum
  real(dp),allocatable,dimension(:,:)::xsink,xsink_new,xsink_all
  real(dp),allocatable,dimension(:,:)::weighted_density,weighted_volume,weighted_ethermal,weighted_divergence
  real(dp),allocatable,dimension(:,:,:)::weighted_momentum
  real(dp),allocatable,dimension(:)::dt_acc                ! maximum timestep allowed by the sink
  real(dp),allocatable,dimension(:)::rho_sink_tff
  integer,allocatable,dimension(:)::idsink,idsink_new,idsink_old,idsink_all
  logical,allocatable,dimension(:,:)::level_sink,level_sink_new
  logical,allocatable,dimension(:)::ok_blast_agn,ok_blast_agn_all,direct_force_sink
  logical,allocatable,dimension(:)::new_born,new_born_all,new_born_new
  integer,allocatable,dimension(:)::idsink_sort
  integer::ncloud_sink,ncloud_sink_massive
  integer::nindsink=0
  integer::sinkint_level=0         ! maximum level currently active is where the global sink variables are updated
  real(dp)::ssoft                  ! sink softening lenght in code units


  ! Particles related arrays
  real(dp),allocatable,dimension(:,:)::xp       ! Positions
  real(dp),allocatable,dimension(:,:)::vp       ! Velocities
  real(dp),allocatable,dimension(:)  ::mp       ! Masses
#ifdef OUTPUT_PARTICLE_POTENTIAL
  real(dp),allocatable,dimension(:)  ::ptcl_phi ! Potential of particle added by AP for output purposes
#endif
  real(dp),allocatable,dimension(:)  ::tp       ! Birth epoch
  real(dp),allocatable,dimension(:,:)::weightp  ! weight of cloud parts for sink accretion only
  real(dp),allocatable,dimension(:)  ::zp       ! Birth metallicity
  integer ,allocatable,dimension(:)  ::nextp    ! Next particle in list
  integer ,allocatable,dimension(:)  ::prevp    ! Previous particle in list
  integer ,allocatable,dimension(:)  ::levelp   ! Current level of particle
  integer(i8b),allocatable,dimension(:)::idp    ! Identity of particle
  ! Tree related arrays
  integer ,allocatable,dimension(:)  ::headp    ! Head particle in grid
  integer ,allocatable,dimension(:)  ::tailp    ! Tail particle in grid
  integer ,allocatable,dimension(:)  ::numbp    ! Number of particles in grid
  ! Global particle linked lists
  integer::headp_free,tailp_free,numbp_free=0,numbp_free_tot=0
  ! Local and current seed for random number generator
  integer,dimension(IRandNumSize) :: localseed=-1

  ! Particle types
  integer, parameter :: NFAMILIES=5
  integer(1),parameter :: FAM_DM=1, FAM_STAR=2, FAM_CLOUD=3, FAM_DEBRIS=4, FAM_OTHER=5, FAM_UNDEF=127
  integer(1),parameter :: FAM_TRACER_GAS=0
  integer(1),parameter :: FAM_TRACER_DM=-1, FAM_TRACER_STAR=-2, FAM_TRACER_CLOUD=-3, FAM_TRACER_DEBRIS=-4, FAM_TRACER_OTHER=-5

  ! Customize here for particle tags within particle types (e.g. different kind of stars).
  ! Note that the type should be integer(1) (1 byte integers) for memory concerns.
  ! Also don't forget to create a function is_<type>_<tag>. See the wiki for a more complete example.
  ! By default, the tag is always 0.

  ! Particle keys for outputing. They should match the above particle
  ! types, except for 'under' family
  character(len=13), dimension(-NFAMILIES:NFAMILIES), parameter :: particle_family_keys = (/ &
       ' other_tracer', 'debris_tracer', ' cloud_tracer', '  star_tracer', ' other_tracer', &
       '   gas_tracer', &
       '           DM', '         star', '        cloud', '       debris', '        other'/)

  type(part_t), allocatable, dimension(:) :: typep  ! Particle type array

contains
  function cross(a,b)
    use amr_parameters, only:dp
    real(dp),dimension(1:3)::a,b
    real(dp),dimension(1:3)::cross
    !computes the cross product c= a x b
    cross(1)=a(2)*b(3)-a(3)*b(2)
    cross(2)=a(3)*b(1)-a(1)*b(3)
    cross(3)=a(1)*b(2)-a(2)*b(1)
  end function cross

  elemental logical pure function is_DM(typep)
    type(part_t), intent(in) :: typep
    is_DM = typep%family == FAM_DM
  end function is_DM

  elemental logical pure function is_star(typep)
    type(part_t), intent(in) :: typep
    is_star = typep%family == FAM_STAR
  end function is_star

  elemental logical pure function is_cloud(typep)
    type(part_t), intent(in) :: typep
    is_cloud = typep%family == FAM_CLOUD
  end function is_cloud

  elemental logical pure function is_debris(typep)
    type(part_t), intent(in) :: typep
    is_debris = typep%family == FAM_DEBRIS
  end function is_debris

  elemental logical pure function is_tracer(typep)
    type(part_t), intent(in) :: typep
    is_tracer = typep%family <= 0
  end function is_tracer

  elemental logical pure function is_not_tracer(typep)
    type(part_t), intent(in) :: typep
    is_not_tracer = typep%family > 0
  end function is_not_tracer

  elemental logical pure function is_not_DM(typep)
    type(part_t), intent(in) :: typep
    is_not_DM = typep%family /= FAM_DM
  end function is_not_DM
  

  elemental function part2int (part)
    ! Convert a particle into an integer
    ! This saves some space e.g. when communicating
    integer :: part2int
    type(part_t), intent(in) :: part

    ! This is the largest value for integer(1)
    integer, parameter :: a = 128, b = 2*a

    part2int = (int(part%family) + a) * b + (int(part%tag) + a)
  end function part2int

  elemental function int2part(index)
    ! Convert from an index to particle type
    type(part_t) :: int2part
    integer, intent(in) :: index

    ! This is the largest value for integer(1)
    integer, parameter :: a = 128, b = 2*a

    int2part%family = int(index / b - a, 1)
    int2part%tag = int(mod(index, b) - a, 1)
  end function int2part
  
  function props2type(idpii, tpii, mpii)
    use amr_commons
    use pm_parameters, only : part_t

    ! Converts from "old" ramses to "new" ramses
    !
    ! Here's the match, add yours here for backward compatibility purposes
    ! DM     tpii == 0
    ! stars  tpii != 0 and idpii > 0
    ! sinks  tpii != 0 and idpii < 0
    !
    ! This is mostly for support of GRAFFIC I/O.
    ! The reason we use idpii instead of idp is to prevent name clashes
    real(dp), intent(in) :: tpii, mpii
    integer, intent(in)  :: idpii

    type(part_t) :: props2type

    if (tpii == 0) then
       props2type%family = FAM_DM
    else if (idpii > 0) then
       props2type%family = FAM_STAR
    else if (idpii < 0) then
       props2type%family = FAM_CLOUD
    else if (mpii == 0) then
       props2type%family = FAM_TRACER_GAS
    end if
    props2type%tag = 0
  end function props2type
end module pm_commons
