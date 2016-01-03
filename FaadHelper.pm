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

package Plugins::C3PO::FaadHelper;

use strict;
use warnings;

sub decode{
	my $transcodeTable =shift;
	Plugins::C3PO::Logger::debugMessage('Start faad/alc decode');
	
	my $isRuntime	= Plugins::C3PO::Transcoder::isRuntime($transcodeTable);
	my $start = $transcodeTable->{'options'}->{'startSec'};
	my $end = $transcodeTable->{'options'}->{'endSec'};
	my $file = $transcodeTable->{'options'}->{'file'};
	my $exe=$transcodeTable->{'pathToFaad'};
	
	
	#[faad] -q -w -f 1 $START$ $END$ $FILE$
	
	my $commandString = '-q -w -f 1';
	
	if ($isRuntime){

		$commandString= qq("$exe" $commandString);
		
		if (defined $start){
			$commandString = $commandString.'-j '.$start.' ';
		}
		if (defined $end){
			$commandString = $commandString.'-e '.$end.' ';
		}
		if ((defined $file)){
		
			$commandString = qq($commandString "$file");
			
		}

		return $commandString;
		
	} else {

		return '[faad] '.$commandString.'$START$ $END$ $FILE$';
	}
}
1;