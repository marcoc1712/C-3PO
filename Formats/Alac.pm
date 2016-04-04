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

package Plugins::C3PO::Formats::Alac;

use strict;
use warnings;
use base qw(Plugins::C3PO::Formats::Format);

sub new { 

	my $class = shift; 
	my $self = $class->SUPER::new(@_);

	$self->_set_isCompressedCodec(1);
	$self->_set_useSoxToTranscodeWhenResampling(0);#sox can't decode ALAC
	$self->_set_useSoxToEncodeWhenResampling(0);#sox can't decode ALAC

	$self->_set_useFFMpegToSplit(1); #should it works?
	$self->_set_useFFMpegToTranscode(0); #keep using FAAD
	
	$self->_set_useFAADToSplit(0);#not working.
	
	return $self;
}

################################################################################
# public methods
################################################################################
sub splitBeforeResampling {
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('splitBeforeResampling');
	
	if ($self->useFFMpegToSplit($transcodeTable)){

		$commandString=$self->_splitUsingFfmpeg($transcodeTable);
		
	} else {

		$commandString = $self->_decodeUsingFaad($transcodeTable);
	}

	Plugins::C3PO::Logger::debugMessage('$commandString '.$commandString);
	return $commandString;
}
sub decodeBeforeResampling{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('ALAC: Decode');
	
	if ($self->_useFFMpegToTranscode($transcodeTable)){

		$commandString = $self->_splitAndEncodeUsingFfmpeg($transcodeTable);

	} else {

		$commandString = $self->_decodeUsingFaad($transcodeTable);
	}
	return $commandString;
}
sub splitAndEncode {
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('splitBeforeResampling');
	
	if ($self->useFFMpegToSplit($transcodeTable)){

		$commandString=$self->_splitAndEncodeUsingFfmpeg($transcodeTable);
		
	} else {

		$commandString = $self->_decodeUsingFaad($transcodeTable);
	}

	Plugins::C3PO::Logger::debugMessage('$commandString '.$commandString);
	return $commandString;
}
################################################################################
# Protected methods.
################################################################################

sub transcodeToWav{
	my $self = shift;
	my $transcodeTable=shift;
	
	return $self->decodeBeforeResampling($transcodeTable);
}

sub transcodeToAiff{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString ="";
	
	if ($self->_useFFMpegToTranscode($transcodeTable)){

		$commandString = $self->_splitUsingFfmpeg($transcodeTable);

	} else{
	
		$commandString = $self->_decodeUsingFaad($transcodeTable);
		$commandString = $commandString. " | ".Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	}
	return $commandString;
}

sub transcodeToFlac{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	$commandString = $self->_decodeUsingFaad($transcodeTable);
	$transcodeTable->{'command'}=$commandString;
	$commandString = $commandString. " | ".Plugins::C3PO::FlacHelper::encode($transcodeTable);

	return $commandString;
}
################################################################################
# Private methods.
################################################################################

sub _decodeUsingFaad{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('using faad To Transcode ALAC to WAV');

	#wav is the only option for FAAD.
	$transcodeTable->{'transitCodec'}='wav';	
	$commandString=Plugins::C3PO::FaadHelper::decode($transcodeTable);
	
	Plugins::C3PO::Logger::debugMessage('$commandString '.$commandString);
	
	return $commandString;
}
1;