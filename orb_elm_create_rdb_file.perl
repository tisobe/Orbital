#!/usr/bin/perl

#################################################################################################
#												#
#	orb_elm_create_rdb_file.perl: read data from Orbit directory and create 2 rdb files	#
#												#
#		if you attach an argument "all", it will collect data from the begining		#
#		otherwise, just add new data to the past data					#
#												#
#	author: t isobe (tisobe@cfa.harvard.edu)						#
#												#
#	last update: Jan 20, 2005								#
#												#
#################################################################################################

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
#--- read current data sets
#

$a_list = `ls /data/mta/Script/Orbital/Orb/orbit_data_*`;
@new_list = split(/\s+/, $a_list);

#
#---- check whether we need to start from scratch or not
#

$check = $ARGV[0];

if($check =~ /all/){ 
#
#--- the case that a user asked to start from scratch
#
#---- we create two rdb files; 
#
	open(OUT1, '>/data/mta/DataSeeker/data/repository/aorbital.rdb');
	open(OUT2, '>/data/mta/DataSeeker/data/repository/orb_angle.rdb');

#
#--- printing headers
#
	print OUT1 "time\t";
	print OUT1 "X\t";
	print OUT1 "Y\t";
	print OUT1 "Z\t";
	print OUT1 "VX\t";
	print OUT1 "VY\t";
	print OUT1 "VZ\t";
	print OUT1 "Point_X\t";
	print OUT1 "Point_Y\t";
	print OUT1 "Point_Z\n";
	
	print OUT2 "time\t";
	print OUT2 "SunCentAng\t";
	print OUT2 "SunLimbAng\t";
	print OUT2 "MoonCentAng\t";
	print OUT2 "MoonLimbAng\t";
	print OUT2 "EarthCentAng\t";
	print OUT2 "EarthLimbAng\t";
	print OUT2 "Dist_SatEarth\t";
	print OUT2 "Sun_EarthCent\t";
	print OUT2 "Sun_EarthLimb\t";
	print OUT2 "RamVector\n";
	
	for($i = 0; $i < 9; $i++){
		print OUT1 "N\t";
	}
	print OUT1 "N\n";
	
	for($i = 10; $i < 19; $i++){
		print OUT2 "N\t";
	}
	print OUT2 "N\n";

	@in_list = @new_list;
}else{
#
#---- the case that we are just adding new data to the already existing database
#
	open(OUT1, '>>/data/mta/DataSeeker/data/repository/aorbital.rdb');
	open(OUT2, '>>/data/mta/DataSeeker/data/repository/orb_angle.rdb');

	open(FH, '/data/mta/Script/Orbital/past_data');
	@past_data = ();
	while(<FH>){
		chomp $_;
		$save = $_;
	}
	close(FH);
	@atemp = split(/orbit_data_/, $save);
	$last_time_stamp = $atemp[1];

	@in_list = ();
	foreach $ent (@new_list){
		@atemp = split(/orbit_data_/, $ent);
		if($atemp[1] > $last_time_stamp){
			push(@in_list, $ent);
		}
	}
}

#
#---- get a list of orbital data extracted
#

$last = 0;
foreach $file (@in_list){

	open(IN, "$file");
	OUTER:
	while(<IN>){
		chomp $_;
		if($_ =~ /\#/){
			next OUTER;
		}
		@atemp = split(/\s+/, $_);
		if($last < $atemp[0]){
			$last = $atemp[0];
			printf OUT1 "%8.1f\t",$atemp[0];
			for($i = 1; $i < 9; $i++){
				printf OUT1 "%8.2f\t",$atemp[$i];
			}
			printf OUT1 "%8.2f\n",$atemp[9];
	
			printf OUT2 "%8.1f\t",$atemp[0];
			for($i = 10; $i < 19; $i++){
				printf OUT2 "%8.2f\t",$atemp[$i];
			}
			printf OUT2 "%8.2f\n",$atemp[19];
		}
	}
	close(IN);
}
close(OUT1);
close(OUT2);
close(FH);

system('ls /data/mta/Script/Orbital/Orb/orbit_data_* >  /data/mta/Script/Orbital/past_data');

system("rm -rf ./Temp ./param");

