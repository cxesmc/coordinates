module grid_to_cdo
    
    use coord_constants 
    use coordinates 

    implicit none 

    public :: grid_cdo_write_desc_short 
    public :: grid_cdo_write_desc_explicit_proj
    public :: grid_cdo_write_desc_explicit_latlon
    public :: grid_cdo_write_desc_via_cdo
    public :: call_system_cdo
contains 
    
    
    subroutine grid_cdo_write_desc_short(grid,fldr)
        ! Write a cdo-compliant grid description file 
        ! based on grid definition 

        implicit none 

        type(grid_class), intent(IN) :: grid    ! Grid definition
        character(len=*), intent(IN) :: fldr    ! File destination

        ! Local variables 
        character(len=512) :: filename 
        integer :: fnum
        character(len=256) :: grid_type 
        character(len=32)  :: xnm, ynm 
        character(len=32)  :: xunits, yunits 
        real(dp) :: phi_proj_orig

        ! Determine grid type to write 
        select case(trim(grid%mtype))

            case("latlon")
            
                grid_type = "lonlat"
                xnm       = "lon"
                ynm       = "lat"
                xunits    = "degrees_east"
                yunits    = "degrees_north" 

            case("polar_stereographic","stereographic")
            
                grid_type = "projection"
                xnm       = "xc" 
                ynm       = "yc" 
                xunits    = trim(grid%units)
                yunits    = trim(grid%units)
                
            case("cartesian")
            
                grid_type = "cartesian"
                xnm       = "xc" 
                ynm       = "yc" 
                xunits    = trim(grid%units)
                yunits    = trim(grid%units)
                
            case DEFAULT 

                grid_type = "generic"
                xnm       = "xc" 
                ynm       = "yc" 
                xunits    = trim(grid%units)
                yunits    = trim(grid%units)
                
        end select

        if (trim(xunits) .eq. "kilometers") xunits = "km"
        if (trim(yunits) .eq. "kilometers") yunits = "km"
        
        ! Generate grid description filename 
        filename = trim(fldr)//"/"//"grid_"//trim(grid%name)//".txt"

        fnum = 98

        open(fnum,file=filename,status='unknown',action='write')

        write(fnum,"(a)")       "gridtype = "//trim(grid_type)
        write(fnum,"(a,i10)")   "gridsize = ", grid%G%nx*grid%G%ny 
        write(fnum,"(a,i10)")   "xsize    = ", grid%G%nx
        write(fnum,"(a,i10)")   "ysize    = ", grid%G%ny
        write(fnum,"(a)")       "xname    = "//trim(xnm)
        write(fnum,"(a)")       "xunits   = "//trim(xunits)
        write(fnum,"(a)")       "yname    = "//trim(ynm)
        write(fnum,"(a)")       "yunits   = "//trim(yunits)
        write(fnum,"(a,f15.6)") "xfirst   = ", grid%G%x(1) 
        write(fnum,"(a,f15.6)") "xinc     = ", grid%G%dx 
        write(fnum,"(a,f15.6)") "yfirst   = ", grid%G%y(1) 
        write(fnum,"(a,f15.6)") "yinc     = ", grid%G%dy 
          
        write(fnum,"(a,a)") "grid_mapping = ","crs"

        ! Add grid attributes depending on grid_mapping type
        select case(trim(grid%mtype))

            case("stereographic")
                ! Including 'oblique_stereographic' 

                write(fnum,"(a,a)")     "grid_mapping_name = ",trim(grid%mtype)
                write(fnum,"(a,f12.3)") "longitude_of_projection_origin = ", grid%proj%lambda 
                write(fnum,"(a,f12.3)") "latitude_of_projection_origin = ", grid%proj%phi 
                write(fnum,"(a,f12.3)") "angle_of_oblique_tangent = ", grid%proj%alpha 
                write(fnum,"(a,f12.3)") "scale_factor_at_projection_origin = ", 1.0d0 
                write(fnum,"(a,f12.3)") "false_easting = ",  0.0d0 
                write(fnum,"(a,f12.3)") "false_northing = ", 0.0d0 
                
                ! Add planet information
                if (grid%planet%is_sphere) then 
                    write(fnum,"(a,f15.8)") "semi_major_axis = ",    grid%planet%a 
                    write(fnum,"(a,f15.8)") "inverse_flattening = ", 0.0d0 
                else 
                    write(fnum,"(a,f15.8)") "semi_major_axis = ",    grid%planet%a 
                    write(fnum,"(a,f15.8)") "inverse_flattening = ", 1.d0/grid%planet%f
                end if 

            case("polar_stereographic")
                
                ! Determine latitude_of_projection_origin, since it must 
                ! be either -90 or +90 for a polar_stereographic projection:
                if (grid%proj%phi .gt. 0.0d0) then 
                    phi_proj_orig = 90.0d0 
                else 
                    phi_proj_orig = -90.0d0 
                end if 


                write(fnum,"(a,a)") "grid_mapping_name = ",trim(grid%mtype)
                write(fnum,"(a,f12.3)") "straight_vertical_longitude_from_pole = ", grid%proj%lambda 
                write(fnum,"(a,f12.3)") "latitude_of_projection_origin = ", phi_proj_orig
                write(fnum,"(a,f12.3)") "standard_parallel = ", grid%proj%phi 
                write(fnum,"(a,f12.3)") "false_easting = ",  0.0d0 
                write(fnum,"(a,f12.3)") "false_northing = ", 0.0d0 
                
                ! Add planet information
                if (grid%planet%is_sphere) then 
                    write(fnum,"(a,f15.8)") "semi_major_axis = ",    grid%planet%a 
                    write(fnum,"(a,f15.8)") "inverse_flattening = ", 0.0d0 
                else 
                    write(fnum,"(a,f15.8)") "semi_major_axis = ",    grid%planet%a 
                    write(fnum,"(a,f15.8)") "inverse_flattening = ", 1.d0/grid%planet%f
                end if 

            case("latlon")
                
                write(fnum,"(a,a)") "grid_mapping_name = ", "latitude_longitude"
                
                ! Add planet information
                if (grid%planet%is_sphere) then 
                    write(fnum,"(a,f15.8)") "semi_major_axis = ",    grid%planet%a 
                    write(fnum,"(a,f15.8)") "inverse_flattening = ", 0.0d0 
                else 
                    write(fnum,"(a,f15.8)") "semi_major_axis = ",    grid%planet%a 
                    write(fnum,"(a,f15.8)") "inverse_flattening = ", 1.d0/grid%planet%f
                end if 

                ! == No additional parameters needed == 
                
            case DEFAULT
                ! Do nothing

        end select

        ! Close the text file
        close(fnum)

        return 

    end subroutine grid_cdo_write_desc_short
    
    subroutine grid_cdo_write_desc_explicit_proj(lon2D,lat2D,grid_name,fldr,grid_type)

        implicit none 

        real(4), intent(IN) :: lon2D(:,:) 
        real(4), intent(IN) :: lat2D(:,:) 
        character(len=*), intent(IN) :: grid_name
        character(len=*), intent(IN) :: fldr 
        character(len=*), intent(IN), optional :: grid_type 

        ! Local variables 
        integer :: i, j, nx, ny 
        integer :: im1, jm1, ip1, jp1 
        integer :: fnum
        real(4) :: bnds(4) 
        character(len=512) :: filename 
        character(len=56)  :: grid_type_str 

        ! Generate grid description filename 
        filename = trim(fldr)//"/"//"grid_"//trim(grid_name)//".txt"

        grid_type_str = "curvilinear"
        if (present(grid_type)) grid_type_str = trim(grid_type)

        fnum = 98 

        nx = size(lon2D,1)
        ny = size(lon2D,2)

        open(fnum,file=filename,status='unknown',action='write')

        write(fnum,"(a,a)")   "gridtype = ",trim(grid_type_str)
        write(fnum,"(a,i10)") "gridsize = ", nx*ny 
        write(fnum,"(a,i10)") "xsize    = ", nx
        write(fnum,"(a,i10)") "ysize    = ", ny

        ! x values 
        write(fnum,*) ""
        write(fnum,"(a)") "# Longitudes"
        write(fnum,"(a)") "xvals = "
        do j = 1, ny 
            write(fnum,"(50000f10.3)") lon2D(:,j)
        end do 

        write(fnum,*) ""
        write(fnum,"(a)") "# Longitudes of cell corners"
        write(fnum,"(a)") "xbounds = "
        do j = 1, ny 
        do i = 1, nx 

            im1 = max(1,i-1)
            jm1 = max(1,j-1)
            ip1 = min(nx,i+1)
            jp1 = min(ny,j+1)

            ! Determine bounds (lower-right, upper-right, upper-left, lower-left)
            ! ie, get ab-nodes from aa-nodes
            bnds(1) = 0.25*(lon2D(i,j)+lon2D(ip1,j)+lon2D(i,jm1)+lon2D(ip1,jm1))
            bnds(2) = 0.25*(lon2D(i,j)+lon2D(ip1,j)+lon2D(i,jp1)+lon2D(ip1,jp1))
            bnds(3) = 0.25*(lon2D(i,j)+lon2D(im1,j)+lon2D(i,jp1)+lon2D(im1,jp1))
            bnds(4) = 0.25*(lon2D(i,j)+lon2D(im1,j)+lon2D(i,jm1)+lon2D(im1,jm1))
            
            write(fnum,"(4f10.3)") bnds 

        end do 
        end do 

        ! y values 
        write(fnum,*) ""
        write(fnum,"(a)") "# Latitudes"
        write(fnum,"(a)") "yvals = "
        do j = 1, ny 
            write(fnum,"(50000f10.3)") lat2D(:,j)
        end do 

        write(fnum,*) ""
        write(fnum,"(a)") "# Latitudes of cell corners"
        write(fnum,"(a)") "ybounds = "
        do j = 1, ny 
        do i = 1, nx 

            im1 = max(1,i-1)
            jm1 = max(1,j-1)
            ip1 = min(nx,i+1)
            jp1 = min(ny,j+1)

            ! Determine bounds (lower-right, upper-right, upper-left, lower-left)
            ! ie, get ab-nodes from aa-nodes
            bnds(1) = 0.25*(lat2D(i,j)+lat2D(ip1,j)+lat2D(i,jm1)+lat2D(ip1,jm1))
            bnds(2) = 0.25*(lat2D(i,j)+lat2D(ip1,j)+lat2D(i,jp1)+lat2D(ip1,jp1))
            bnds(3) = 0.25*(lat2D(i,j)+lat2D(im1,j)+lat2D(i,jp1)+lat2D(im1,jp1))
            bnds(4) = 0.25*(lat2D(i,j)+lat2D(im1,j)+lat2D(i,jm1)+lat2D(im1,jm1))
            
            write(fnum,"(4f10.3)") bnds 

        end do 
        end do 

        close(fnum)

        return 

    end subroutine grid_cdo_write_desc_explicit_proj

    subroutine grid_cdo_write_desc_explicit_latlon(lon,lat,grid_name,fldr,wraplon)

        implicit none 

        real(4), intent(IN) :: lon(:) 
        real(4), intent(IN) :: lat(:) 
        character(len=*), intent(IN) :: grid_name
        character(len=*), intent(IN) :: fldr  
        logical,          intent(IN) :: wraplon 

        ! Local variables 
        integer :: i, j, nx, ny 
        integer :: im1, jm1, ip1, jp1 
        integer :: fnum
        real(4) :: bnds(4) 
        character(len=512) :: filename 
        character(len=56)  :: grid_type_str 
        real(4), allocatable :: lon2D(:,:) 
        real(4), allocatable :: lat2D(:,:) 


        nx = size(lon,1)
        ny = size(lat,1)
    
        allocate(lon2D(nx,ny))
        allocate(lat2D(nx,ny))

        call gen_latlon2D(lon2D,lat2D,lon,lat)

        grid_type_str = "lonlat"

        if (wraplon) then 
            write(*,*) "grid_cdo_write_desc_explicit_latlon:: &
                       &wraplon is currently broken. If this grid descrition &
                       &routine is used, and lon=0deg exists in the grid, &
                       &the mapping may produce missing values around lon=0deg. &
                       &wraplon was intended to address this, but is not successful so far. &
                       &When used, all the rest of the cells are missing and the cells &
                       &with lon=0deg are filled in. Needs improvement, don't use."
            stop 
        end if 
        
        ! Generate grid description filename 
        filename = trim(fldr)//"/"//"grid_"//trim(grid_name)//".txt"

        fnum = 98 

        open(fnum,file=filename,status='unknown',action='write')

        write(fnum,"(a,a)")   "gridtype = ",trim(grid_type_str)
        write(fnum,"(a,i10)") "gridsize = ", nx*ny 
        write(fnum,"(a,i10)") "xsize    = ", nx
        write(fnum,"(a,i10)") "ysize    = ", ny

        ! x values 
        write(fnum,*) ""
        write(fnum,"(a)") "# Longitudes"
        write(fnum,"(a)") "xvals = "
        write(fnum,"(50000f10.3)") lon

        write(fnum,*) ""
        write(fnum,"(a)") "# Longitudes of cell corners"
        write(fnum,"(a)") "xbounds = "
        !do j = 1, ny 
        do i = 1, nx 

            im1 = max(1,i-1)
            jm1 = max(1,j-1)
            ip1 = min(nx,i+1)
            jp1 = min(ny,j+1)

            if (i .eq. 1 .and. wraplon) im1  = nx 
            if (i .eq. nx .and. wraplon) ip1 = 1 

            ! Determine bounds (lower-right, upper-right, upper-left, lower-left)
            ! ie, get ab-nodes from aa-nodes
            ! bnds(1) = 0.25*(lon2D(i,j)+lon2D(ip1,j)+lon2D(i,jm1)+lon2D(ip1,jm1))
            ! bnds(2) = 0.25*(lon2D(i,j)+lon2D(ip1,j)+lon2D(i,jp1)+lon2D(ip1,jp1))
            ! bnds(3) = 0.25*(lon2D(i,j)+lon2D(im1,j)+lon2D(i,jp1)+lon2D(im1,jp1))
            ! bnds(4) = 0.25*(lon2D(i,j)+lon2D(im1,j)+lon2D(i,jm1)+lon2D(im1,jm1))
            
            bnds(1) = 0.5*(lon(i)+lon(ip1))
            bnds(2) = 0.5*(lon(im1)+lon(i))

            if (i .eq. 1 .and. wraplon) then 
                bnds(2) = 0.5*((lon(im1)-360.0)+lon(i))
            end if 

            if (i .eq. nx .and. wraplon) then 
                bnds(1) = 0.5*((lon(i)-360.0)+lon(ip1))
            end if 

            write(fnum,"(2f10.3)") bnds(1:2)

        end do 
        !end do 

        ! y values 
        write(fnum,*) ""
        write(fnum,"(a)") "# Latitudes"
        write(fnum,"(a)") "yvals = "
        write(fnum,"(50000f10.3)") lat

        write(fnum,*) ""
        write(fnum,"(a)") "# Latitudes of cell corners"
        write(fnum,"(a)") "ybounds = "
        do j = 1, ny 
        !do i = 1, nx 

            im1 = max(1,i-1)
            jm1 = max(1,j-1)
            ip1 = min(nx,i+1)
            jp1 = min(ny,j+1)

            ! Determine bounds (lower-right, upper-right, upper-left, lower-left)
            ! ie, get ab-nodes from aa-nodes
            ! bnds(1) = 0.25*(lat2D(i,j)+lat2D(ip1,j)+lat2D(i,jm1)+lat2D(ip1,jm1))
            ! bnds(2) = 0.25*(lat2D(i,j)+lat2D(ip1,j)+lat2D(i,jp1)+lat2D(ip1,jp1))
            ! bnds(3) = 0.25*(lat2D(i,j)+lat2D(im1,j)+lat2D(i,jp1)+lat2D(im1,jp1))
            ! bnds(4) = 0.25*(lat2D(i,j)+lat2D(im1,j)+lat2D(i,jm1)+lat2D(im1,jm1))
            
            bnds(1) = 0.5*(lat(j)+lat(jp1))
            bnds(2) = 0.5*(lat(jm1)+lat(j))

            write(fnum,"(2f10.3)") bnds(1:2)

        !end do 
        end do 

        close(fnum)

        return 

    end subroutine grid_cdo_write_desc_explicit_latlon

    subroutine grid_cdo_write_desc_via_cdo(grid_name,fldr,file_nc)
        ! Write a cdo-compliant grid description file 
        ! based on grid definition using cdo call 

        implicit none 

        character(len=*), intent(IN) :: grid_name   ! Name of grid to be described
        character(len=*), intent(IN) :: fldr        ! File destination
        character(len=*), intent(IN) :: file_nc     ! Netcdf file with grid definition


        ! Local variables 
        character(len=512)  :: file_grid_desc
        character(len=2048) :: cdo_cmd
        logical :: map_exists  
        logical :: cdo_success 

        ! Determine whether map file should be loaded if available 
        ! Step 1: call cdo to generate mapping weights in a scrip file 

        ! Generate grid description filename
        file_grid_desc = trim(fldr)//"/"//"grid_"//trim(grid_name)//".txt"

        ! Define cdo command to generate griddes file from src grid (fnm1) 
        cdo_cmd = "cdo griddes "//trim(file_nc)//" > "//trim(file_grid_desc)

        ! Call cdo command via system call
        call call_system_cdo(cdo_cmd)

        return 

    end subroutine grid_cdo_write_desc_via_cdo

    subroutine gen_grid_file(src_nc,src_var,grid_name,fldr)
        ! Use cdo to generate a clean netcdf file with one variable 
        ! defined on a grid of interest, which can be used to
        ! create a grid description file later via `cdo griddes` 

        implicit none 

        character(len=*), intent(IN) :: src_nc 
        character(len=*), intent(IN) :: src_var 
        character(len=*), intent(IN) :: grid_name 
        character(len=*), intent(IN) :: fldr 

        ! Local variables 
        character(len=512)  :: filename
        character(len=1024) :: cdo_cmd 

        ! Create output filename 
        filename = trim(fldr)//"/grid_"//trim(grid_name)//".nc"

        ! Define cdo command to extract variable into a new file 
        ! cdo command output is redirected to a file '.tmpcdoout'.
        cdo_cmd = "cdo selvar,"//trim(src_var)//" "//trim(src_nc)// &
                " "//trim(filename)

        ! Call cdo command via system call
        call call_system_cdo(cdo_cmd)
        
        return 

    end subroutine gen_grid_file

    subroutine call_system_cdo(cdo_cmd)

        implicit none 

        character(len=*), intent(IN) :: cdo_cmd 

        ! Local variables 
        character(len=2048) :: cdo_cmd_ext 
        character(len=56) :: cdo_output_file 
        character(len=2048) :: str_now 
        integer :: i, fnum, io, aborted
        logical :: cdo_success 

        ! Define diagnostic output filename
        cdo_output_file = ".tmpcdoout"

        ! Add the diagnostic output filename to the command to be called
        cdo_cmd_ext = trim(cdo_cmd)//" &> "//trim(cdo_output_file)

        write(*,*) "cdo command: "
        write(*,*) trim(cdo_cmd_ext) 

        write(*,"(a)",advance='no') "Calling via system call... "
        call system(cdo_cmd_ext)
        write(*,*) "done." 

        ! Check if scrip weights file was written 
        !inquire(file=trim(fnm_map),exist=cdo_success)

        ! ===================================================
        ! Check to see if 'Abort' was called by cdo: 
        fnum = 99
        open(fnum,file=cdo_output_file,status='old',action='read')

        do i = 1, 10000
            read(fnum,"(a10000)",iostat=io) str_now
            aborted = index(str_now,"Abort")
            if (io .lt. 0 .or. aborted .gt. 0) exit 
        end do 
        close(fnum)
        ! ===================================================
        
        cdo_success = .TRUE. 
        if (aborted .gt. 0) cdo_success = .FALSE. 

        if (.not. cdo_success) then 
            write(*,*) 
            write(*,*) "call_system_cdo:: Error: cdo call was aborted due to an error. &
            & Check the cdo log file: .tmpcdoout"
            write(*,*) 
            stop 
        end if 

        return 

    end subroutine call_system_cdo

    subroutine gen_latlon2D(lon2D,lat2D,lon,lat)

        implicit none 

        real(4), intent(OUT) :: lon2D(:,:) 
        real(4), intent(OUT) :: lat2D(:,:) 
        real(4), intent(IN)  :: lon(:) 
        real(4), intent(IN)  :: lat(:) 

        ! Local variables 
        integer :: i, j, nx, ny 

        nx = size(lon,1)
        ny = size(lat,1)

        do j = 1, ny 
            lon2D(:,j) = lon 
        end do 

        do i = 1, nx 
            lat2D(i,:) = lat 
        end do 

        return 

    end subroutine gen_latlon2D

end module grid_to_cdo