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

package Plugins::C3PO::Formats::Format;

use strict;
use warnings;
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
# settings to be defined in the Subclass constructor.
###############################################################################

my $p_isCompressedCodec;
my $p_useSoxToTranscodeWhenResampling;
my $p_useSoxToEncodeWhenResampling;

my $p_useFFMpegToSplit;
my $p_useFAADToSplit;

my $p_useFFMpegToTranscode;

###############################################################################
# constructor
###############################################################################
sub new { 
	my $class = shift; 
	$logger = shift;
	$log = shift;

	my $self = { }; 
	bless $self, $class; 
	return $self;
}
################################################################################
# public Settings getters
################################################################################

sub isCompressedCodec{
	my $self = shift;
	return $p_isCompressedCodec;
}

# usefull when resampling and decoding but splitting is not required, in order 
# to avoid chains like FLAC | SOX.
sub useSoxToTranscodeWhenResampling {
	my $self = shift;
	return $p_useSoxToTranscodeWhenResampling;
}

#NOT TO BE USED with ALAC input.	
# encode to the output codec  while resampling, 
# no meaning if not resampling. Used to avoid chains like xxx |SOX | FLAC 
sub useSoxToEncodeWhenResampling {
	my $self = shift;
	return $p_useSoxToEncodeWhenResampling;
}
sub useFFMpegToSplit {
	my $self = shift;
	my $transcodeTable=shift;
	
	# use ffmpeg instead of flac or faad to split files when usin cue sheets.
	# needs ffmpeg to be installed, if not will use flac or faad.

	if (! $self->_isFfmpegInstalled($transcodeTable)) {return 0};
	return $p_useFFMpegToSplit;
}
sub useFAADToSplit{
	my $self = shift;
	my $transcodeTable=shift;
	
	# use faad to split files when using cue sheets.
	# not sure it works, but is only for Alac.

	return $p_useFAADToSplit;
}
################################################################################
# protected  Settings getters
################################################################################

sub _useFFMpegToTranscode {
	my $self = shift; 
	my $transcodeTable = shift;
	
	# decode to $outcodec when splitting or
	# when trascoding at the end, if not done by sox wile resampling.
	# needs ffmpeg to be installed.

	if (! $self->_isFfmpegInstalled($transcodeTable)) {return 0};
	return $p_useFFMpegToTranscode;
}

################################################################################
# protected  Settings setters
################################################################################
sub _set_isCompressedCodec{
	my $self = shift; 
	$p_isCompressedCodec = shift;
};
sub _set_useSoxToTranscodeWhenResampling{	
	my $self = shift; 
	$p_useSoxToTranscodeWhenResampling = shift;
};
sub _set_useSoxToEncodeWhenResampling{	
	my $self = shift; 
	$p_useSoxToEncodeWhenResampling = shift;
};
sub _set_useFFMpegToSplit{
	my $self = shift; 
	$p_useFFMpegToSplit = shift;
};
sub _set_useFFMpegToTranscode{
	my $self = shift; 
	$p_useFFMpegToTranscode = shift;
};
sub _set_useFAADToSplit{
	my $self = shift; 
	$p_useFAADToSplit = shift;
};

################################################################################
# private Settings to be moved to subclasses
################################################################################
#TO BE USED ONLY with FLAC output.

sub useFlacToFinalEncode{

	# transcode to flac at the end if requested and not upsampling
	# If not will use sox.
	
	return 1;
}
################################################################################
# public methods
################################################################################
sub toString{
	my $self  = shift;
	my $class = ref($self) || $self;
	
	return $class;
}
sub transcode {
	my $self = shift; 
	my $transcodeTable = shift;
	
	my $commandString="";
	my $outCodec = $self->getOutputCodec($transcodeTable);
	
	Plugins::C3PO::Logger::debugMessage("transcode to $outCodec");
	
	if ($self->compareCodecs($outCodec,'wav')){
		
		$commandString=$self->transcodeToWav($transcodeTable);
		
	} elsif ($self->compareCodecs($outCodec,'aif')){
		
		$commandString=$self->transcodeToAiff($transcodeTable);
	
	} elsif ($self->compareCodecs($outCodec,'flc')){
		
		$commandString=$self->transcodeToFlac($transcodeTable);
		
	}elsif ($self->compareCodecs($outCodec,'dsf')){
		
		$commandString=$self->transcodeToDsf($transcodeTable);
	
	}elsif ($self->compareCodecs($outCodec,'dff')){
		
		$commandString=$self->transcodeToDff($transcodeTable);
	
	}else {
		Plugins::C3PO::Logger::errorMessage('invalid output codec: '.$outCodec);
		die;
	}
	$transcodeTable->{'transitCodec'}=$outCodec;
	return $commandString;
}

################################################################################
# public methods to be overridden by subclasses
################################################################################
sub splitBeforeResampling {
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: splitBeforeResampling MUST be define for any and each format');
	die;
}
sub decodeBeforeResampling{
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: decodeBeforeResampling MUST be define for any and each format');
	die;
}
sub splitAndEncode {
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: splitAndEncode MUST be define for any and each format');
	die;
}
sub decode {
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: decode MUST be define for any and each format');
	die;
}

