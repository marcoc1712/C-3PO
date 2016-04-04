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

package Plugins::C3PO::inCodec::inCodec;

use strict;
use warnings;

my $logger;
my $log;

sub new { 
	my $class = shift; 
	$logger = shift;
	$log = shift;
	
	my $self = { }; 
	bless $self, $class; 
	return $self;
}

sub isLMSDebug{
	my $class = shift;
	if ($logger && $logger->{DEBUGLOG} && $log && $log->is_debug) {return 1}
	return 0;
};
sub isLMSInfo{
	my $class = shift;
	if (isLMSDebug()) {return 1;}
	if ($logger && $logger->{INFOLOG} && $log && $log->is_info) {return 1}
	return 0;
};

#use Data::Dump;

#####################################################################
# flow control - Double check when adding support for codecs.
#####################################################################

#TODO: using FLAC to split an AIF file then upsampled by SOX, sometime do not 
#work, at 192k (sox raise to 50% CPU). No probs at 176400.
#
sub getOutputCodec{
	my $class = shift;
	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec= $transcodeTable->{'outCodec'};
	
	if ($transcodeTable->{'enableConvert'}->{$inCodec}){return $outCodec;}
	
	if ($transcodeTable->{'enableResample'}->{$inCodec} && 
	    compareCodecs($inCodec, 'alc')){return $outCodec;}

	return $inCodec;
}

sub isCompressedCodec{
	my $codec= shift;

	if (compareCodecs($codec, 'flc')) {return 1};
	if (compareCodecs($codec, 'alc')) {return 1};
	
	return 0;
}
#TODO: using FLAC to split an AIF file then upsampled by SOX, sometime do not 
#work, at 192k (sox raise to 50% CPU). No probs at 176400.
#
sub useFFMpegToSplit{

	# use ffmpeg instead of flac or faad to split files when usin cue sheets.
	# needs ffmpeg to be installed, if not will use flac or faad.
	
	my $transcodeTable =shift;
	
	if (!defined $transcodeTable->{'pathToFFmpeg'}) {return 0};
	
	#in runtime use transitCodec instead of inCodec.
	my $inCodec= isRuntime($transcodeTable) 
		? $transcodeTable->{'transitCodec'} : $transcodeTable->{'inCodec'};
 
	if (compareCodecs($inCodec, 'wav')) {return 1};
	if (compareCodecs($inCodec, 'aif')) {return 1};
	if (compareCodecs($inCodec, 'alc')) {return 0};
	if (compareCodecs($inCodec, 'flc')) {return 0};

	return 0;
}
sub useFAADToSplit {
	my $transcodeTable =shift;

	my $inCodec= isRuntime($transcodeTable) ? $transcodeTable->{'transitCodec'} 
											: $transcodeTable->{'inCodec'};
		
	if (useFFMpegToSplit($transcodeTable)) {return 0;}
	
	if (compareCodecs($inCodec, 'wav')) {return 0};
	if (compareCodecs($inCodec, 'aif')) {return 0};
	if (compareCodecs($inCodec, 'alc')) {return 1};
	if (compareCodecs($inCodec, 'flc')) {return 0};
	
	return 0;
	}

sub useFFMpegToTranscode {
	
	# decode to $outcodec when splitting or
	# when trascoding at the end, if not done by sox wile resampling.
	# needs ffmpeg to be installed, if not will use sox.
	
	my $transcodeTable =shift;
	
	if (!defined $transcodeTable->{'pathToFFmpeg'}) {return 0};
	
	my $inCodec= $transcodeTable->{'transitCodec'};
	my $outcodec= getOutputCodec($transcodeTable);
	
	# avoid to encode before upsampling.
	if (isCompressedCodec($outcodec)) {return 0};
	
	if (compareCodecs($inCodec, 'wav')) {return 1};
	if (compareCodecs($inCodec, 'aif')) {return 1};
	if (compareCodecs($inCodec, 'alc')) {return 0};
	if (compareCodecs($inCodec, 'flc')) {return 0};
	
	return 0;
}
sub useFlacToDecodeWhenSplitting {

	# decode to $outcodec when splitting, no meaning if not splitting.
	# if not ALWAIS output WAV.

	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=getOutputCodec($transcodeTable);

	if (!compareCodecs($inCodec, 'flc')) {return 0};
	
	return 0; # AIF will not worlk with 1. See FlacTranscode.
}
sub useSoxToDecodeWhenResampling {
	
	# decode from input codec wile resampling, 
	# no meaning if not resampling or splitting
	
	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	
	if (compareCodecs($inCodec, 'alc')) {return 0};
	if (compareCodecs($inCodec, 'flc')) {return 1};
	if (compareCodecs($inCodec, 'wav')) {return 1};
	if (compareCodecs($inCodec, 'aif')) {return 1};
	
	return 1;
}
sub useSoxToEncodeWhenResampling {
	
	# encode to the output codec wile resampling, 
	# no meaning if not resampling.
	
	my $transcodeTable =shift;

	return 1;
}

sub useFlacToFinalEncode{

	# transcode to flac at the end if requested and not upsampling
	# If not will use sox.
	
	return 1;
}
###################

sub enableStdin{

	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	
	my $enable = $transcodeTable->{'enableStdin'}->{$inCodec} ? 1 : 0;
	Plugins::C3PO::Logger::debugMessage("codec: $inCodec - enableStdin: $enable");
	
	return $enable;
}
sub enableSeek{

	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	
	my $enable = $transcodeTable->{'enableSeek'}->{$inCodec} ? 1 : 0;
	Plugins::C3PO::Logger::debugMessage("codec: $inCodec - enableSeek: $enable");
	
	return $enable;
}

