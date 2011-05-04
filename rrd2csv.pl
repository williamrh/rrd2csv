#!/usr/bin/perl
use POSIX qw(strftime);
use lib '/usr/opt/rrdtool/';
#use lib '/opt/rrdtool-1.4.4/lib/perl/5.8.8/x86_64-linux-thread-multi/';
use RRDs;

%scale_symbols = qw( -18 a -15 f -12 p -9 n -6 u -3 m
  3 k 6 M 9 G 12 T 15 P 18 E );

#----------------------------------------

while ( $ARGV[0] =~ /^-/ ) {
  SWITCH: {
    if ( $ARGV[0] eq '--debug' || $ARGV[0] =~ /^-d/ ) {
      $debug = 1;
      last SWITCH;
    }
    if ( $ARGV[0] eq '--notime' || $ARGV[0] =~ /^-n/ ) {
      $notime = 1;
      last SWITCH;
    }
    if ( $ARGV[0] eq '--title' || $ARGV[0] =~ /^-t/ ) {
      shift @ARGV;
      $title = $ARGV[0];
      last SWITCH;
    }
    if ( $ARGV[0] eq '--resolution' || $ARGV[0] =~ /^-r/ ) {
      shift @ARGV;
      $resolution = $ARGV[0];
      last SWITCH;
    }
    if ( $ARGV[0] eq '--autoscale' || $ARGV[0] =~ /^-a/ ) {
      $scale = 1;
      last SWITCH;
    }
    if ( $ARGV[0] eq '--conversion' || $ARGV[0] =~ /^-c/ ) {
      shift @ARGV;
      $conversion = $ARGV[0];
      if ( $conversion !~ /^\d+$|^\d+\.\d+$|^\.\d+$/ ) {
        print "bad conversion factor \"$conversion\"\n";
        exit 1;
      }
      last SWITCH;
    }
    if ( $ARGV[0] eq '--label' || $ARGV[0] =~ /^-l/ ) {
      shift @ARGV;
      $label = $ARGV[0];
      last SWITCH;
    }
    if ( $ARGV[0] eq '--start' || $ARGV[0] =~ /^-s/ ||
         $ARGV[0] eq '--begin' || $ARGV[0] =~ /^-b/ ) {
      shift @ARGV;
      $start = $ARGV[0];
      last SWITCH;
    }
    if ( $ARGV[0] eq '--end' || $ARGV[0] =~ /^-e/ ) {
      shift @ARGV;
      $end = $ARGV[0];
      last SWITCH;
    }
    if ( $ARGV[0] eq '--now' || $ARGV[0] =~ /^-n/ ) {
      $point_in_time = 1;
      last SWITCH;
    }
    if ( $ARGV[0] eq '--verbose' || $ARGV[0] =~ /^-v/ ) {
      $verbose = 1;
      last SWITCH;
    }
    if ( $ARGV[0] eq '--max' || $ARGV[0] =~ /^-m/ ) {
      $max = 1;
      last SWITCH;
    }
    print "rrd2csv: unknown option \"$ARGV[0]\"\n";
    exit 1;
  }
  shift @ARGV;
}

#----------------------------------------

if ( $#ARGV != 0 ) {
  print <<_EOT_;
usage: rrd2csv [args] some.rrd
  -a            autoscale DS values (also --autoscale)
  -c num        convert DS values by "num" (also --conversion)
  -e end        report ending at time "end" (also --end)
  -l label      label DS values with "label" (also --label)
  -m            only report the maximum value (also --max)
  -n            only report values around now (--now)
  -s start      report starting at time "start" (also --start)
  -v            print the start and end times (also --verbose)
  --notime      should only be used by scripts
  --title       print the RRD value descriptions at the top
  --resolution  this number multiplies the 10 second step by X

  The -s and -e options support the traditional "seconds
  since the Unix epoch" and the AT-STYLE time specification
  (see man rrdfetch)
_EOT_
  exit 1;
}

if ( ! -f "$ARGV[0]" ) {
  print "rrd2csv: can't find \"$ARGV[0]\"\n";
  exit 1;
}

#----------------------------------------

MODE_PARSE:  {
  # now...
  if ( $now ) {
    $start = $end = 'now';
    last MODE_PARSE;
  }
  # max...
  if ( $max ) {
    $start = 'now-1year';
    $end = 'now';
    last MODE_PARSE;
  }
  # start and no end so spec end...
  if ( $start && ! $end ) {
    $end = 'now';
    last MODE_PARSE;
  }
  # end and no start so make start just before end...
  if ( $end && ! $start ) {
    if ( $end =~ /^\d+$/ ) {
      $start = $end-1;
    } else {
      $start = "${end}-1sec";
    }
    $point_in_time = 1;
    last MODE_PARSE;
  }
  # no now, no start, no end... report now...
  if ( ! $start && ! $end ) {
    $start = $end = 'now';
    $point_in_time = 1;
    last MODE_PARSE;
  }
}

#----------------------------------------

