#!/usr/bin/perl

#########################################################################################################
#													#
#	orb_elm_get_orb.perl: collect all orbital information from archived data and create ascii tables#
#													#
#		author: t. isobe (tisobe@cfa.harvard.edu)						#
#		last update: Jan 20, 2005								#
#													#
#########################################################################################################

#
#--- create a temporary directory and a parameter directory
#

$alist = `ls -d *`;
@dlist = split(/\s+/, $alist);

OUTER:
foreach $dir (@dlist){
        if($dir =~ /param/){
                system("rm ./param/*");
                last OUTER;
        }
}

system('mkdir ./param');

OUTER:
foreach $dir (@dlist){
        if($dir =~ /Temp/){
                system("rm ./Temp/*");
                last OUTER;
        }
}

system('mkdir ./Temp');
system('mkdir ./Temp/Orbit');
system('mkdir ./Temp/Angle');

#
#--- read the list of previously read files, and save the name of the last file
#--- we need to recompute the last one, just in a case, a new data are added on to it
#

$list = `ls -rt /data/mta/Script/Orbital/Orb/*`;
@a_list = split(/\s+/, $list);
$last_time = pop(@a_list);
@atemp = split(/data_/, $last_time);
$last_time = $atemp[1];

#
#--- change sec from 1998.1.1 to year and y-date
#

$in_temp = `axTime3 $last_time u s t d`;


@atemp = split(/:/, $in_temp);
$year = $atemp[0];
$yday = $atemp[1];

#
#---- change y-date to month and date, ignore leap year correction
#

if($yday < 32){
	$month = '01';
	$mday  = $yday;
}elsif($yday < 61){
	$month = '02';
	$mday  = $yday - 31;
}elsif($yday < 92){
	$month = '03';
	$mday  = $yday - 60;
}elsif($yday < 122){
	$month = '04';
	$mday  = $yday - 91;
}elsif($yday < 153){
	$month = '05';
	$mday  = $yday - 121;
}elsif($yday < 183){
	$month = '06';
	$mday  = $yday - 152;
}elsif($yday < 214){
	$month = '07';
	$mday  = $yday - 182;
}elsif($yday < 245){
	$month = '08';
	$mday  = $yday - 213;
}elsif($yday < 275){
	$month = '09';
	$mday  = $yday - 245;
}elsif($yday < 306){
	$month = '10';
	$mday  = $yday - 274;
}elsif($yday < 336){
	$month = '11';
	$mday  = $yday - 305;
}else{
	$month = '12';
	$mday  = $yday - 335;
}

#
#---- find today's date
#

($usec, $umin, $uhour, $umday, $umon, $uyear, $uwday, $uyday, $uisdst)= localtime(time);

$uyear += 1900;
$umon++;
$umday++;

#
#---- read user/passward
#

open(IN, "/data/mta4/MTA/data/.hakama");
while(<IN>){
       	chomp $_;
       	$hakama = $_;
       	$hakama =~ s/\s+//g;
}
close(IN);

open(IN, '/data/mta4/MTA/data/.dare');
while(<IN>){
       	chomp $_;
       	$dare = $_;
       	$dare =~ s/\s+//g;
}
close(IN);

$f_start = "$year/$month/$mday,00:00:00";
$f_end   = "$uyear/$umon/$umday,00:00:00";

#
#---- get a list of orbitephem files
#

open(OUT, ">./Temp/input_line");
print OUT "operation=browse\n";
print OUT "dataset=flight\n";
print OUT "detector=ephem\n";
print OUT "level=1\n";
#print OUT "version=last\n";
print OUT "filetype=orbitephem1\n";
print OUT "filename=orbitf%\n";
print OUT "go\n";
close(OUT);

system("echo $hakama  |/home/ascds/DS.release/bin/arc4gl -U$dare -Sarcocc -i./Temp/input_line > ./Temp/zout") ; 
system("rm ./Temp/input_line");

open(FH, './Temp/zout');
@file_name = ();
while(<FH>){
	chomp $_;
	if($_ =~ /orbitf/){
		@atemp = split(/\s+/, $_);
		@btemp = split(/orbitf/, $atemp[0]);
		@ctemp = split(/N/, $btemp[1]);
		if($ctemp[0] > $last_time){		#--- keep only files newer than the last processed date
			push(@file_name, $atemp[0]);
		}
	}
}
close(FH);
system("rm ./Temp/zout");

#
#---- now retrieve from archive
#

$alist = `ls -d ./Temp/Orbit/*`;
@dlist = split(/\s+/, $alist);

