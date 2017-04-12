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

package Plugins::C3PO::AudioFile;

use strict;
use warnings;

use Audio::Scan;

###############################################################################
# log system
###############################################################################

my $logger;
my $log;

sub isLMSDebug{
	my $self = shift;
	
	if ($logger && $logger->{DEBUGLOG} && $log && $log->is_debug) {return 1}
	return 0;
}
sub isLMSInfo{
	my $self = shift;
	
	if (isLMSDebug()) {return 1;}
	if ($logger && $logger->{INFOLOG} && $log && $log->is_info) {return 1}
	return 0;
}
sub getLog{
	my $self = shift;
	
	return $log;
}
###############################################################################
# constructor
###############################################################################
sub new { 
	my $class   = shift; 
    my $file    = shift; 
	$logger     = shift;
	$log        = shift;

	my $self = {  
        _file => $file,
        _error => undef,
        _samplerate => undef,
        _bits_per_sample => undef,
        _isDsd => undef,
        _fileInfo =>undef,
        _info => undef,
        _tags => undef,
    }; 
	bless $self, $class;

    if (!-e $file)  {$self->{_error} = "file $file does not exists"; return $self;}
    if (!-r $file)  {$self->{_error} = "can't read $file"; return $self;}

    my $fileInfo= Audio::Scan->scan($file);

    $self->{_samplerate}        = $fileInfo->{info}->{samplerate};
    $self->{_bits_per_sample}   = $fileInfo->{info}->{bits_per_sample};
    $self->{_isDsd}             = ( $self->{_bits_per_sample} && ( $self->{_bits_per_sample} == 1)) ? 1 :0;
    $self->{_fileInfo}          = $fileInfo;
    $self->{_info}              = $fileInfo->{info};
    $self->{_tags}              = $fileInfo->{tags};
    
    if (!$self->{_samplerate}) {$self->{_error} = "$file is not an audio file"}
    
    return $self;
}

################################################################################
# public methods
################################################################################

sub toString{
	my $self  = shift;
	my $class = ref($self) || $self;
	
	return $class;
}

sub getFile{
	my $self  = shift;
		
	return  $self->{_file} ;
}

sub getError{
	my $self  = shift;
		
	return  $self->{_error} ;
}

sub getSamplerate{
	my $self  = shift;
		
	return  $self->{_samplerate} ;
}
sub _getBitsPerSample{
	my $self  = shift;
		
	return  $self->{_bits_per_sample} ;
}

sub isDsd{
	my $self  = shift;
		
	return  $self->{_isDsd} ;
}

sub getFileInfo{
	my $self  = shift;
		
	return  $self->{_fileInfo} ;
}
################################################################################
# Additional methods.
################################################################################
sub getInfo{
	my $self  = shift;
		
	return  $self->{_info} ;
}
sub getTags{
	my $self  = shift;
		
	return  $self->{_tags} ;
}
1;