if ( $point_in_time ) {
  # find out step...
  push @fetch, $ARGV[0], '-s', $start, '-e', $end, 'AVERAGE';
  if ( $debug ) { print "rrdtool fetch ", join(' ',@fetch), " (figuring out step)\n"; }
  ($start,$step,$names,$data) = RRDs::fetch @fetch;
  if ( $error = RRDs::error ) {
    print "rrd2csv: rrdtool fetch failed: \"$error\"\n";
    exit 1;
  }
  # do fetch from point_in_time minus step to point_in_time...
  # "go back two steps"... so we report values on either side
  # of the point in time...
  undef @fetch;
  $offset = $step * 10;
  if ( $end =~ /^\d+$/ ) {
    $start = $start - $offset;
  } else {
    $start = "${end}-${offset}sec";
  }
  push @fetch, $ARGV[0], '-s', $start, '-e', $end, 'AVERAGE';
  if ( $debug ) { print "rrdtool fetch ", join(' ',@fetch), " (getting data)\n"; }
  ($start,$step,$names,$data) = RRDs::fetch @fetch;
  if ( $error = RRDs::error ) {
    print "rrd2csv: rrdtool fetch failed: \"$error\"\n";
    exit 1;
  }
} else {
  push @fetch, $ARGV[0];
  if ( $start ) { push @fetch, '-s', $start; }
  if ( $end ) { push @fetch, '-e', $end; }
  push @fetch, 'AVERAGE';
#  print "rrdtool fetch ", join(' ',@fetch), "\n";
#print "
  ($start,$step,$names,$data) = RRDs::fetch @fetch;
#    if ( $resolution ) {
#      $step = $step * $resolution;
#    }

  if ( $error = RRDs::error ) {
#    print "rrd2csv: rrdtool fetch failed: \"$error\"\n";

    exit 1;
  }
}

#----------------------------------------

if ( $debug ) {
  $now = time();
  print '-' x 66, "\n";
  $d_start = $start;
  $last = RRDs::last $ARGV[0];
  print "  Now:         ", scalar localtime($now), " ($now)\n";
  print "  Last update: ", scalar localtime($last), " ($last)\n";
  print "  Start:       ", scalar localtime($d_start), " ($d_start)\n";
  print "  End:         ", scalar localtime($end), " ($end)\n";
  print "  Step size:   $step seconds\n";
  print "  Data points: ", $#$data + 1, "\n";
  print "  Data:                                  ";
  foreach $name (@$names) { printf " %8s", $name; }
  print "\n";
  foreach $line (@$data) {
    print "    ", scalar localtime($d_start), " ($d_start) ";
    $d_start += $step;
    foreach $val (@$line) {
      if ( ! defined $val ) {
        printf "%8s ", 'NaN';
      } else {
        printf "%8.2f ", $val;
      }
    }
    print "\n";
  }
  print '-' x 66, "\n";
}

#----------------------------------------
if ( $title ) {
  $now = time();
#  print '-' x 66, "\n";
  $d_start = $start;
  $last = RRDs::last $ARGV[0];
  print "TIME ";
foreach $name (@$names) { printf ",%8s", $name; }
    print "\n";
}

if ( $max ) {
  for $t ( 0 .. $#{$data} ) {
    $start += $step;
    for $i (0 .. $#$names) {
      if ( $data->[$t][$i] > $max[$i] ) {
        if ( $debug ) { print "new max for ds num $i is $data->[$t][$i]\n"; }
        $max[$i] = $data->[$t][$i];
        $time_of_max[$i] = $start;
      }
    }
  }
  if ( $debug ) { print '-' x 66, "\n"; }
  for $i ( 0 .. $#$names ) {
    if ( $conversion ) {
      $max[$t] = $max[$t] * $conversion;
    }
    if ( $scale ) {
      ($val, $units) = autoscale($max[$i]);
    } else {
      $val = $max[$i];
    }
    print scalar localtime($time_of_max[$i]);
    printf "  %8.2f$units$label %s\n", $$names[$i];
  }
  exit;
}

#----------------------------------------

$skip = 1;
if ( $resolution eq '0' || ! $resolution ) {
        $resolution = '1';
}
#RESOLUTION
if ( $resolution eq '2' ) { $resolution = '30';}
if ( $resolution eq '3' ) { $resolution = '180';}
if ( $resolution eq '4' ) { $resolution = '360';}
if ( $resolution eq '5' ) { $resolution = '770';}
if ( $resolution eq '6' ) { $resolution = '2160';}
print "RESOLUTION: $resolution\n";
#RESOLUTION
for $t ( 0 .. $#{$data} ) {
	if ( $resolution eq $skip ) {
		$skip = 1;
		if ( !$notime ) {
			if ( $verbose ) {
				print scalar localtime($start), ' through ',
				scalar localtime($start+$step), ' average';
			} else {
				print strftime("%m/%d/%Y %H:%M:%S", localtime($start));
			}
		}

		$start += $step * $resolution;
		for $i (0 .. $#$names) {
			if ( ! defined $data->[$t][$i] ) {
				#      printf "  %8s %s", 'NaN', $$names[$i];
				#      next;
			}

			if ( $conversion ) {

				$data->[$t][$i] = $data->[$t][$i] * $conversion;
			}

			if ( $scale ) {
				($val, $units) = autoscale($data->[$t][$i]);
			} else {
				$val = $data->[$t][$i];
			}

			printf ", %8.2f$units$label %s", $val;
			#printf "  %8.2f$units$label %s", $val, $$names[$i];
		}
	print "\n";

	} else {
		$skip++;
	}
}

exit 0;

#==============================================================================

sub autoscale {
  local($value) = @_;
  local($floor, $mag, $index, $symbol, $new_value);

  if ( $value =~ /^\s*[0]+\s*$/ ||
       $value =~ /^\s*[0]+.[0]+\s*$/ ||
       $value =~ /^\s*NaN\s*$/ ) {
    return $value, ' ';
  }

  $floor = &floor($value);
  $mag = int($floor/3);
  $index = $mag * 3;
  $symbol = $scale_symbols{$index};
  $new_value = $value / (10 ** $index);
  return $new_value, " $symbol";
}

#------------------------------------------------------------------

sub floor {
  local($value) = @_;
  local($i) = 0;

  if ( $value > 1.0 ) {
    # scale downward...
    while ( $value > 10.0 ) {
      $i++;
      $value /= 10.0;
    }
  } else {
    while ( $value < 10.0 ) {
      $i--;
      $value *= 10.0;
    }
  }
  return $i;
}