OUTER:
foreach $dir (@dlist){
        if($dir =~ /fits/){
                system("rm ./Temp/Orbit/*.fits");
                last OUTER;
        }
}

foreach $file (@file_name){
#print "$file\n";
	open(OUT, ">./Temp/Orbit/input_line");
	print OUT "operation=retrieve\n";
	print OUT "dataset=flight\n";
	print OUT "detector=ephem\n";
	print OUT "level=1\n";
	print OUT "filetype=orbitephem1\n";
	print OUT "filename=$file\n";
	print OUT "go\n";
	close(OUT);
	
	system("cd ./Temp/Orbit/; echo $hakama  |/home/ascds/DS.release/bin/arc4gl -U$dare -Sarcocc -i./input_line") ; 
}
system("rm ./Temp/Orbit/input_line");
system("gzip -d ./Temp/Orbit/*gz");

$a_list = `ls ./Temp/Orbit/*fits`;
@list = split(/\s+/, $a_list);

foreach $fits_file (@list){

#
#--- get a time stamp for output file name
#
	@atemp = split(/orbitf/, $fits_file);
	@btemp = split(/N/, $atemp[1]);
	$time_stamp = $btemp[0];
#
#--- start reading the data
#

	@time = ();
	@x    = ();
	@y    = ();
	@z    = ();
	@vx   = ();
	$vy   = ();
	$vz   = ();
	@start_list = ();
	@end_list   = ();
	
	$cnt  = 0;

	system("fdump $fits_file  ./Temp/zout 'time x y' - clobber=yes");
	open(IN, "./Temp/zout");
	while(<IN>){
		chomp $_;
		if($_ =~ /DATE-OBS/){
			@ctemp = split(/\'/, $_);
			@dtemp = split(/T/, $ctemp[1]);
			@ftemp = split(/-/, $dtemp[0]);
			$f_start = "$ftemp[0]/$ftemp[1]/$ftemp[2],$dtemp[1]";
		}
		if($_ =~ /DATE-END/){
			@ctemp = split(/\'/, $_);
			@dtemp = split(/T/, $ctemp[1]);
			@ftemp = split(/-/, $dtemp[0]);
			$f_end = "$ftemp[0]/$ftemp[1]/$ftemp[2],$dtemp[1]";
		}
		@btemp = split(/\s+/, $_);
		if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
			push(@time, $btemp[2]);
			push(@x,    $btemp[3]);
			push(@y,    $btemp[4]);
			$cnt++;
		}
	}
	close(IN);

	system("fdump $fits_file  ./Temp/zout 'z vx vy' - clobber=yes");
	open(IN, "./Temp/zout");
	while(<IN>){
		chomp $_;
		@btemp = split(/\s+/, $_);
		if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
			push(@z,    $btemp[2]);
			push(@vx,   $btemp[3]);
			push(@vy,   $btemp[4]);
		}
	}
	close(IN);

	system("fdump $fits_file  ./Temp/zout 'vz' - clobber=yes");
	open(IN, "./Temp/zout");
	while(<IN>){
		chomp $_;
		@btemp = split(/\s+/, $_);
		if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
			push(@vz,    $btemp[2]);
		}
	}
	close(IN);
	system("rm ./Temp/zout");
#	system("rm  $fits_file");

#
#--- get corresponding orbital angle files from archive database
#

	$alist = `ls -d ./Temp/Angle/*`;
	@dlist = split(/\s+/, $alist);
	
	OUTER:
	foreach $dir (@dlist){
        	if($dir =~ /fits/){
                	system("rm ./Temp/Angle/*.fits");
                	last OUTER;
        	}
	}

	open(OUT, ">./Temp/Angle/input_line");
	print OUT "operation=retrieve\n";
	print OUT "dataset=flight\n";
	print OUT "detector=ephem\n";
	print OUT "level=1\n";
	#print OUT "version=last\n";
	print OUT "filetype=angleephem\n";
	print OUT "tstart=$f_start\n";
	print OUT "tstop=$f_end\n";
	print OUT "go\n";
	close(OUT);

	system("cd ./Temp/Angle; echo $hakama  |/home/ascds/DS.release/bin/arc4gl -U$dare -Sarcocc -i./input_line") ; 
	system("rm ./Temp/Angle/input_line");

	system("gzip -d ./Temp/Angle/*gz");

#
#--- here is the list of angle data files
#
	$a_list = `ls ./Temp/Angle/angle*_eph1.fits`;
	@angle_list = split(/\s+/, $a_list);
	
	@atime          = ();
	@point_x        = ();
	@point_y        = ();

	@point_z        = ();
	@suncnet        = ();
	@sunlimb        = ();

	@mooncent      = ();
	@moonlimb      = ();
	@earthcent     = ();

	@earthlimb     = ();
	@dist_satearth = ();
	@sun_earthcent = ();

	@sun_earthlimb = ();
	@ramvector     = ();

	$acnt          = 0;

