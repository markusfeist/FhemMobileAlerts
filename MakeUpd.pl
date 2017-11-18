#!/usr/bin/perl
 
use strict;
use warnings;
use File::stat;
use Fcntl ':mode';

  open(UPDFILE, ">controls_mobilealerts.txt") || die("Can't open Updatefile: $!\n");
  opendir DH, "FHEM" || die("Can't open FHEM: $!\n");
  foreach my $file (readdir(DH)) {
    my @line_parts;
    @line_parts[0] = "UPD";
    my $st = stat("FHEM/$file");
    next if (S_ISDIR($st->mode));
    my @mt = localtime($st->mtime);
    @line_parts[1] = sprintf "%04d-%02d-%02d_%02d:%02d:%02d",
                $mt[5]+1900, $mt[4]+1, $mt[3], $mt[2], $mt[1], $mt[0];
    @line_parts[2] = $st->size;
    @line_parts[3] = "FHEM/" . $file;
    my $modifiy_line = join(" ",@line_parts)."\n";
    print UPDFILE $modifiy_line;
  }
  close UPDFILE;
