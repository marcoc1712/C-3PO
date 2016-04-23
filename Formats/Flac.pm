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

package Plugins::C3PO::Formats::Flac;

use strict;
use warnings;
use base qw(Plugins::C3PO::Formats::Format);

sub new { 

	my $class = shift; 
	my $self = $class->SUPER::new(@_);

	$self->_set_isCompressedCodec(1);
	$self->_set_useSoxToTranscodeWhenResampling(1);
	$self->_set_useSoxToEncodeWhenResampling(1);

	$self->_set_useFFMpegToSplit(0);#not using FFmpeg with flac input
	$self->_set_useFFMpegToTranscode(0);#not using FFmpeg with flac input
	
	$self->_set_useFAADToSplit(0);
	
	return $self;
}

################################################################################
# private  Settings.
################################################################################
sub _useFlacToDecodeWhenSplitting{
	my $self = shift;
	my $transcodeTable=shift;
	return 0; #not working with AIF in  output.
}
sub _useFlacToTranscode {
	my $self = shift;
	my $transcodeTable=shift;
	return 0; #using SOX instead
}
################################################################################
# public methods
################################################################################

sub splitBeforeResampling {
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('FLAC: splitBeforeResampling');
	
	#Always decode to wav before resampling.
	$transcodeTable->{'transitCodec'}='wav';	
	$commandString=Plugins::C3PO::FlacHelper::decode($transcodeTable);
	
	Plugins::C3PO::Logger::debugMessage('$commandString '.$commandString);
	return $commandString;
}

sub decodeBeforeResampling{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	my $outCodec = $self->getOutputCodec($transcodeTable);
	
	# called when SOX could not be used, so always decode to wav.
	$commandString=Plugins::C3PO::FlacHelper::decode($transcodeTable);
	$transcodeTable->{'transitCodec'}='wav';	

	return $commandString;
}
sub splitAndEncode{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $outCodec = $self->getOutputCodec($transcodeTable);
	
	if ($self->compareCodecs($outCodec,'flc')){
		
		#Encode to final compression.
		$transcodeTable->{'transitCodec'}='flc';		
		return Plugins::C3PO::FlacHelper::encode($transcodeTable);
		
	} elsif ($self->_useFlacToDecodeWhenSplitting($transcodeTable)){

		$transcodeTable->{'transitCodec'}=$self->getOutputCodec($transcodeTable);
		return Plugins::C3PO::FlacHelper::decode($transcodeTable);
		
	} else{
	
		#decode to wav,  will be transcoded to $outcodec in 
		#a further step.
		$transcodeTable->{'transitCodec'}='wav';		
		return Plugins::C3PO::FlacHelper::decode($transcodeTable);
	}
}
################################################################################
# Protected methods.
################################################################################

sub transcodeToWav{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString;
	
	if ($self->_useFlacToTranscode($transcodeTable)){
		
		$commandString=Plugins::C3PO::FlacHelper::decode($transcodeTable);
		
	} else {
	
		$commandString = Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	}
	return $commandString;
}
sub transcodeToAiff{
	my $self = shift;
	my $transcodeTable=shift;
	
	# FLAC is not working properly with AIFF output. 
	# TODO, use FFMPEG as an option?
	
	my $commandstring = Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	return $commandstring;
}

sub transcodeToFlac{
	my $self = shift;
	my $transcodeTable=shift;
	
	#maybe we should change the compression level.
	my $commandstring=Plugins::C3PO::FlacHelper::encode($transcodeTable);
	
	return $commandstring;
}
################################################################################
# Private methods.
################################################################################

1;