#
#---- read out data form the file
#
	foreach $fits_file2 (@angle_list){
		system("fdump $fits_file2  ./Temp/zout 'time point_x point_y' - clobber=yes");
		open(IN, "./Temp/zout");
		while(<IN>){
			@btemp = split(/\s+/, $_);
			if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
				push(@atime,     $btemp[2]);
				push(@point_x,    $btemp[3]);
				push(@point_y,    $btemp[4]);
				$acnt++;
			}
		}
		close(IN);
	
	
		system("fdump $fits_file2  ./Temp/zout 'point_z point_suncentang point_sunlimbang' - clobber=yes");
		open(IN, "./Temp/zout");
		while(<IN>){
			@btemp = split(/\s+/, $_);
			if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
				push(@point_z,     $btemp[2]);
				push(@suncent,  $btemp[3]);
				push(@sunlimb,  $btemp[4]);
				$acnt++;
			}
		}
		close(IN);
	
		system("fdump $fits_file2  ./Temp/zout 'point_mooncentang point_moonlimbang point_earthcentang' - clobber=yes");
		open(IN, "./Temp/zout");
		while(<IN>){
			@btemp = split(/\s+/, $_);
			if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
				push(@mooncent,     $btemp[2]);
				push(@moonlimb,     $btemp[3]);
				push(@earthcent,    $btemp[4]);
				$acnt++;
			}
		}
		close(IN);
	
		system("fdump $fits_file2  ./Temp/zout 'point_earthlimbang dist_satearth sun_earthcentang' - clobber=yes");
		open(IN, "./Temp/zout");
		while(<IN>){
			@btemp = split(/\s+/, $_);
			if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
				push(@earthlimb,       $btemp[2]);
				push(@dist_satearth,   $btemp[3]);
				push(@sun_earthcent,   $btemp[4]);
				$acnt++;
			}
		}
		close(IN);
	
		system("fdump $fits_file2  ./Temp/zout 'sun_earthlimbang point_ramvectorang' - clobber=yes");
		open(IN, "./Temp/zout");
		while(<IN>){
			@btemp = split(/\s+/, $_);
			if($btemp[1] =~ /\d/ && $btemp[2] =~ /\d/){
				push(@sun_earthlimb,     $btemp[2]);
				push(@ramvector,    $btemp[3]);
				$acnt++;
			}
		}
		close(IN);
		system("rm ./Temp/zout");
	
	}
	close(FH);
	system("rm ./Temp/alist");
#
#---- all angle data are read from fits files (usually around 400 files)
#---- put thedata into a hush table, so that after sorting out time, we can still
#---- retreive the data in order
#
	for($i = 0; $i < $acnt; $i++){
		%{ang_data.$atime[$i]} = ( point_x => ["$point_x[$i]"],
					   point_y => ["$point_y[$i]"],
					   point_z => ["$point_z[$i]"],
					   suncent => ["$suncent[$i]"],
					   sunlimb => ["$sunlimb[$i]"],
					   mooncent => ["$mooncent[$i]"],
					   moonlimb => ["$moonlimb[$i]"],
					   earthcent => ["$earthcent[$i]"],
					   earthlimb => ["$earthlimb[$i]"],
					   dist_satearth => ["$dist_satearth[$i]"],
					   sun_earthcent => ["$sun_earthcent[$i]"],
					   sun_earthlimb => ["$sun_earthlimb[$i]"],
					   ramvector     => ["$ramvector[$i]"]
					);
	}

	@temp = sort{$a<=>$b} @atime;
	@atime = @temp;
	
#
#---- open an output file: name is appended with the time stamp
#
	$orbit_file = "/data/mta/Script/Orbital/Orb/orbit_data_$time_stamp";
	open(OUT, ">$orbit_file");

	print OUT "#time\t";
	print OUT "X\t";
	print OUT "Y\t";
	print OUT "Z\t";
	print OUT "VX\t";
	print OUT "VY\t";
	print OUT "VZ\t";
	print OUT "Point_X\t";
	print OUT "Point_Y\t";
	print OUT "Point_Z\t";
	print OUT "SunCentAng\t";
	print OUT "SunLimbAng\t";
	print OUT "MoonCentAng\t";
	print OUT "MoonLimbAng\t";
	print OUT "EarthCentAng\t";
	print OUT "EarthLimbAng\t";
	print OUT "Dist_SatEarth\t";
	print OUT "Sun_EarthCent\t";
	print OUT "Sun_EarthLimb\t";
	print OUT "RamVector\n";
	print OUT "#\n";