sub needRestoreHeader{
	my $transcodeTable =shift;
	
	my $testFile=$transcodeTable->{'testfile'};
	
	return (defined $testFile);

}
sub getTestFile{
	my $transcodeTable =shift;
	
	my $fileName = "header.".$transcodeTable->{'inCodec'};
	my $outfile  = Plugins::C3PO::OsHelper::getTemporaryFile($fileName);
		
	Plugins::C3PO::Logger::debugMessage('out file : '.$outfile);
	
	saveHeaderFile(\*STDIN, $outfile);
	
	Plugins::C3PO::Logger::debugMessage('returning : '.$outfile);
	return $outfile;
}

sub saveHeaderFile{
	my $fh = shift;
	my $testHeaderFile = shift;
	
	my $head = FileHandle->new;
	$head->open("> $testHeaderFile") or die $!;
	binmode ($head);

	my $headbuffer;

	if (
		sysread ($fh, $headbuffer, 8192)	# read in (up to) 8192 bit chunks, write
		and syswrite $head, $headbuffer	# exit if read or write fails
	  ) {};
	  die "Problem writing: $!\n" if $!;

	flush $head;
	close $head;
	
	return 1;
}
################################################################################
sub isRuntime{
	my $transcodeTable =shift;

	return (defined $transcodeTable->{'options'}->{clientId} ? 1 : 0)
}
sub isNative{
	my $transcodeTable =shift;
	my $inCodec = $transcodeTable->{'inCodec'};
	
	if (! $transcodeTable->{'enableConvert'}->{$inCodec} &&
		! $transcodeTable->{'enableResample'}->{$inCodec}) {return 1;}
		
	return 0;
}
sub compareCodecs{
	my $Acodec= shift;
	my $Bcodec= shift;
	
	if ($Acodec eq 'pcm'){ $Acodec = 'wav';}
	if ($Bcodec eq 'pcm'){ $Bcodec = 'wav';}
	
	return ($Acodec eq $Bcodec);

}
sub isSplittingRequested{
	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	
	#if (!isResamplingRequested($transcodeTable) && 
	#	compareCodecs($inCodec, getOutputCodec($transcodeTable))){ return 0;}
	
	if (!isRuntime($transcodeTable) && 
	    $transcodeTable->{'enableSeek'}->{$inCodec}) {return 1;} 
	
	if  (defined $transcodeTable->{'options'}->{startTime}) {return 1;}  
	if  (defined $transcodeTable->{'options'}->{endTime}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{startSec}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{endSec}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{durationSec}){return 1;} 
	
	return 0;
}

