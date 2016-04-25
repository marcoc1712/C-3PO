#!/usr/bin/perl
#
# This program is part of the C-3PO Plugin. 
# See Plugin.pm for credits, license terms and others.
#
# Logitech Media Server Copyright 2001-2011 Logitech.
# This Plugin Copyright 2015 Marco Curti (marcoc1712 at gmail dot com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#########################################################################

package main;

use FindBin qw($Bin);
use lib $Bin;

use Utils::Config;

unshift @INC, Utils::Config::expandINC($Bin);

use constant ISWINDOWS    => ( $^O =~ /^m?s?win/i ) ? 1 : 0;
use constant ISMAC        => ( $^O =~ /darwin/i ) ? 1 : 0;

use Data::Dump qw(dump);

#my $pathToC3PO_exe = "G:\\Sviluppo\\slimserver\\Plugins\\C3PO\\Bin\\MSWin32-x86-multi-thread\\C-3PO.exe";
my $pathToC3PO_exe = "G:\\Sviluppo\\slimserver\\Plugins\\C3PO\\C-3PO.pl";
my $logFolder= "C:\\Documents and Settings\\All Users\\Dati applicazioni\\SqueezeboxTest\\logs";

my $clientId= 'e8:de:27:03:05:b2';
my $prefFile="C:\\Documents and Settings\\All Users\\Dati applicazioni\\SqueezeboxTest\\prefs\\plugin\\C3PO.prefs";
my $inCodec='wav';
my $outCodec='wav';
my $start='-s 1486.02666666667';
my $end='-w 218.04';
my $file="F:\\Classica\\Albinoni, Tomaso\\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\\Albinoni - Adagio.wav";

my $command;
	
#test if C3PO.PL will start on LMS calls

if  (!(-e $pathToC3PO_exe)){
	warn('WARNING: wrong path to C-3PO.exe, will not start - '.$pathToC3PO_exe);
	exit;
}

$command= qq("$pathToC3PO_exe" -d -c $clientId -p "$prefFile" -l "$logFolder" ).
		  qq(-i $inCodec -o $outCodec $start $end "$file");
		  
#$command= qq("$pathToC3PO_exe" -h hello -l "$logFolder");

$command= finalizeCommand($command);

my $ret= `$command`;
print ($ret ? $ret : 'nothing');

sub finalizeCommand{
	my $command=shift;
	
	if (!defined $command || $command eq "") {return ""}

	if (main::ISWINDOWS){

		# command could not start with ", should move it after the volume ID.
		if (substr($command,0,1) eq '"'){

			my $str= substr($command,2,length($command)-2);
			my $vol= substr($command,1,1);
			
			$command=$vol.'"'.$str;
		}
	}
	return $command;
}
1;