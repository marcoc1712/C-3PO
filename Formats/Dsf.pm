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

package Plugins::C3PO::Formats::Dsf;

use strict;
use warnings;
use base qw(Plugins::C3PO::Formats::Format);

sub new { 

	my $class = shift; 
	my $self = $class->SUPER::new(@_);

	$self->_set_isCompressedCodec(0);
	$self->_set_useSoxToTranscodeWhenResampling(1);
	$self->_set_useSoxToEncodeWhenResampling(1);

	$self->_set_useFFMpegToSplit(0);
	$self->_set_useFFMpegToTranscode(0);
	
	$self->_set_useFAADToSplit(0);
		
	return $self;
}

################################################################################
# public methods
################################################################################

sub splitBeforeResampling {
	my $self = shift;
	my $transcodeTable=shift;

	#I'm not aware of any tool to split dsd files
	return "";
}
sub decodeBeforeResampling{
	my $self = shift;
	my $transcodeTable=shift;
	
	#dsd always ned sox downsampling, never transcode
	return "";

}
sub splitAndEncode{

	my $self = shift;
	my $transcodeTable=shift;
	
	#dsd always ned sox downsampling, never transcode
	return "";

}
################################################################################
# Protected methods.
################################################################################

sub transcodeToWav{
	my $self = shift;
	my $transcodeTable=shift;
	
	#dsd always ned sox downsampling, never transcode
	return "";
}
sub transcodeToAiff{
	my $self = shift;
	my $transcodeTable=shift;
	
	#dsd always ned sox downsampling, never transcode
	return "";
}

sub transcodeToFlac{
	my $self = shift;
	my $transcodeTable=shift;

	#dsd always ned sox downsampling, never transcode
	return "";
}
################################################################################
# Private methods.
################################################################################
1;