#!/usr/bin/perl


########################################
##Combines multiple RRD's into a single CSV file - Richard Hoop
########################################


 use Getopt::Long;
 use POSIX qw/strftime/;
 use Term::ANSIColor;
 use Sys::Hostname;
 use strict;
 use warnings;

my $start;
my $end;
my $rrd;
my $title;
my $file;
my @csv;
my $i=0;
my $tempstring;
my $temprrd;
my $help;

GetOptions( "start=s" => \$start,
            "end=s" => \$end,
            "rrd=s" => \$rrd,
            "help" => \$help,
            "title=s" => \$title
	);

if ( $help ) { 
	print "\nrrdmulti.pl --rrd=/usr/ops/collectd/vrrd/<SERVERNAME>/cpu-0/ --start=-3600 --end=now";
	print " \n\n\t --rrd should only be the directory of multi graphs. IE CPU or Mem.\n\n"; 
	exit ( 0 );
}

#GET RRDS FROM DIRS
opendir DIR, $rrd or die "cannot open dir $rrd: $!";
my @rrds= readdir DIR;
closedir DIR;

#REMOVE '.' and '..' file names
foreach $file (@rrds) {
	if ($file eq '.' || $file eq '..') {
		splice(@rrds,$i,1);
	}
	$i++;
}

#REST I
$i = 0;

#MASTER EPOCH
my $Output_epoch = (`rrd2csv.pl --start $start --end $end $rrd/$rrds[0] | perl -lane 'print join(" ", \@F[0..1])'`);
$Output_epoch =~ s/,//g;
my @epoch =   split(/\n/, $Output_epoch);

#TIME INTO TITLE
push(my @title,"Time");

#APACHE STATS HAVE EXTR RRD's IN THE FOLDER
if ( $rrd =~ m/apache/ ) { 
	foreach $file (@rrds) {
		if ( $rrds[$i] =~ m/scoreboard.*rrd/) {
			$temprrd = $rrds[$i];   
			$tempstring = (`rrd2csv.pl --notime --start $start --end $end $rrd/$temprrd`);
			@$file =   split(/\n/, $tempstring);
			#TITLE
			my $temptitle = $file;                  
			$temptitle =~ s/apache_scoreboard-//g;
			$temptitle =~ s/.rrd//g;
			push(@title,$temptitle);        
		}
		$i++;

	}
 
} else { 

	foreach $file (@rrds) {
		if ( $rrds[$i] =~ m/rrd/) {
			$temprrd = $rrds[$i];
			$tempstring = (`rrd2csv.pl --notime --start $start --end $end $rrd/$temprrd`);
			@$file =   split(/\n/, $tempstring);
			#TITLE
			my $temptitle = $file;                  
			$temptitle =~ s/.rrd//g;
			push(@title,$temptitle);        
		}
		$i++;
	}
}
	#FIX TIME SKEW AND PRINT THE TITLE

	pop(@epoch);
	pop(@epoch);
	pop(@epoch);
	$title = join(", ",@title);
	print $title;
	print "\n";
	#RESET I
	$i = 0;

	#PRINT IN CSV FORMAT
	foreach my $Line (@epoch)
	{
		print $Line;
		foreach my $name (@rrds) {
			print @$name[$i];
		}

		print "\n";
		$i++;
	}