#
#---- $j increment with angle data
#
	$j = 0;
	for($i = 0; $i < $cnt; $i++){
#
#--- data from oribit file
#
		print OUT "$time[$i]\t";
		print OUT "$x[$i]\t";
		print OUT "$y[$i]\t";
		print OUT "$z[$i]\t";
		print OUT "$vx[$i]\t";
		print OUT "$vy[$i]\t";
		print OUT "$vz[$i]\t";

#
#---- compare time from the oribit file and that from angle files
#---- and if match, print the angle data
#
		if($time[$i] == $atime[$j]){

			print OUT "${ang_data.$atime[$j]}{point_x}[0]\t";
			print OUT "${ang_data.$atime[$j]}{point_y}[0]\t";
			print OUT "${ang_data.$atime[$j]}{point_z}[0]\t";

			print OUT "${ang_data.$atime[$j]}{suncent}[0]\t";
			print OUT "${ang_data.$atime[$j]}{sunlimb}[0]\t";

			print OUT "${ang_data.$atime[$j]}{mooncent}[0]\t";
			print OUT "${ang_data.$atime[$j]}{moonlimb}[0]\t";

			print OUT "${ang_data.$atime[$j]}{earthcent}[0]\t";
			print OUT "${ang_data.$atime[$j]}{earthlimb}[0]\t";

			print OUT "${ang_data.$atime[$j]}{dist_satearth}[0]\t";
			print OUT "${ang_data.$atime[$j]}{sun_earthcent}[0]\t";
			print OUT "${ang_data.$atime[$j]}{sun_earthlimb}[0]\t";
			print OUT "${ang_data.$atime[$j]}{ramvector}[0]\n";

			$j++;
		}elsif($time[$i] > $atime[$j]){
			OUTER:
			while($time[$i] > $atime[$j]){
				$j++;
				if($j >= $acnt){
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\n";
					$j = $acnt;
					last OUTER;
				}
				if($time[$i] == $atime[$j]){
					print OUT "${ang_data.$atime[$j]}{point_x}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_y}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_z}[0]\t";

					print OUT "${ang_data.$atime[$j]}{suncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sunlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{mooncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{moonlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{earthlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{dist_satearth}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthlimb}[0]\t";
					print OUT "${ang_data.$atime[$j]}{ramvector}[0]\n";

					$j++;
					last OUTER;
				}elsif($$time[$i] < $atime[$j] && $time[$i] > $atime[$j-1]){
					print OUT "${ang_data.$atime[$j]}{point_x}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_y}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_z}[0]\t";

					print OUT "${ang_data.$atime[$j]}{suncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sunlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{mooncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{moonlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{earthlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{dist_satearth}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthlimb}[0]\t";
					print OUT "${ang_data.$atime[$j]}{ramvector}[0]\n";
					$j++;
					last OUTER;
				}else{
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\n";
					last OUTER;
				}
			}
		}elsif($time[$i] < $atime[$j]){
			OUTER:
			while($time[$i] < $atime[$j]){
				$j--;
				if($j <= 0){
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\n";
					$j = 0;
					last OUTER;
				}
				if($time[$i] == $atime[$j]){
					print OUT "${ang_data.$atime[$j]}{point_x}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_y}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_z}[0]\t";

					print OUT "${ang_data.$atime[$j]}{suncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sunlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{mooncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{moonlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{earthlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{dist_satearth}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthlimb}[0]\t";
					print OUT "${ang_data.$atime[$j]}{ramvector}[0]\n";
					$j++;
					last OUTER;
				}elsif($time[$i] > $atime[$j] && $time[$i] < $atime[$j+1]){
					print OUT "${ang_data.$atime[$j]}{point_x}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_y}[0]\t";
					print OUT "${ang_data.$atime[$j]}{point_z}[0]\t";

					print OUT "${ang_data.$atime[$j]}{suncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sunlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{mooncent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{moonlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{earthlimb}[0]\t";

					print OUT "${ang_data.$atime[$j]}{dist_satearth}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthcent}[0]\t";
					print OUT "${ang_data.$atime[$j]}{sun_earthlimb}[0]\t";
					print OUT "${ang_data.$atime[$j]}{ramvector}[0]\n";
					$j++;
					last OUTER;
				}else{
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
					print  OUT "-999.00\t";
			
					print  OUT "-999.00\t";
					print  OUT "-999.00\n";
					last OUTER;
				}
			}
		}
	}
	close(OUT);
}

system("rm -rf ./Temp ./param");