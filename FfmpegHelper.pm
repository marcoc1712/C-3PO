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

package Plugins::C3PO::FfmpegHelper;

use strict;

sub split_{
	my $transcodeTable =shift;
	
	my $isRuntime	= Plugins::C3PO::Transcoder::isRuntime($transcodeTable);
	my $inCodec		= $transcodeTable->{'transitCodec'};
	my $start		= $transcodeTable->{'options'}->{'startSec'};
	my $end			= $transcodeTable->{'options'}->{'durationSec'};
	my $file		= $transcodeTable->{'options'}->{'file'};
	my $exe			= $transcodeTable->{'pathToFFmpeg'};
	
	Plugins::C3PO::Logger::verboseMessage('Start ffmpeg split_');

	$inCodec=_translateCodec($inCodec);
						
	if ($isRuntime){

		my $commandString= qq("$exe" -vn -v 0 );
		#print $commandString."\n";

		if (defined $start){
			$commandString = $commandString.'-ss '.$start.' ';
		}
		if (defined $end){
			$commandString = $commandString.'-t '.$end.' ';
		}
		if ((!defined $file) || ($file eq "")|| ($file eq "-")) {

			$commandString=$commandString.qq(-i - -f $inCodec -);

		} else{

			$commandString= qq($commandString -i "$file" -f $inCodec -);
			
		}

		return $commandString;

	} else{
	
		return '[ffmpeg] -vn -v 0 $START$ $END$ -i $FILE$ -f '.$inCodec.' -';
	}
}

sub transcode {
	my $transcodeTable =shift;
	
	my $isRuntime	= Plugins::C3PO::Transcoder::isRuntime($transcodeTable);
	my $outCodec	= $transcodeTable->{'outCodec'};
	my $command		= $transcodeTable->{'command'};
	my $exe			= $transcodeTable->{'pathToFFmpeg'};
	my $file		= $transcodeTable->{'options'}->{'file'};
	
	Plugins::C3PO::Logger::verboseMessage('Start ffmpeg transcode');
	
	$outCodec=_translateCodec($outCodec);
	my $commandString="";
	
	if ((!defined $command) || ($command eq "")){
	
		$commandString= qq(-vn -v 0 -i "$file" -f $outCodec -);
	
	} else{
	
		$commandString= qq(-vn -v 0 -i - -f $outCodec -);
	
	}
	
	if ($isRuntime){

		$commandString = qq("$exe" $commandString);
	
	} else{
	
		$commandString = '[ffmpeg] '.$commandString;
	}
	
	return $commandString;
}

sub _translateCodec{
	my $codec= shift;
	
	if ($codec eq 'aif') {return 'aiff';}
	return $codec;
}
1;