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

package Plugins::C3PO::Transcoder;

#
# See plugin.pm for description and terms of use.

use strict;
use warnings;

#use Data::Dump;

#####################################################################
# flow control - Double check when adding support for codecs.
#####################################################################

#TODO: using FLAC to split an AIF file then upsampled by SOX, sometime do not 
#work, at 192k (sox raise to 50% CPU). No probs at 176400.
#

sub enableSeek{
	#
	# TODO:
	#
	# 'I' Capability is necessary for Qubuz and other services, but is not
	# compatible with 'T' and 'U' (seek) used by .cue sheets.
	# Profiles could not include all of them at thee same time, unless we patch
	# LMS as Daphile did.
	#
	#
	my $transcodeTable =shift;
	
	#in runtime use transitCodec.	
	my $inCodec= isRuntime($transcodeTable) 
		? $transcodeTable->{'transitCodec'} : $transcodeTable->{'inCodec'};
	
	my $enable = $transcodeTable->{'enableSeek'}->{$inCodec} ? 1 : 0;
	Plugins::C3PO::Logger::debugMessage("codec: $inCodec - enableSeek: $enable");
	
	return $enable;
}
sub isCompressedCodec{
	my $codec= shift;

	if ($codec eq 'flc') {return 1};
	if ($codec eq 'alc') {return 1};
	
	return 0;
}
sub useFFMpegToSplit{

	# use ffmpeg instead of flac to split files when usin cue sheets.
	# needs ffmpeg to be installed, if not will use flac.
	
	my $transcodeTable =shift;
	
	if (!defined $transcodeTable->{'pathToFFmpeg'}) {return 0};
	
	#in runtime use transitCodec instead of inCodec.
	my $inCodec= isRuntime($transcodeTable) 
		? $transcodeTable->{'transitCodec'} : $transcodeTable->{'inCodec'};

	if ($inCodec eq 'wav') {return 1};
	if ($inCodec eq 'pcm') {return 1};
	if ($inCodec eq 'aif') {return 1};

	return 0;
}
sub useFFMpegToTranscode {
	
	# decode to $outcodec when splitting or
	# when trascoding at the end, if not done by sox wile resampling.
	# needs ffmpeg to be installed, if not will use sox.
	
	my $transcodeTable =shift;
	
	if (!defined $transcodeTable->{'pathToFFmpeg'}) {return 0};
	
	my $inCodec= $transcodeTable->{'transitCodec'};
	my $outcodec= $transcodeTable->{'outCodec'};
	
	# avoid to encode before upsampling.
	if (isCompressedCodec($outcodec)) {return 0};
	
	if ($inCodec eq 'wav') {return 1};
	if ($inCodec eq 'pcm') {return 1};
	if ($inCodec eq 'aif') {return 1};
	
	return 0;
}
sub useFlacToDecodeWhenSplitting {

	# decode to $outcodec when splitting, no meaning if not splitting.

	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=$transcodeTable->{'outCodec'};

	if (!($inCodec eq 'flc')) {return 0};
	
	return 0; # AIF will not worlk with 1. See FlacTranscode.
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
		sysread ($fh, $headbuffer, 8192)	# read in (up to) 64k chunks, write
		and syswrite $head, $headbuffer	# exit if read or write fails
	  ) {};
	  die "Problem writing: $!\n" if $!;

	flush $head;
	close $head;
	
	return 1;
}
################################################################################
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
sub isRuntime{
	my $transcodeTable =shift;

	return (defined $transcodeTable->{'options'}->{clientId} ? 1 : 0)
}

sub isSplittingRequested{
	my $transcodeTable =shift;
	
	if (!isRuntime($transcodeTable)) {return 1;} 
	
	if  (defined $transcodeTable->{'options'}->{startTime}) {return 1;}  
	if  (defined $transcodeTable->{'options'}->{endTime}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{startSec}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{endSec}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{durationSec}){return 1;} 
	
	return 0;
}

sub isDecodingRequested{
	my $transcodeTable =shift;
	
	my $inCodec= $transcodeTable->{'transitCodec'};
	my $outCodec=$transcodeTable->{'outCodec'};
		
	return ($inCodec eq $outCodec);
}

