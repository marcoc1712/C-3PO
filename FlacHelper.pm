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
#

package Plugins::C3PO::FlacHelper;

use strict;

sub encode{
	my $transcodeTable =shift;
	Plugins::C3PO::Logger::verboseMessage('Start flac encode');
	
	return transcode($transcodeTable,'');
}
sub decode{
	my $transcodeTable =shift;
	Plugins::C3PO::Logger::verboseMessage('Start flac decode');
	
	# TODO:
	# To decode directly in split, we should take care of the desired 
	# output codec.
	# See also useFlacToDecodeWhenSplitting.
	#
	return transcode($transcodeTable,'d');
}
sub transcode{
	my $transcodeTable =shift;
	my $decode=shift;
	
	my $isRuntime	= Plugins::C3PO::Transcoder::isRuntime($transcodeTable);
	my $start = $transcodeTable->{'options'}->{'startTime'};
	my $end = $transcodeTable->{'options'}->{'endTime'};
	my $file = $transcodeTable->{'options'}->{'file'};
	my $exe=$transcodeTable->{'pathToFlac'};
	
	my $compression	= $transcodeTable->{'outCompression'};
	my $command	= $transcodeTable->{'command'};
	
	Plugins::C3PO::Logger::verboseMessage('Start flac transcode');
	
	$compression =_getCompression($compression);
	
	my $commandString="";
	if (!defined $decode || $decode eq ''){
		
		$commandString = '-cs --totally-silent --compression-level-'.$compression.' ';
	}
	else{
	
		$commandString = '-dcs --totally-silent ';
	}
	
	if ($isRuntime){

		$commandString= qq("$exe" $commandString);
		
		if (defined $start){
			$commandString = $commandString.'--skip='.$start.' ';
		}
		if (defined $end){
			$commandString = $commandString.'--until='.$end.' ';
		}
		if ((defined $file) && !($file eq "") && !($file eq "-")){
		
			$commandString = qq($commandString-- "$file");

		} elsif ($file eq "-"){
		
			$commandString =$commandString.'-- -';
			
		}else {
		
			$commandString =$commandString.'--';
		}

		return $commandString;
		
	} elsif ((defined $command) && (!($command eq ""))){

		return '[flac] '.$commandString.' -- -';
		
	} else {

		return '[flac] '.$commandString.'$START$ $END$ -- $FILE$';
	}
}
sub _getCompression{
	my $compression= shift;
	
	if (!defined $compression) {$compression= 0;}
	
	$compression = (( grep { $compression eq $_ } 0,5,8 ) ? $compression : 0);
	return $compression;
}


1;