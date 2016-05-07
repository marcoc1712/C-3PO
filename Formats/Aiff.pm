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

package Plugins::C3PO::Formats::Aiff;

use strict;
use warnings;
use base qw(Plugins::C3PO::Formats::Format);

sub new { 

	my $class = shift; 
	my $self = $class->SUPER::new(@_);

	$self->_set_isCompressedCodec(0);
	$self->_set_useSoxToTranscodeWhenResampling(1);
	$self->_set_useSoxToEncodeWhenResampling(1);

	$self->_set_useFFMpegToSplit(1);
	$self->_set_useFFMpegToTranscode(1);
	
	$self->_set_useFAADToSplit(0);
	
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
		
		#Always encode to FLAC (0 compresion).
		$commandString=$self->_splitUsingFlac($transcodeTable);
	}
	Plugins::C3PO::Logger::debugMessage('command: '.$commandString);
	return $commandString;
}
sub decodeBeforeResampling{
	my $self = shift;
	my $transcodeTable=shift;
	
	return "";
}
sub splitAndEncode{

	my $self = shift;
	my $transcodeTable=shift;
	
	my $outCodec=$self->getOutputCodec($transcodeTable);
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('splitAndEncode to $outCodec');
	
	if ($self->compareCodecs($outCodec, 'flc')){
		
		#Encode to FLAC, final compression, FFMPEG can't.
		$commandString = $self->_splitAndEncodeUsingFlac($transcodeTable);
	
	} elsif ($self->useFFMpegToSplit($transcodeTable)){
		
		#could encode directly to outcodec, if useFFMpegToTranscode
		$commandString=$self->_splitAndEncodeUsingFfmpeg($transcodeTable);
		
	} else {
		#always encode to flac (0 compression) wil be transcoded to $outcodec in 
		#a further step (normally using sox).)
		$commandString=$self->_splitUsingFlac($transcodeTable);
	}
	Plugins::C3PO::Logger::debugMessage('command: '.$commandString);
	return $commandString;

}
################################################################################
# Protected methods.
################################################################################

sub transcodeToWav{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandstring;
	
	if ($self->_useFFMpegToTranscode($transcodeTable)){
		
		$commandstring = Plugins::C3PO::FfmpegHelper::transcode($transcodeTable);
		
	} else {
	
		$commandstring = Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	}
	return $commandstring;
}
sub transcodeToAiff{
	my $self = shift;
	my $transcodeTable=shift;

	return "";
}
sub transcodeToFlac{
	my $self = shift;
	my $transcodeTable=shift;
	
	if ($self->isLMSInfo()) {
		$self->getLog()->info('command '.$transcodeTable->{'command'});
	} else{
		Plugins::C3PO::Logger::debugMessage('command '.$transcodeTable->{'command'});
	}
	
	my $commandstring=Plugins::C3PO::FlacHelper::encode($transcodeTable);
	
	return $commandstring;
}
1;