sub isTranscodingRequested{
	my $transcodeTable =shift;
	my $inCodec		 = $transcodeTable->{'inCodec'};
	my $outCodec	 = getOutputCodec($transcodeTable);
	my $transitCodec = $transcodeTable->{'transitCodec'};
	
	if (!isRuntime($transcodeTable) && 
	    !compareCodecs($inCodec, $outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 1;}
	
	if (!isRuntime($transcodeTable)) {return 0;}
	
	# WAV -> WAV -> FLAC [v] -> 1
	if (compareCodecs($inCodec, $transitCodec) &&
	    !compareCodecs($inCodec, $outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 1;}
		
	# WAV -> WAV -> FLAC [ ] -> 0
	if (compareCodecs($inCodec, $transitCodec) &&
	    !compareCodecs($inCodec, $outCodec) &&
	    !$transcodeTable->{'enableConvert'}->{$inCodec}) {return 0;}
		
	# FLAC -> WAV -> FLAC [v] -> 1
	if (!compareCodecs($inCodec, $transitCodec) &&
		!compareCodecs($transitCodec, $outCodec) &&
		!compareCodecs($inCodec, $outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 1;}
	
	# FLAC -> WAV -> FLAC [v] -> 1
	if (!compareCodecs($inCodec, $transitCodec) &&
		!compareCodecs($transitCodec, $outCodec) &&
		!compareCodecs($inCodec, $outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 1;}

	# FLAC -> WAV -> FLAC [ ] -> 1
	if (!compareCodecs($inCodec, $transitCodec) &&
		!compareCodecs($transitCodec, $outCodec) &&
		!compareCodecs($inCodec, $outCodec) &&
	    !$transcodeTable->{'enableConvert'}->{$inCodec}) {return 1;}
		
	# FLAC -> WAV -> WAV [v] -> 1
	if (!compareCodecs($inCodec, $transitCodec) &&
		compareCodecs($transitCodec, $outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 0;}
	
	# FLAC -> WAV -> WAV [v] -> 0
	if (!compareCodecs($inCodec, $transitCodec) &&
		compareCodecs($transitCodec, $outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 0;}
	
	# WAV -> FLAC -> AIF [v] -> 1
	if (!compareCodecs($inCodec, $transitCodec) &&
		!compareCodecs($transitCodec, $outCodec) &&
		!compareCodecs($inCodec,$outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 1;}
	
	# WAV -> FLAC -> AIF [ ] -> 1
	if (!compareCodecs($inCodec, $transitCodec) &&
		!compareCodecs($transitCodec, $outCodec) &&
		!compareCodecs($inCodec, $outCodec) &&
	    !$transcodeTable->{'enableConvert'}->{$inCodec}) {return 0;}
		
	# WAV -> WAV -> WAV [v] -> 0
	if (compareCodecs($inCodec, $transitCodec) &&
		compareCodecs($transitCodec, $outCodec) &&
	    $transcodeTable->{'enableConvert'}->{$inCodec}) {return 0;}
	
	# WAV -> WAV -> WAV [ ] -> 0
	if (compareCodecs($inCodec, $transitCodec)&&
		compareCodecs($transitCodec, $outCodec) &&
	    !$transcodeTable->{'enableConvert'}->{$inCodec}) {return 0;}
	
	# fault back.
	
	$inCodec= $transcodeTable->{'transitCodec'};
	return (compareCodecs($inCodec, $outCodec));
}

sub isResamplingRequested{
	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	
	if (!$transcodeTable->{'enableResample'}->{$inCodec}) {return 0;}
	return !($transcodeTable->{'resampleWhen'} eq 'N');
}
sub willResample{
	my $transcodeTable=shift;
	
	if (!isResamplingRequested($transcodeTable)) {return 0;}
	#be sure to call checkResample before.
	
	# Keep it short and always resample if asked for.
	#return 1;

	#Always resample if any extra effects is requested.
	if ($transcodeTable->{'extra'} && !($transcodeTable->{'extra'} eq "")) {return 1;}

	my $targetSamplerate=$transcodeTable->{'targetSamplerate'};
	my $fileSamplerate = $transcodeTable->{'fileInfo'}->{info}->{samplerate};
	
	Plugins::C3PO::Logger::verboseMessage("targetSamplerate: ". defined $targetSamplerate ? $targetSamplerate : 'undef');
	Plugins::C3PO::Logger::verboseMessage("fileSamplerate: ". defined $fileSamplerate ? $fileSamplerate : 'undef');

	if (!defined $targetSamplerate) {return 0;}
	if (!$fileSamplerate || !($fileSamplerate == $targetSamplerate)){return 1;}
	
		
	my $targetBitDepth = $transcodeTable-{'outBitDepth'};
	my $fileBitDepth   = $transcodeTable->{'fileInfo'}->{info}->{bits_per_sample} ? 
							$transcodeTable->{'fileInfo'}->{info}->{bits_per_sample}/8 :
							undef;
	
	Plugins::C3PO::Logger::verboseMessage("targetBitDepth: ". defined $targetBitDepth ? $targetBitDepth : 'undef');
	Plugins::C3PO::Logger::verboseMessage("fileBitDepth: ". defined $fileBitDepth ? $fileBitDepth : 'undef');
	
	if (!defined $targetBitDepth) {return 0;}
	if (!$fileBitDepth || !($fileBitDepth == $targetBitDepth)){return 1;}
	
	return 0;
}
sub isOutputCompressed{
	my $transcodeTable =shift;
	my $outCodec= getOutputCodec($transcodeTable);
    return isCompressedCodec($outCodec);
}
sub isInputCompressed{
	my $transcodeTable =shift;	
	my $inCodec= $transcodeTable->{'inCodec'};
	return isCompressedCodec($inCodec);
}
sub isAStdInPipe {
	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	
	if (!isRuntime($transcodeTable) && 
	    $transcodeTable->{'enableStdin'}->{$inCodec}) {return 1;} 
	
	if (!isRuntime($transcodeTable)) {return 0;} 
	
	if (!defined $transcodeTable->{'options'}->{'file'} ||
		$transcodeTable->{'options'}->{'file'} eq '' ||
		$transcodeTable->{'options'}->{'file'} eq '-'){
		
		return 1;
	}	
	return 0;
}
###############################################################################
# Routines to be integrated when support for codecs is added.
###############################################################################

sub splitAndDecodeCompressedInput {
	my $transcodeTable=shift;
	
	my $inCodec	= $transcodeTable->{'inCodec'};
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('splitAndDecodeCompressedInput - $inCodec '.$inCodec);
	
	if (compareCodecs($inCodec, 'flc' )) {

		#decode and split with flac.
		if (useFlacToDecodeWhenSplitting($transcodeTable)){

			$transcodeTable->{'transitCodec'}=getOutputCodec($transcodeTable);
			# See useFlacToDecodeWhenSplitting

		} else {

			# wav is the defauld option for FLAC.
			$transcodeTable->{'transitCodec'}='wav';	

		}
		$commandString=Plugins::C3PO::FlacHelper::decode($transcodeTable);

	} elsif (compareCodecs($inCodec, 'alc' )){
				
		if (useFFMpegToSplit($transcodeTable)){
			
			Plugins::C3PO::Logger::debugMessage('$inCodec '.$inCodec.' use FFMpeg To Split');
			
			if (useFFMpegToTranscode($transcodeTable)){
					
				Plugins::C3PO::Logger::debugMessage(
					'$inCodec '.$inCodec.' use FFMpeg To Decode to '.getOutputCodec($transcodeTable));

				$transcodeTable->{'transitCodec'}=getOutputCodec($transcodeTable);
			}
			
			# ELSE $transcodeTable->{'transitCodec'}=$transcodeTable->{'inCodec'};
			
			$commandString=Plugins::C3PO::FfmpegHelper::split_($transcodeTable);
			
		} else {
		
			Plugins::C3PO::Logger::debugMessage('$inCodec '.$inCodec.' use faad');
		
			# wav is the defauld option for FAAD.
			$transcodeTable->{'transitCodec'}='wav';	
			$commandString=Plugins::C3PO::FaadHelper::decode($transcodeTable);
			
			Plugins::C3PO::Logger::debugMessage('$commandString '.$commandString);
		}
	}
	# add here other compressed codecs.
	Plugins::C3PO::Logger::debugMessage('$commandString '.$commandString);
	return $commandString;
}

sub splitAndEndcodeUnCompressedInputUsingFlac {
	
	# We need FLAC s output.
	
	my $transcodeTable=shift;
	
	Plugins::C3PO::Logger::verboseMessage('Start splitAndEndcodeUnCompressedInputUsingFlac');
	
	my $commandString="";
	
	#encode and split with flac.
	$transcodeTable->{'transitCodec'}='flc';		

	my $compression=$transcodeTable->{'outCompression'};	
	$transcodeTable->{'outCompression'}=0;
	$commandString=Plugins::C3PO::FlacHelper::encode($transcodeTable);
	$transcodeTable->{'outCompression'}=$compression;
	
	return $commandString;
}

sub transcodeCompressedOutput{

	# We need FLAC s output.
	
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::verboseMessage('Start transcodeCompressedOutput');
	
	my $inCodec=$transcodeTable->{'transitCodec'};
	my $outCodec = getOutputCodec($transcodeTable);
	
	Plugins::C3PO::Logger::verboseMessage('Start transcode');

	my $commandstring="";
	
	if (compareCodecs($outCodec, 'flc') && useFlacToFinalEncode($transcodeTable)){

		$commandstring = Plugins::C3PO::FlacHelper::encode($transcodeTable);
	
	} else {
	
		$commandstring = Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	}
	return $commandstring;
}
sub normalizeCodecs{
	my $transcodeTable =shift;

	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=getOutputCodec($transcodeTable);
	
	if ($transcodeTable->{'inCodec'} eq 'pcm'){ 

		$transcodeTable->{'inCodec'}='wav';
	}
	
	if ($transcodeTable->{'outCodec'} eq 'pcm'){ 

		$transcodeTable->{'outCodec'}='wav';
	
	} 
	return $transcodeTable;
}
#####################################################################
# Plugin entry point
#####################################################################

sub initTranscoder{
	my $transcodeTable= shift;
	$logger= shift;
	
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'};}
	
	if (isLMSDebug()) {
		$log->debug("Using LMS DEBUG log.");
	}
	if (isLMSInfo()) {
		$log->info("Using LMS INFO log.");
	}
	
	Plugins::C3PO::Logger::debugMessage('Start initTranscoder');
	
	my $commandTable={};
	my $codecs=$transcodeTable->{'codecs'};

	for my $codec (keys %$codecs){
		
		if (!$codecs->{$codec}) {next;}
		
		my $cmd={};
		
		$transcodeTable->{'inCodec'}=$codec;

		if (ceckC3PO($transcodeTable)){
			
			Plugins::C3PO::Logger::debugMessage('Use C3PO');
			$cmd=useC3PO($transcodeTable);
			#Data::Dump::dump ($cmd);

		} else {
		
			Plugins::C3PO::Logger::debugMessage('Use Server');	
			$cmd=useServer($transcodeTable);
			#Data::Dump::dump ($cmd);
		}
		
		if ($cmd && !$cmd->{'error'}){

			$commandTable->{$cmd->{'profile'}}= $cmd;

		} else {
			
			printlog(	"PROFILE: Name        : ".$cmd->{'profile'}."\n".
						"         Error       : ".$cmd->{'error'}."\n");
		}
	}
	return $commandTable;
}
sub ceckC3PO{
	my $transcodeTable= shift;
	my $willStart=$transcodeTable->{'C3POwillStart'};
	my $codec = $transcodeTable->{'inCodec'};
	
	if (!((defined $willStart) &&
		  (($willStart eq 'pl') ||($willStart eq 'exe')))){

		#Fault back, resample to max supported samplerate.
		$transcodeTable->{'resampleTo'}='X';
		$transcodeTable->{'resampleWhen'}='A';
		return 0;
	}
	
	# safety
	if (isRuntime($transcodeTable)) {return 0;}
	
	# In windows I does not works insiede C3PO, so it's disabled.
	if (main::ISWINDOWS &&
	    enableStdin($transcodeTable) &&
	    (($transcodeTable->{'resampleWhen'} eq 'E') || 
	     ($transcodeTable->{'resampleTo'} eq 'S'))){
		 
		return 0;
	}
		
	# there is nothing to do, native.
	if (isNative($transcodeTable)) {return 0;}

	# ELIMINARE PER USARE C-3PO quando possibile.
	if ($transcodeTable->{'enableResample'}->{$codec} &&
		$transcodeTable->{'resampleTo'} eq 'X') {return 0;}
		
	return 1;

}
sub buildProfile{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::debugMessage('Start buildProfile');
	
	my $macaddress= $transcodeTable->{'macaddress'};
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=getOutputCodec($transcodeTable);

	# pcm/wav misuse...
	if (compareCodecs($inCodec,'wav')){$inCodec='wav'};
	
	if (compareCodecs($inCodec, 'aif') && compareCodecs($outCodec, 'wav')){
		
		{$outCodec='aif'};
		
	} elsif (compareCodecs($outCodec, 'wav')) {
	
		$outCodec='pcm'
	};

	# wav-pcm-*-xx:xx:xx:xx:xx:xx
	return $inCodec.'-'.$outCodec.'-*-'.$macaddress;
}

sub useC3PO{
	my $transcodeTable= shift;

	Plugins::C3PO::Logger::debugMessage('Start useC3PO');
	
	my $result={};

	my $macaddress= $transcodeTable->{'macaddress'};
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=getOutputCodec($transcodeTable);
	my $prefFile = $transcodeTable->{'pathToPrefFile'};
	my $pathToC3PO_pl = $transcodeTable->{'pathToC3PO_pl'};
	my $logFolder = $transcodeTable->{'logFolder'};
	my $serverFolder = $transcodeTable->{'serverFolder'};
	
	
	$result->{'profile'} =  buildProfile($transcodeTable);
	
	my $command="";
	
	my $willStart=$transcodeTable->{'C3POwillStart'};
	
	if ($willStart eq 'pl'){
		
			$command =  qq([perl] "$pathToC3PO_pl").' -c $CLIENTID$ ';
			
	} else {
			
			$command =  '[C-3PO] -c $CLIENTID$ ';
	}
	if (isLMSInfo()) {
		$log->info("serverfolder. ".$serverFolder);
	}
	
	$command = $command.qq(-p "$prefFile" -l "$logFolder" -x "$serverFolder" -i $inCodec -o $outCodec )
					   .'$START$ $END$ $RESAMPLE$ $FILE$';
	
	if (! isLMSDebug()) {
		$command = $command." --nodebuglog";
	}
	
	if (! isLMSInfo()) {
		$command = $command." --noinfolog";
	}
		
	$result->{'command'}= $command;
	
	my $capabilities = { 
	#	I => 'noArgs',   # Qubuz or .cue, see below.
	#	I => 'FILE=-',   # Is the Daphile way, needs patch on LMS.
	#	F => 'FILE=-f %f', 
	#	R => 'FILE=-f %F', 
		F => 'noArgs', 
		R => 'noArgs', 
	#	T => 'START=-s %s', 
	#	U => 'END=-w %w', 
		D => 'RESAMPLE=-r %d' };
	
	#Enable stdIn pipes (Quboz) but disable seek (cue sheets)
	# In windows I does not works insiede C3PO, so it's disabled.)
	
	if(enableStdin($transcodeTable) && !main::ISWINDOWS){
	
	#if(enableStdin($transcodeTable)){}
		#Disabling this and enabling the followings LMS will use R capabilities and 
		# pass the Qobuz link to C3PO, but it does not works, needs the quboz plugin pipe 
		# to be activated via I.
		#
		$capabilities->{I}= 'noArgs';  
		#$capabilities->{T}='START=-s %s';
		#$capabilities->{U}='END=-w %w';
		
	} elsif (enableSeek($transcodeTable))  {

		$capabilities->{T}='START=-s %s';
		$capabilities->{U}='END=-w %w';
	}

	$result->{'capabilities'}=$capabilities;
	
	return $result;
}
sub useServer {
	my $transcodeTable= shift;

	Plugins::C3PO::Logger::debugMessage('Start useServer');

	my $result={};

	$result->{'profile'} =  buildProfile($transcodeTable);

	if (isNative($transcodeTable)) {
	
		$transcodeTable->{'capabilities'}={
				I => 'noArgs',
				F => 'noArgs',
			#	R => 'noArgs',
			#	F => 'FILE=-f %f',
			#	R => 'FILE=-f %F',
			#	T => 'START=-s %s', 
			#	U => 'END=-w %w',
			#	D => 'RESAMPLE=-r %d' };
		};
	
	} else{
	
		my $capabilities = { 
		#	I => 'noArgs',   # Qubuz or .cue, see below.
		#	I => 'FILE=-',   # Is the Daphile way, needs patch on LMS, don't work on standard
			F => 'noArgs',
			R => 'noArgs',
		#	F => 'FILE=-f %f',
		#	R => 'FILE=-f %F',
		#	T => 'START=-s %s', 
		#	U => 'END=-w %w',
			D => 'RESAMPLE=-r %d' };

		if(enableStdin($transcodeTable)){

			# cue files will always play from the beginning of first track.
			$capabilities->{I}= 'noArgs';

			# enabling the following, track > 1 in cue file will not play at all.
			#$capabilities->{T}='START=--skip=%t';
			#$capabilities->{U}='END=--until=%v';

		}elsif (enableSeek($transcodeTable) && useFFMpegToSplit($transcodeTable)){

			$capabilities->{T}='START=-ss %s';
			$capabilities->{U}='END=-t %w';

		} elsif (enableSeek($transcodeTable) && useFAADToSplit($transcodeTable)){

			$capabilities->{T}='START=-j %s';
			$capabilities->{U}='END=-e %u';

		} elsif (enableSeek($transcodeTable)){ #use flac

			$capabilities->{T}='START=--skip=%t';
			$capabilities->{U}='END=--until=%v';
		}

		$transcodeTable->{'capabilities'}=$capabilities;	
		
	}
	
	$transcodeTable= buildCommand($transcodeTable);
	$result->{'command'}=$transcodeTable->{'command'};
	$result->{'capabilities'}=$transcodeTable->{'capabilities'};
	
	return $result;
}

################################################################
# C-3PO entry point.
################################################################

sub buildCommand {
	my $transcodeTable = shift;
	
	#$transcodeTable = setOutputCodec($transcodeTable);
	
	my $command="";
	
	if (isLMSInfo()) {
		$log->info('Start buildCommand');
	} else{
	
		Plugins::C3PO::Logger::debugMessage('Start buildCommand');
	}
	
	$transcodeTable=normalizeCodecs($transcodeTable);
	
	if (isResamplingRequested($transcodeTable)) {
	
		$transcodeTable= checkResample($transcodeTable);
	}
	
	#save incodec.
	$transcodeTable->{'transitCodec'}=$transcodeTable->{'inCodec'};
	
	if (isLMSInfo()) {
		$log->info('inCodec: '.$transcodeTable->{'inCodec'});
		$log->info('transitCodec: '.$transcodeTable->{'transitCodec'});
		$log->info('outCodec: '.$transcodeTable->{'outCodec'});
		$log->info('Is resampling requested? '.isResamplingRequested($transcodeTable));
		$log->info('willResample ? '.willResample($transcodeTable));
		$log->info('Is splitting requested? '.isSplittingRequested($transcodeTable));
	} else{
		Plugins::C3PO::Logger::infoMessage('inCodec: '.$transcodeTable->{'inCodec'});
		Plugins::C3PO::Logger::infoMessage('transitCodec: '.$transcodeTable->{'transitCodec'});
		Plugins::C3PO::Logger::infoMessage('outCodec: '.$transcodeTable->{'outCodec'});
		Plugins::C3PO::Logger::infoMessage('Is resampling requested? '.isResamplingRequested($transcodeTable));
		Plugins::C3PO::Logger::infoMessage('willResample ? '.willResample($transcodeTable));
		Plugins::C3PO::Logger::infoMessage('Is splitting requested? '.isSplittingRequested($transcodeTable));
	}
	
	if (willResample($transcodeTable)){
	
		$transcodeTable=splitTranscodeAndResample($transcodeTable);
	
	} elsif (isSplittingRequested($transcodeTable)){
		
		$transcodeTable=splitAndTranscode($transcodeTable);

	} else {
		
		$transcodeTable=transcodeOnly($transcodeTable);
		$transcodeTable->{'command'}=$transcodeTable->{transcode};
	
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::infoMessage('Transcode command: '.$command);
	
	if ($command eq ""){
		
		if (isRuntime($transcodeTable)){

			# Using native to just pass IN to OUT.
			$transcodeTable = native($transcodeTable);

		} else {
			
			# Native
			$transcodeTable->{'command'}="-";		
		}
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::infoMessage('Safe command    : '.$command);
	
	if (needRestoreHeader($transcodeTable)){
	
		$transcodeTable = restoreHeader($transcodeTable);
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::infoMessage('Final command    : '.$command);
	return $transcodeTable;
}
sub native{
	my $transcodeTable = shift;
	
	# maybe transcoding and/or resampling was requested but is not needed
	# and we could not issue an ampty command from C-3PO.
	# let's have a 'dummy' transcoding.
	
	my $commandstring=_transcode($transcodeTable);
	$transcodeTable->{'command'}=$commandstring;
	
	return $transcodeTable;
}
sub restoreHeader{
	my $transcodeTable = shift;
	
	my $willStart				 = $transcodeTable->{'C3POwillStart'};
	my $pathToPerl				 = $transcodeTable->{'pathToPerl'};
	#my $pathToHeaderRestorer_pl	 = $transcodeTable->{'pathToHeaderRestorer_pl'};
	#my $pathToHeaderRestorer_exe = $transcodeTable->{'pathToHeaderRestorer_exe'} || "";
	
	my $pathToHeaderRestorer_pl	 = $transcodeTable->{'pathToC3PO_pl'};
	my $pathToHeaderRestorer_exe = $transcodeTable->{'pathToC3PO_exe'} || "";
	my $testfile				 = $transcodeTable->{'testfile'} || "";

	my $prefFile				 = $transcodeTable->{'pathToPrefFile'};
	my $logFolder				 = $transcodeTable->{'logFolder'};
	my $serverFolder			 = $transcodeTable->{'serverFolder'};

	my $commandString= "";

	if ($willStart eq 'pl'){
		
			$commandString =  qq("$pathToPerl" "$pathToHeaderRestorer_pl" );
							  
			
	} else {
			
			$commandString =  qq("$pathToHeaderRestorer_exe" );
	}
	
	#$commandString = $commandString.
	#				 qq(-d $main::logLevel -l "$main::logfile" "$testfile" | );
	
	$commandString = $commandString
					 .qq(-b -p "$prefFile" -l "$logFolder" -x "$serverFolder" "$testfile");
	
	#Copy debug settngs.
	if (! main::DEBUGLOG) {
		$commandString = $commandString." --nodebuglog";
	}
	
	if (! main::INFOLOG) {
		$commandString = $commandString." --noinfolog";
	}
	
	if ($transcodeTable->{'command'} && !($transcodeTable->{'command'} eq "")){
	
		$transcodeTable->{'command'}=$commandString." | ".$transcodeTable->{'command'};
	
	} else{
	
		$transcodeTable->{'command'}=$commandString." |";
	}
	
	
	return $transcodeTable;
}
sub splitTranscodeAndResample{
	my $transcodeTable = shift;

	Plugins::C3PO::Logger::debugMessage('Start splitTranscodeAndResample');

	my $commandString= split_($transcodeTable);
	
	Plugins::C3PO::Logger::debugMessage('Command: '.$commandString);

	my $targetSamplerate = $transcodeTable->{'targetSamplerate'};
	
	my $resampleString = Plugins::C3PO::SoxHelper::resample($transcodeTable,$targetSamplerate);

	$transcodeTable->{resample}=$resampleString;

	if ($commandString eq ""){
		$commandString = $resampleString;

	} elsif (!($resampleString eq "")){
		$commandString=$commandString." | ".$resampleString;
	}
	Plugins::C3PO::Logger::debugMessage('Resample; '.$resampleString);

	$transcodeTable->{'command'}=$commandString;
	return $transcodeTable;
}

sub splitAndTranscode{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::debugMessage('Start splitAndTranscode');
	
	my $incodec=$transcodeTable->{'inCodec'};
	$transcodeTable->{'transitCodec'}=$incodec;

	# Sox will not called at the end, so if we need compresed output,
	# better use flac also to split and not decode.
	
	if (isOutputCompressed($transcodeTable)){

		$transcodeTable = splitAndTranscodeCompressedOutput($transcodeTable);

	} else {

		$transcodeTable = splitAndTranscodeUncompressedOutput($transcodeTable);
	} 
	
	return $transcodeTable;

}
sub splitAndTranscodeUncompressedOutput{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::debugMessage('Start splitAndTranscodeUncompressedOutput');
	
	my $commandString="";
	
	$commandString = split_($transcodeTable);
	
	$transcodeTable->{'command'}=$commandString;

	if (isTranscodingRequested($transcodeTable)) {

		$transcodeTable=transcodeOnly($transcodeTable);
		my $encodeString = $transcodeTable->{transcode};
		if ($commandString eq ""){
			$commandString= $encodeString
		} else{
			$commandString=$commandString." | ".$encodeString;
		}
	}
	
	$transcodeTable->{'command'}=$commandString;
	return $transcodeTable;
}

sub splitAndTranscodeCompressedOutput{
	
	#We Need FLAC
	
	my $transcodeTable=shift;
	
	Plugins::C3PO::Logger::debugMessage('Start splitAndTranscodeCompressedOutput');

	my $splitString="";
	$transcodeTable->{'transitCodec'}='flc';		

	$splitString=Plugins::C3PO::FlacHelper::encode($transcodeTable);
		
	$transcodeTable->{'split'}=$splitString;
	my $command= $splitString;
	$transcodeTable->{'command'}=$command;
	
	return $transcodeTable;
}

sub transcodeOnly{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::verboseMessage('Start transcode');
	
	my $inCodec=$transcodeTable->{'transitCodec'};
	my $outCodec = getOutputCodec($transcodeTable);
	
	my $commandstring="";
	
	if (compareCodecs($inCodec, $outCodec)){ #do nothing
	
	}  else{
		$commandstring= _transcode($transcodeTable);
	}
	$transcodeTable->{transcode}=$commandstring; 
	return $transcodeTable;
}
sub _transcode{

	my $transcodeTable = shift;
	my $commandstring="";
	
	if (isOutputCompressed($transcodeTable)){
	
		$commandstring = transcodeCompressedOutput($transcodeTable);
	
	} elsif (useFFMpegToTranscode($transcodeTable)){
		
		$commandstring = Plugins::C3PO::FfmpegHelper::transcode($transcodeTable);
		
	} else{
	
		$commandstring = Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	}
	return $commandstring;
}

sub split_{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::debugMessage('Start split_');
	
	my $commandString;
	
	if (isSplittingRequested($transcodeTable) &&
		isInputCompressed($transcodeTable)){
		
		$commandString=splitAndDecodeCompressedInput($transcodeTable);
		
	}elsif (isSplittingRequested($transcodeTable)){
			#uncompressed input.
		
		#could need trascoding.
		$commandString=splitUncompressedInput($transcodeTable);
	} elsif (isAStdInPipe($transcodeTable)){
	
		# could not use SOX directly with stdIn.
		
		$commandString=splitAndDecodeCompressedInput($transcodeTable);
	
	}elsif (isInputCompressed($transcodeTable) &&
			!(useSoxToDecodeWhenResampling($transcodeTable))){
			
		$commandString=splitAndDecodeCompressedInput($transcodeTable);
	
	}elsif (!(useSoxToDecodeWhenResampling($transcodeTable))){
			#uncompressed input.
			
		$commandString=splitUnCompressedInput($transcodeTable);
	}
	$commandString=$commandString || "";
	$transcodeTable->{'command'}=$commandString;
	return $commandString;
}

### here splitAndDecodeCompressedInput

sub splitUncompressedInput {
	my $transcodeTable=shift;
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('Start splitUncompressedInput');
	
	if (useFFMpegToSplit($transcodeTable)){

		if (useFFMpegToTranscode($transcodeTable)){

			$transcodeTable->{'transitCodec'}=getOutputCodec($transcodeTable);
		}

		$commandString=Plugins::C3PO::FfmpegHelper::split_($transcodeTable);
		
	} else {

		$commandString=splitAndEndcodeUnCompressedInputUsingFlac($transcodeTable);
	}
	return $commandString;
}

sub checkResample{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::verboseMessage('Start checkResample');
	
	my $samplerates=$transcodeTable->{'sampleRates'};
	my $maxsamplerate = getMaxSamplerate($samplerates,$transcodeTable->{'maxSupportedSamplerate'});
	my $forcedSamplerate= $transcodeTable->{'options'}->{'forcedSamplerate'};
	my $resampleWhen= $transcodeTable->{'resampleWhen'};
	my $resampleTo= $transcodeTable->{'resampleTo'};

	my $file = $transcodeTable->{'options'}->{'file'};
	my $fileInfo;
	my $fileSamplerate;
	my $isSupported;
	my $maxSyncrounusSamplerate;
	
	my $willStart=$transcodeTable->{'C3POwillStart'};

	if (isRuntime($transcodeTable) && defined $willStart && $willStart){
	
		my $testfile=$file;
		if (isAStdInPipe($transcodeTable)){
			
			$testfile= getTestFile($transcodeTable);
			Plugins::C3PO::Logger::debugMessage('testfile: '.$testfile);
			$transcodeTable->{'testfile'}=$testfile;
		}
		Plugins::C3PO::Logger::debugMessage('testfile: '.$testfile);
		$fileInfo= Audio::Scan->scan($testfile);
		
		Plugins::C3PO::Logger::infoMessage('AudioScan: '.Data::Dump::dump ($fileInfo));
		
		$transcodeTable->{'fileInfo'}=$fileInfo;
		$fileSamplerate=$fileInfo->{info}->{samplerate};
		
		Plugins::C3PO::Logger::debugMessage('file samplerate: '.$fileSamplerate);
			
		if ($fileSamplerate){
			
			$isSupported= isSamplerateSupported(
									$fileSamplerate,
			   						$samplerates);
			
			$maxSyncrounusSamplerate=
				getMaxSyncrounusSampleRate($fileSamplerate,
										   $samplerates);
										   
			Plugins::C3PO::Logger::debugMessage('samplerate is '.($isSupported ? '' : 'not ').'supported');
			Plugins::C3PO::Logger::debugMessage('Max syncrounus sample rate : '.$maxSyncrounusSamplerate);
		}
	}
	my $targetSamplerate;
	my $resamplestring="";
	
	if (!isRuntime($transcodeTable)){
	
		$targetSamplerate=$maxsamplerate;
		
	} elsif (defined $forcedSamplerate && $forcedSamplerate>0){

		$targetSamplerate=$forcedSamplerate;

	} elsif ($resampleWhen eq'N'){ #do nothing

	} elsif (!$fileSamplerate){
	
		$targetSamplerate=$maxsamplerate;
	
	} elsif (($resampleWhen eq'E')&& ($isSupported)){ #do nothing
	
	} elsif ($resampleTo eq'X'){
		
		$targetSamplerate=$maxsamplerate;
	
	} elsif (defined $maxSyncrounusSamplerate){
	
		$targetSamplerate=$maxSyncrounusSamplerate;
		
	} else {
		
		$targetSamplerate=$maxsamplerate;
	}
	
	$transcodeTable->{'targetSamplerate'}=$targetSamplerate;
	
	Plugins::C3PO::Logger::debugMessage('Target Sample rate : '.$targetSamplerate);
	
	return $transcodeTable;
	
}

###############################################################################
# Helper routines.
################################################################################

sub isSamplerateSupported{
	my $fileSamplerate = shift;
	my $samplerates = shift;
	
	if (!defined $fileSamplerate || $fileSamplerate==0){
		
		return undef;
	}

	for my $rate (keys %$samplerates){
	
		if ($samplerates->{$rate} && $fileSamplerate==$rate) {return 1;}
	}
	
	return 0;
}

sub getMaxSamplerate{
	my $samplerates= shift;
	my $playerMax = shift;

	my $max=0;
	#Data::Dump::dump ($samplerates);
	#Data::Dump::dump ($playerMax);
	for my $rs (keys %$samplerates){
		
		my $rate = $rs/1;
		
		if (($rate>$max) && $samplerates->{$rs}){
			$max = $rate;
		}
	} 
	#Data::Dump::dump ($max);
	return (($max>0) ? $max : $playerMax);
}

sub getMaxSyncrounusSampleRate{
	my $fileSamplerate=shift;
	my $samplerates=shift;
	
	Plugins::C3PO::Logger::debugMessage('fileSamplerate : '.$fileSamplerate);
	Plugins::C3PO::Logger::debugMessage('Samplerates : '.Data::Dump::dump($samplerates));
	
	if (!defined $fileSamplerate || $fileSamplerate==0){
		
		return undef;
	}
	my $rateFamily;
	
	$fileSamplerate= $fileSamplerate/1;
	
	#Data::Dump::dump(!($fileSamplerate % 11025));
	
	if ($fileSamplerate % 11025 == 0) {
		
		$rateFamily=11025;
	
	} elsif ($fileSamplerate % 12000 == 0) {
		
		$rateFamily=12000;
		
	} elsif ($fileSamplerate % 8000 == 0) {
		
		$rateFamily=8000;
		
	} else {
	
		return undef;
	}
	
	#Data::Dump::dump($rateFamily);
	
	my $max=0;
	
	for my $rs (keys %$samplerates){
		
		if (! $samplerates->{$rs}){next;}
		my $rate = $rs/1;
		
		#Data::Dump::dump($max,$rate, $rateFamily, $rate % $rateFamily, $samplerates->{$rate});
		
		if (($rate % $rateFamily == 0 ) && 
		    ($rate>$max)){
			
			$max = $rate;
		}
	} 
	#Data::Dump::dump($max);
	return ($max > 0 ? $max : undef);
}	
###############################################################################
1;