################################################################################
# protected methods
################################################################################

sub _isFfmpegInstalled{
	my $self = shift;
	my $transcodeTable=shift;
	
	if (!defined $transcodeTable->{'pathToFFmpeg'}) {return 0};
	return 1;
}
sub _splitAndEncodeUsingFfmpeg{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('splitUsingFfmpeg');

	if ($self->_useFFMpegToTranscode($transcodeTable)){
	
		#decode to $outcodec..
		Plugins::C3PO::Logger::debugMessage('_useFFMpegToTranscode');
		$transcodeTable->{'transitCodec'}=$self->getOutputCodec($transcodeTable);
		
	} else{
		#decode to WAV.
		$transcodeTable->{'transitCodec'}='wav';		
	}
	
	$commandString=Plugins::C3PO::FfmpegHelper::split_($transcodeTable);
	return $commandString;
}
sub _splitUsingFfmpeg{
	my $self = shift;
	my $transcodeTable=shift;
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('splitUsingFfmpeg');
	#Always decode to WAV.
	$transcodeTable->{'transitCodec'}='wav';		
	$commandString=Plugins::C3PO::FfmpegHelper::split_($transcodeTable);
	return $commandString;
}
sub _splitAndEncodeUsingFlac{
	my $self = shift;
	my $transcodeTable=shift;

	my $commandString="";
	Plugins::C3PO::Logger::debugMessage('splitUsingFlac');

	#encode to flac final compression and split.
	$transcodeTable->{'transitCodec'}='flc';		
	$commandString=Plugins::C3PO::FlacHelper::encode($transcodeTable);
	return $commandString;	
}
sub _splitUsingFlac{
	my $self = shift;
	my $transcodeTable=shift;

	my $commandString="";
	Plugins::C3PO::Logger::debugMessage('splitUsingFlac');
	
	my $compression=$transcodeTable->{'outCompression'};	
	$transcodeTable->{'outCompression'}=0;

	#encode to FLAC (0 compresion).
	$transcodeTable->{'transitCodec'}='flc';		
	$commandString=Plugins::C3PO::FlacHelper::encode($transcodeTable);
	
	$transcodeTable->{'outCompression'}=$compression;
	return $commandString;
}

sub native{
    my $self = shift; 
    my $transcodeTable = shift;
    
    # does not work in windows.
    #return $self->_dummyTranscoder($transcodeTable); 

    return Plugins::C3PO::SoxHelper::transcode($transcodeTable);
}

################################################################################
# protected methods to be overridden by subclasses
################################################################################
sub transcodeToWav{
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: transcodeToWav MUST be define for any and each format');
	die;
}
sub transcodeToAiff{
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: transcodeToAiff MUST be define for any and each format');
	die;
}

sub transcodeToFlac{
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: transcodeToFlac MUST be define for any and each format');
	die;
}
sub transcodeToDsf{
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: transcodeToDsf MUST be define for any and each format');
	die;
}
sub transcodeToDff{
	my $self = shift;
	my $transcodeTable=shift;
	Plugins::C3PO::Logger::errorMessage('$self: transcodeToDff MUST be define for any and each format');
	die;
}

################################################################################
# methods from Transacoder, to be moved in a separate class (see Transcoder)).
################################################################################
sub getOutputCodec{
	my $self = shift; 
	my $transcodeTable=shift;
	
	return Plugins::C3PO::Transcoder::getOutputCodec($transcodeTable);
}
sub compareCodecs{
	my $self = shift; 

	return Plugins::C3PO::Transcoder::compareCodecs(@_);
}
################################################################################
# Private methods.
################################################################################

sub _dummyTranscoder{ # does not works in windows.
    my $self = shift; 
    my $transcodeTable = shift;
	
	my $willStart				 = $transcodeTable->{'C3POwillStart'};
	my $pathToPerl				 = $transcodeTable->{'pathToPerl'};
	
	my $pathToHeaderRestorer_pl	 = $transcodeTable->{'pathToC3PO_pl'};
	my $pathToHeaderRestorer_exe = $transcodeTable->{'pathToC3PO_exe'} || "";

	my $prefFile				 = $transcodeTable->{'pathToPrefFile'};
	my $logFolder				 = $transcodeTable->{'logFolder'};
	my $serverFolder			 = $transcodeTable->{'serverFolder'};

	my $commandString= "";

	if ($willStart eq 'pl'){
		
			$commandString =  qq("$pathToPerl" "$pathToHeaderRestorer_pl" );
							  
			
	} else {
			
			$commandString =  qq("$pathToHeaderRestorer_exe" );
	}

	$commandString = $commandString
					 .qq(-b -p "$prefFile" -l "$logFolder" -x "$serverFolder");
	
	#Copy debug settngs.
	if (! main::DEBUGLOG) {
		$commandString = $commandString." --nodebuglog";
	}
	
	if (! main::INFOLOG) {
		$commandString = $commandString." --noinfolog";
	}

    return $commandString;
}


1;