sub isResamplingRequested{
	my $transcodeTable =shift;
	return !($transcodeTable->{'resampleWhen'} eq 'N');
}
sub willResample{
	my $transcodeTable=shift;
	
	#be sure to call checkResample before.
	
	my $targetSamplerate=$transcodeTable->{'targetSamplerate'};
	my $fileSamplerate = $transcodeTable->{'fileInfo'}->{info}->{samplerate};
	
	Plugins::C3PO::Logger::verboseMessage("targetSamplerate: ". defined $targetSamplerate ? $targetSamplerate : 'undef');
	Plugins::C3PO::Logger::verboseMessage("fileSamplerate: ". defined $fileSamplerate ? $fileSamplerate : 'undef');

	if ((defined $targetSamplerate) &&
		((!$fileSamplerate) || !($fileSamplerate == $targetSamplerate))){

		return 1
		
	}
	return 0;
}
sub isOutputCompressed{
	my $transcodeTable =shift;
	
	my $outCompression = $transcodeTable->{'outCompression'};
	return (defined $outCompression ? 1 : 0);
}
sub isInputCompressed{
	my $transcodeTable =shift;	
	
	my $inCodec= $transcodeTable->{'inCodec'};
	
	return isCompressedCodec($inCodec);
}
sub isTranscodingRequested{
	my $transcodeTable =shift;
	
	my $inCodec= $transcodeTable->{'transitCodec'};
	my $outCodec=$transcodeTable->{'outCodec'};
	
	return !($outCodec eq $inCodec);
}
sub isAStdInPipe {
	my $transcodeTable =shift;
	
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

sub splitAndTranscodeCompressedOutput{
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
sub splitAndDecodeCompressedInput {
	my $transcodeTable=shift;
	
	my $inCodec	= $transcodeTable->{'inCodec'};
	
	my $commandString="";
	
	Plugins::C3PO::Logger::debugMessage('$inCodec '.$inCodec);
	
	if ($inCodec eq 'flc' ) {

		#decode and split with flac.
		if (useFlacToDecodeWhenSplitting($transcodeTable)){

			$transcodeTable->{'transitCodec'}=$transcodeTable->{'outCodec'};
			# See useFlacToDecodeWhenSplitting

		} else {

			# wav is the defauld option for FLAC.
			$transcodeTable->{'transitCodec'}='wav';	

		}
		$commandString=Plugins::C3PO::FlacHelper::decode($transcodeTable);
	}
	# add here other compressed codecs.
	Plugins::C3PO::Logger::debugMessage('$commandString '.$commandString);
	return $commandString;
}

sub splitAndEndcodeCompressedInput {
	my $transcodeTable=shift;
	
	Plugins::C3PO::Logger::verboseMessage('Start splitAndEndcodeCompressedInput');
	
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
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::verboseMessage('Start transcodeCompressedOutput');
	
	my $inCodec=$transcodeTable->{'transitCodec'};
	my $outCodec = $transcodeTable->{'outCodec'};
	
	Plugins::C3PO::Logger::verboseMessage('Start transcode');

	my $commandstring="";
	
	if (($outCodec eq 'flc') && useFlacToFinalEncode($transcodeTable)){

		$commandstring = Plugins::C3PO::FlacHelper::encode($transcodeTable);
	
	} else {
	
		$commandstring = Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	}
	return $commandstring;
}
sub normalizeCodecs{
	my $transcodeTable =shift;

	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=$transcodeTable->{'outCodec'};
	
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
	my $willStart=$transcodeTable->{'C3POwillStart'};
	
	Plugins::C3PO::Logger::debugMessage('Start initTranscoder');
	
	if (!((defined $willStart) &&
		  (($willStart eq 'pl') ||($willStart eq 'exe')))){

		#Fault back, resample to max supported samplerate.
		$transcodeTable->{'resampleTo'}='X';
		$transcodeTable->{'resampleWhen'}='A';
	}
	
	my $commandTable={};
	my $codecs=$transcodeTable->{'codecs'};

	for my $codec (keys %$codecs){
	
		my $cmd={};
		
		if (!($codecs->{$codec})) {next}
		
		$transcodeTable->{'inCodec'}=$codec;
		
		if (!(isRuntime($transcodeTable)) &&
			(($transcodeTable->{'resampleTo'} eq 'S')||
			($transcodeTable->{'resampleWhen'} eq 'E'))){
			
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

sub buildProfile{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::debugMessage('Start buildProfile');
	
	my $macaddress= $transcodeTable->{'macaddress'};
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=$transcodeTable->{'outCodec'};

	# pcm/wav misuse...
	if ($inCodec eq 'pcm'){$inCodec='wav'};
	
	if (($inCodec eq 'aif') && (($outCodec eq 'wav') || ($outCodec eq'pcm'))){
		
		{$outCodec='aif'};
		
	} elsif ($outCodec eq 'wav'){
	
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
	my $outCodec=$transcodeTable->{'outCodec'};
	my $prefFile = $transcodeTable->{'pathToPrefFile'};
	my $pathToC3PO_pl = $transcodeTable->{'pathToC3PO_pl'};
	my $logFolder = $transcodeTable->{'logFolder'};
	
	$result->{'profile'} =  buildProfile($transcodeTable);
	
	my $command="";
	
	my $willStart=$transcodeTable->{'C3POwillStart'};
	
	if ($willStart eq 'pl'){
		
			$command =  qq([perl] "$pathToC3PO_pl").' -c $CLIENTID$ -p ';
			
	} else {
			
			$command =  '[C-3PO] -c $CLIENTID$ -p ';
	}
	
	$command = $command.qq("$prefFile" -l "$logFolder" -i $inCodec -o $outCodec )
					   .'$START$ $END$ $RESAMPLE$ $FILE$';
					   
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
	if(!enableSeek($transcodeTable) && !main::ISWINDOWS){
	#if(!enableSeek($transcodeTable)){

		#Disabling this and enabling the followings LMS will use R capabilities and 
		# pass the Qobuz link to C3PO, but it does not works, needs the quboz plugin pipe 
		# to be activated via I.
		#
		$capabilities->{I}= 'noArgs';  
		#$capabilities->{T}='START=-s %s';
		#$capabilities->{U}='END=-w %w';
	} else {

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
		
	if(!enableSeek($transcodeTable)){
		                              
		# cue files will always play from the beginning of first track.
		$capabilities->{I}= 'noArgs';
		
		# enabling the following, track > 1 in cue file will not play at all.
		#$capabilities->{T}='START=--skip=%t';
		#$capabilities->{U}='END=--until=%v';
		
	}elsif (useFFMpegToSplit($transcodeTable)){
		
		$capabilities->{T}='START=-ss %s';
		$capabilities->{U}='END=-t %w';
		
	} else { #use flac

		$capabilities->{T}='START=--skip=%t';
		$capabilities->{U}='END=--until=%v';
	}
	
	$transcodeTable->{'capabilities'}=$capabilities;	
	
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
	
	my $command="";
	
	Plugins::C3PO::Logger::debugMessage('Start buildCommand');

	$transcodeTable=normalizeCodecs($transcodeTable);

	if (isResamplingRequested($transcodeTable)) {
	
		$transcodeTable= checkResample($transcodeTable);
		
	}
	Plugins::C3PO::Logger::debugMessage('willResample ? '.willResample($transcodeTable));
	
	#save incodec.
	$transcodeTable->{'transitCodec'}=$transcodeTable->{'inCodec'};
	
	if (willResample($transcodeTable)){
	
		$transcodeTable=splitTranscodeAndResample($transcodeTable);
	
	} elsif (isSplittingRequested($transcodeTable)){
		
		$transcodeTable=splitAndTranscode($transcodeTable);

	} else {
		
		$transcodeTable=transcode($transcodeTable);
		$transcodeTable->{'command'}=$transcodeTable->{transcode};
	
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::debugMessage('transcode command: '.$command);
	
	# We could not exit with a null string, we need at least a dummy executable
	# converter.
	
	if ($command eq ""){

		$command= Plugins::C3PO::DummyTranscoderHelper::transcode($transcodeTable);
	}
	$transcodeTable->{'command'}=$command;
	
	if (needRestoreHeader($transcodeTable)){
	
		$transcodeTable = restoreHeader($transcodeTable);
		
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::debugMessage('built command: '.$command);
	return $transcodeTable;
}
sub restoreHeader{
	my $transcodeTable = shift;
	
	my $willStart				 = $transcodeTable->{'C3POwillStart'};
	my $pathToPerl				 = $transcodeTable->{'pathToPerl'};
	my $pathToHeaderRestorer_pl	 = $transcodeTable->{'pathToHeaderRestorer_pl'};
	my $pathToHeaderRestorer_exe = $transcodeTable->{'pathToHeaderRestorer_exe'};
	my $testfile				 = $transcodeTable->{'testfile'};

	my $commandString= "";

	if ($willStart eq 'pl'){
		
			$commandString =  qq("$pathToPerl" "$pathToHeaderRestorer_pl" );
							  
			
	} else {
			
			$commandString =  qq("$pathToHeaderRestorer_exe" );
	}
	
	$commandString = $commandString.
					 qq(-d $main::logLevel -l "$main::logfile" "$testfile" | );
									
	$transcodeTable->{'command'}=$commandString.$transcodeTable->{'command'};
	
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

		$transcodeTable=transcode($transcodeTable);
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

### here splitAndTranscodeCompressedOutput.

sub transcode{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::verboseMessage('Start transcode');
	
	my $inCodec=$transcodeTable->{'transitCodec'};
	my $outCodec = $transcodeTable->{'outCodec'};
	
	my $commandstring="";

	if (isOutputCompressed($transcodeTable)){
	
		$commandstring = transcodeCompressedOutput($transcodeTable);
	
	} elsif (useFFMpegToTranscode($transcodeTable)){
		
		$commandstring = Plugins::C3PO::FfmpegHelper::transcode($transcodeTable);
		
	} else{
	
		$commandstring = Plugins::C3PO::SoxHelper::transcode($transcodeTable);
	}
	$transcodeTable->{transcode}=$commandstring; 
	return $transcodeTable;
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
	
		# could not use SOX directly in this case.
		
		$commandString=splitAndDecodeCompressedInput($transcodeTable);
	
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

			$transcodeTable->{'transitCodec'}=$transcodeTable->{'outCodec'};
		}

		$commandString=Plugins::C3PO::FfmpegHelper::split_($transcodeTable);
		
	} else {

		$commandString=splitAndEndcodeCompressedInput($transcodeTable);
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
	
	#if (defined $willStart && defined $file && 
	#	!isAStdInPipe($transcodeTable)){
	
	if (isRuntime($transcodeTable) && defined $willStart && $willStart){
	
		my $testfile=$file;
		if (isAStdInPipe($transcodeTable)){
			
			$testfile= getTestFile($transcodeTable);
			Plugins::C3PO::Logger::debugMessage('testfile: '.$testfile);
			$transcodeTable->{'testfile'}=$testfile;
		}
		Plugins::C3PO::Logger::debugMessage('testfile: '.$testfile);
		$fileInfo= Audio::Scan->scan($testfile);
		
		Plugins::C3PO::Logger::debugMessage('AudioScan: '.Data::Dump::dump ($fileInfo));
		
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

	} elsif ($resampleWhen eq'N'){

	} elsif (!$fileSamplerate){
	
		$targetSamplerate=$maxsamplerate;
	
	} elsif (($resampleWhen eq'E')&& ($isSupported)){
	
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
	
		if ($fileSamplerate==$rate) {return 1;}
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
	
	#Data::Dump::dump($fileSamplerate);
	#Data::Dump::dump($samplerates);
	
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
		
		my $rate = $rs/1;
		
		#Data::Dump::dump($max,$rate, $rateFamily, $rate % $rateFamily, $samplerates->{$rate});
		
		if (($rate % $rateFamily == 0 ) && 
		    ($rate>$max) && 
			($samplerates->{$rate})){
			
			$max = $rate;
		}
	} 
	#Data::Dump::dump($max);
	return ($max > 0 ? $max : undef);
}	
###############################################################################
1;