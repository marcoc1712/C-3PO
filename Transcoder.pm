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

use strict;
use warnings;

my $logger;
my $log;

#####################################################################
# Plugin entry point
#####################################################################

sub initTranscoder{
	my $transcodeTable= shift;
	$logger= shift;
	
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'};}
	
	if (isLMSDebug()) {
		$log->debug('Start initTranscoder');
	}
	
	my $commandTable={};
	my $codecs=$transcodeTable->{'codecs'};

	for my $codec (keys %$codecs){
		
		$transcodeTable->{'command'}="";
		
		if (!$codecs->{$codec}) {next;}
		
		my $cmd={};
		if (isLMSDebug()) {
			$log->debug("checking $codec");
		}
		$transcodeTable->{'inCodec'}=$codec;

		if (ceckC3PO($transcodeTable)){
			
			if (isLMSDebug()) {
				$log->debug("Use C3PO for $codec");
			}

			$cmd=useC3PO($transcodeTable);
			#Data::Dump::dump ($cmd);

		} else {
		
			if (isLMSDebug()) {
				$log->debug("Use Server for $codec");
			}
			
			$cmd=useServer($transcodeTable);
			#Data::Dump::dump ($cmd);
		}
		
		if ($cmd && !$cmd->{'error'}){

			$commandTable->{$cmd->{'profile'}}= $cmd;

		} else {
		
			$log->error("PROFILE: Name        : ".$cmd->{'profile'}."\n".
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
	
	
	if (isLMSDebug()) {
		$log->debug('is Native :'.isNative($transcodeTable));
		$log->debug('isResamplingRequested :'.isResamplingRequested($transcodeTable));
		$log->debug('resampling to :'.$transcodeTable->{'resampleTo'});
	} else{
		Plugins::C3PO::Logger::debugMessage('is Native :'.isNative($transcodeTable));
		Plugins::C3PO::Logger::debugMessage('isResamplingRequested :'.isResamplingRequested($transcodeTable));
		Plugins::C3PO::Logger::debugMessage('resampling to :'.$transcodeTable->{'resampleTo'});
	}
	
	# there is nothing to do, native.
	if (isNative($transcodeTable)) {return 0;}
	if (! isResamplingRequested($transcodeTable)){return 0;}
	if ($transcodeTable->{'resampleTo'} eq 'X') {return 0;}
	
	# In windows STDIN does not works inside C3PO, so it's disabled.
	if (main::ISWINDOWS &&
	    enableStdin($transcodeTable) &&
	    (($transcodeTable->{'resampleWhen'} eq 'E') || 
	     ($transcodeTable->{'resampleTo'} eq 'S'))){
		 
		return 0;
	}
	return 1;

}
sub buildProfile{
	my $transcodeTable = shift;
	
	if (isLMSDebug()) {
		$log->debug('Start buildProfile');
	}
		
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

	if (isLMSDebug()) {
		$log->debug('Start useC3PO');
	}

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
	if (isLMSDebug()) {
		$log->debug("serverfolder. ".$serverFolder);
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

	if (isLMSDebug()) {
		$log->debug('Start useServer');
	}
	
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

		my $inCodec=$transcodeTable->{'inCodec'};
		my $format= getFormat($inCodec);

		if(enableStdin($transcodeTable)){

			# cue files will always play from the beginning of first track.
			$capabilities->{I}= 'noArgs';

			# enabling the following, track > 1 in cue file will not play at all.
			#$capabilities->{T}='START=--skip=%t';
			#$capabilities->{U}='END=--until=%v';

		}elsif (enableSeek($transcodeTable) && $format->useFFMpegToSplit($transcodeTable)){

			$capabilities->{T}='START=-ss %s';
			$capabilities->{U}='END=-t %w';

		} elsif (enableSeek($transcodeTable) && $format->useFAADToSplit($transcodeTable)){

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
sub isNative{

	my $transcodeTable =shift;
	my $inCodec = $transcodeTable->{'inCodec'};
	
	if (! $transcodeTable->{'enableConvert'}->{$inCodec} &&
		! isResamplingRequested($transcodeTable)) {return 1;}
		
	return 0;
}
################################################################
# C-3PO entry point.
################################################################

sub buildCommand {
	my $transcodeTable = shift;

	my $command="";
	
	if (isLMSDebug()) {
		$log->debug('Start buildCommand');
	} else{
	
		Plugins::C3PO::Logger::debugMessage('Start buildCommand');
	}
	
	$transcodeTable=normalizeCodecs($transcodeTable);
	
	if (isResamplingRequested($transcodeTable)) {
	
		$transcodeTable= checkResample($transcodeTable);
	}
	
	#save incodec.
	$transcodeTable->{'transitCodec'}=$transcodeTable->{'inCodec'};
	
	if (isLMSDebug()) {
		$log->debug('inCodec: '.$transcodeTable->{'inCodec'});
		$log->debug('transitCodec: '.$transcodeTable->{'transitCodec'});
		$log->debug('outCodec: '.$transcodeTable->{'outCodec'});
		$log->debug('Is resampling requested? '.isResamplingRequested($transcodeTable));
		$log->debug('willResample ? '.willResample($transcodeTable));
		$log->debug('Is splitting requested? '.isSplittingRequested($transcodeTable));
	} else{
		Plugins::C3PO::Logger::debugMessage('inCodec: '.$transcodeTable->{'inCodec'});
		Plugins::C3PO::Logger::debugMessage('transitCodec: '.$transcodeTable->{'transitCodec'});
		Plugins::C3PO::Logger::debugMessage('outCodec: '.$transcodeTable->{'outCodec'});
		Plugins::C3PO::Logger::debugMessage('Is resampling requested? '.isResamplingRequested($transcodeTable));
		Plugins::C3PO::Logger::debugMessage('willResample ? '.willResample($transcodeTable));
		Plugins::C3PO::Logger::debugMessage('Is splitting requested? '.isSplittingRequested($transcodeTable));
	}

	if (willResample($transcodeTable)){
	
		$transcodeTable=splitResampleAndTranscode($transcodeTable);
	
	} elsif (isSplittingRequested($transcodeTable)){
		
		$transcodeTable=splitAndTranscode($transcodeTable);

	} else {
		
		$transcodeTable=transcodeOnly($transcodeTable);
		$transcodeTable->{'command'}=$transcodeTable->{transcode};
	
	}
	$command = $transcodeTable->{'command'}||"";
	
	if (isLMSDebug()) {
		$log->debug('Transcode command: '.$command);
	} else{
		Plugins::C3PO::Logger::debugMessage('Transcode command: '.$command);
	}
	
	if ($command eq ""){
		
		if (isRuntime($transcodeTable)){

			# Using native to just pass IN to OUT via a dummy transcoder.
			$transcodeTable = native($transcodeTable);

		} else {
			
			# Native LMS pipe method.
			$transcodeTable->{'command'}="-";		
		}
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::debugMessage('Safe command    : '.$command);
	
	if (needRestoreHeader($transcodeTable)){
	
		$transcodeTable = restoreHeader($transcodeTable);
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::debugMessage('Final command    : '.$command);
	return $transcodeTable;
}

###############################################################################
# C-3PO sub cases
###############################################################################

sub splitResampleAndTranscode{
	my $transcodeTable = shift;
	
	if (isLMSDebug()) {
		$log->debug('Start splitTranscodeAndResample')
	} else{
		Plugins::C3PO::Logger::debugMessage('Start splitTranscodeAndResample');
	}
	my $inCodec=$transcodeTable->{'inCodec'};
	my $format= getFormat($inCodec);
	
	my $sox=$format->useSoxToTranscodeWhenResampling($transcodeTable);
	
	if (isLMSDebug()) {
		$log->debug("useSoxToTranscodeWhenResampling: ".$sox)
	} else{
		Plugins::C3PO::Logger::debugMessage("useSoxToTranscodeWhenResampling: ".$sox);
	}
	
	my $commandString;
	
	if (isSplittingRequested($transcodeTable)){
		
		if (isLMSDebug()) {
			$log->debug('isSplittingRequested : 1')
		} else{
			Plugins::C3PO::Logger::debugMessage('isSplittingRequested : 1');
		}

		#no compression applied, we need to resample firts.
		$commandString=$format->splitBeforeResampling($transcodeTable);
			
	} elsif (isAStdInPipe($transcodeTable)){
		
		if (isLMSDebug()) {
			$log->debug('isAStdInPipe : 1')
		} else{
			Plugins::C3PO::Logger::debugMessage('isAStdInPipe : 1');
		}

		# could not use SOX directly with stdIn.
		# just see if we could early decode compressed formats.
		$commandString=$format->decodeBeforeResampling($transcodeTable);
	
	} elsif (!($format->useSoxToTranscodeWhenResampling($transcodeTable))){
		
		if (isLMSDebug()) {
			$log->debug('NOT useSoxToTranscodeWhenResampling')
		} else{
			Plugins::C3PO::Logger::debugMessage('NOT useSoxToTranscodeWhenResampling');
		}

		# early decode compressed formats.
		$commandString=$format->decodeBeforeResampling($transcodeTable);
	}
	$commandString=$commandString || "";
	$transcodeTable->{'command'}=$commandString;
	
	if (isLMSDebug()) {
		$log->debug('Split Command: '.$commandString)
	} else{
		Plugins::C3PO::Logger::debugMessage('Split Command: '.$commandString);
	}
	
	my $targetSamplerate = $transcodeTable->{'targetSamplerate'};
	
	my $resampleString = Plugins::C3PO::SoxHelper::resample($transcodeTable,$targetSamplerate);

	$transcodeTable->{resample}=$resampleString;
	
	if ($commandString eq ""){
	
		$commandString = $resampleString;

	} else {
		$commandString=$commandString." | ".$resampleString;
	}
	
	if (isLMSDebug()) {
		$log->debug('Resample; '.$resampleString)
	} else{
		Plugins::C3PO::Logger::debugMessage('Resample; '.$resampleString);
	}

	$transcodeTable->{'command'}=$commandString;
	return $transcodeTable;
}
sub splitAndTranscode{
	my $transcodeTable = shift;
	
	if (isLMSInfo()) {
		$log->info('Start splitAndTranscode')
	} else{
		Plugins::C3PO::Logger::debugMessage('Start splitAndTranscode');
	}

	my $inCodec=$transcodeTable->{'inCodec'};
	$transcodeTable->{'transitCodec'}=$inCodec;
	
	my $format= getFormat($inCodec);
	
	my $commandString="";
	$transcodeTable->{'command'}=$commandString;
	
	# SOx is not going to be called fo resampling, so we need to perform all
	# the transcoding in the split fase or immediatly after.
	
	if (isSplittingRequested($transcodeTable)){
		
		#Split and encode to final codec when possible,
		$commandString=$format->splitAndEncode($transcodeTable);	
		$transcodeTable->{'command'}=$commandString;
	}
	
	if (isLMSInfo()) {
		$log->info('Is transcoding Required? '.isTranscodingRequired($transcodeTable));
	} else{
		Plugins::C3PO::Logger::debugMessage('Is transcoding Required? '.isTranscodingRequired($transcodeTable));
	}

	if (isTranscodingRequired($transcodeTable)) {
	
		my $codec=$transcodeTable->{'transitCodec'};
		$format= getFormat($codec);
		my $transcodeString = $format->transcode($transcodeTable);
		
		if (! ($transcodeString eq "")){
			$commandString= $commandString." | ".$transcodeString;
		}
		$transcodeTable->{'command'}=$commandString;
	}
	
	return $transcodeTable;
}
sub transcodeOnly{
	my $transcodeTable = shift;
	
	if (isLMSInfo()) {
		$log->info('Start transcode Only')
	} else{
		Plugins::C3PO::Logger::debugMessage('Start transcode Only');
	}

	my $inCodec=$transcodeTable->{'inCodec'};
	
	my $format= getFormat($inCodec);
	my $commandstring="";
	
	if (isTranscodingRequired($transcodeTable)){
		$commandstring= $format->transcode($transcodeTable);
	}
	
	$transcodeTable->{transcode}=$commandstring; 
	return $transcodeTable;
}
sub native{
	my $transcodeTable = shift;
	
	if (isLMSInfo()) {
		$log->info('Start native')
	} else{
		Plugins::C3PO::Logger::debugMessage('Start native');
	}
	
	# maybe transcoding and/or resampling was requested but is not needed
	# and we could not issue an ampty command from C-3PO.
	# let's use a 'dummy' transcoder.
	
	my $inCodec=$transcodeTable->{'transitCodec'};
	
	my $format= getFormat($inCodec);
	my $commandstring="";
	
	if (isTranscodingRequired($transcodeTable)){
		$commandstring= $format->native($transcodeTable);
	}
	
	$transcodeTable->{'command'}=$commandstring;
	
	return $transcodeTable;
}
###############################################################################
# Repair some LMS misuse
###############################################################################

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

sub compareCodecs{
	my $Acodec= shift;
	my $Bcodec= shift;
	
	if (! $Acodec || ! $Bcodec){
		Plugins::C3PO::Logger::traceMessage('compareCodecs : ');
		die;
	}
	if ($Acodec eq 'pcm'){ $Acodec = 'wav';}
	if ($Bcodec eq 'pcm'){ $Bcodec = 'wav';}
	
	return ($Acodec eq $Bcodec);

}
################################################################################
# Codec independent - Helper routines.
################################################################################

sub checkResample{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::debugMessage('Start checkResample');
	
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
sub willResample{
	my $transcodeTable=shift;
	
	if (!isResamplingRequested($transcodeTable)) {return 0;}
	#be sure to call checkResample before.
	
	# Keep it short and always resample if asked for.
	#return 1;

	#Aways resample if any effect is requested
	if ($transcodeTable->{'gain'}) {return 1;}
	if ($transcodeTable->{'loudnessGain'}) {return 1;}
	if ($transcodeTable->{'remixLeft'} && !($transcodeTable->{'remixLeft'} eq 100)) {return 1;}
	if ($transcodeTable->{'remixRight'} && !($transcodeTable->{'remixRight'} eq 100)) {return 1;}
	if ($transcodeTable->{'flipChannels'}) {return 1;}
	
	#Always resample if any extra effects is requested.
	if ($transcodeTable->{'extra_before_rate'} && !($transcodeTable->{'extra_before_rate'} eq "")) {return 1;}
	if ($transcodeTable->{'extra_after_rate'} && !($transcodeTable->{'extra_after_rate'} eq "")) {return 1;}
	
	#Resample if sample rate or bit depth are different.
	my $targetSamplerate=$transcodeTable->{'targetSamplerate'};
	my $fileSamplerate = $transcodeTable->{'fileInfo'}->{info}->{samplerate};
	
	Plugins::C3PO::Logger::debugMessage("targetSamplerate: ".(defined $targetSamplerate ? $targetSamplerate : 'undef'));
	Plugins::C3PO::Logger::debugMessage("fileSamplerate: ".(defined $fileSamplerate ? $fileSamplerate : 'undef'));

	if (!defined $targetSamplerate) {return 0;}
	if (!$fileSamplerate || !($fileSamplerate == $targetSamplerate)){return 1;}
	
		
	my $targetBitDepth = $transcodeTable->{'outBitDepth'};
	my $fileBitDepth   = $transcodeTable->{'fileInfo'}->{info}->{bits_per_sample} ? 
							$transcodeTable->{'fileInfo'}->{info}->{bits_per_sample}/8 :
							undef;
	
	Plugins::C3PO::Logger::debugMessage("targetBitDepth: ".(defined $targetBitDepth ? $targetBitDepth : 'undef'));
	Plugins::C3PO::Logger::debugMessage("fileBitDepth: ".(defined $fileBitDepth ? $fileBitDepth : 'undef'));
	
	if (!defined $targetBitDepth) {return 0;}
	if (!$fileBitDepth || !($fileBitDepth == $targetBitDepth)){return 1;}
	
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
sub getTestFile{
	my $transcodeTable =shift;
	
	my $fileName = "header.".$transcodeTable->{'inCodec'};
	my $outfile  = Plugins::C3PO::OsHelper::getTemporaryFile($fileName);
		
	Plugins::C3PO::Logger::debugMessage('out file : '.$outfile);
	
	saveHeaderFile(\*STDIN, $outfile);
	
	Plugins::C3PO::Logger::debugMessage('returning : '.$outfile);
	return $outfile;
}
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
#####################################################################
# Transcoding flow control: general, not codec depending 
# TO BE MOVED in a NEW transcoder class.
#####################################################################

sub isLMSDebug{
	
	if ($logger && $logger->{DEBUGLOG} && $log && $log->is_debug) {return 1}
	return 0;
}
sub isLMSInfo{

	if (isLMSDebug()) {return 1;}
	if ($logger && $logger->{INFOLOG} && $log && $log->is_info) {return 1}
	return 0;
}
sub isRuntime{
	my $transcodeTable =shift;

	return (defined $transcodeTable->{'options'}->{clientId} ? 1 : 0)
}

sub isSplittingRequested{
	my $transcodeTable =shift;
	my $inCodec= $transcodeTable->{'inCodec'};

	if (!isRuntime($transcodeTable) && 
	    $transcodeTable->{'enableSeek'}->{$inCodec}) {return 1;} 
	
	if  (defined $transcodeTable->{'options'}->{startTime}) {return 1;}  
	if  (defined $transcodeTable->{'options'}->{endTime}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{startSec}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{endSec}){return 1;} 
	if  (defined $transcodeTable->{'options'}->{durationSec}){return 1;} 
	
	return 0;
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

sub isResamplingRequested{
	my $transcodeTable =shift;
	
	my $inCodec= $transcodeTable->{'inCodec'};
	
	Plugins::C3PO::Logger::debugMessage('In codec '.$inCodec);
	Plugins::C3PO::Logger::debugMessage('enableResample: '.
		($transcodeTable->{'enableResample'}->{$inCodec} ? 
			$transcodeTable->{'enableResample'}->{$inCodec} : 0));
	
	Plugins::C3PO::Logger::debugMessage('resampleWhen: '.$transcodeTable->{'resampleWhen'});
	
	if (! $transcodeTable->{'enableResample'}->{$inCodec}) {return 0;}
	return !($transcodeTable->{'resampleWhen'} eq 'N');
}
sub isTranscodingRequired{
	my $transcodeTable =shift;
	
	my $isRuntime	   = isRuntime($transcodeTable);
	my $inCodec		   = $transcodeTable->{'inCodec'};
	my $outCodec	   = getOutputCodec($transcodeTable);
	my $transitCodec   = $transcodeTable->{'transitCodec'};
	my $enableConvert  = $transcodeTable->{'enableConvert'}->{$inCodec};
	
	
	if (isLMSDebug()) {
		$log->debug('isRuntime '.$isRuntime);
		$log->debug('inCodec '.$inCodec);
		$log->debug('transitCodec '.$transitCodec);
		$log->debug('outCodec '.$outCodec);
		$log->debug('enableConvert '.(defined $enableConvert ? '1' : '0'));
		
	} else{
		Plugins::C3PO::Logger::debugMessage('isRuntime '.$isRuntime);
		Plugins::C3PO::Logger::debugMessage('inCodec '.$inCodec);
		Plugins::C3PO::Logger::debugMessage('transitCodec '.$transitCodec);
		Plugins::C3PO::Logger::debugMessage('outCodec '.$outCodec);
		Plugins::C3PO::Logger::debugMessage('enableConvert '.(defined $enableConvert ? '1' : '0'));
	}
	
	if (! $isRuntime && ! $enableConvert) {return 0;}
	if (!compareCodecs($transitCodec, $outCodec)) {return 1;}
}
 

###############################################################################
# Depending somehow on Format....
###############################################################################

sub getOutputCodec{
	my $transcodeTable =shift;
	
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec= $transcodeTable->{'outCodec'};
	
	if (! $inCodec || ! $outCodec){
		Plugins::C3PO::Logger::traceMessage('getOutputCodec : ');
		die;
	}
	
	if ($transcodeTable->{'enableConvert'}->{$inCodec}){return $outCodec;}
	
	if ($transcodeTable->{'enableResample'}->{$inCodec} && 
	    compareCodecs($inCodec, 'alc')){return $outCodec;}

	return $inCodec;
}

#NOT TO BE USED with ALAC input.	
# encode to the output codec (FLAC) )wile resampling, 
# no meaning if not resampling.

sub useSoxToEncodeWhenResampling {
	my $transcodeTable =shift;

	my $inCodec=$transcodeTable->{'transitCodec'};
	
	my $format= getFormat($inCodec);
	return $format->useSoxToEncodeWhenResampling($transcodeTable);
}
###############################################################################
# Get procedure details depending on the input format.
###############################################################################
	
sub getFormat{
	my $inCodec = shift;
	
	my $format;
	
	#require Plugins::C3PO::Formats::Format;
	
	if ($inCodec eq 'wav'){

		$format = Plugins::C3PO::Formats::Wav->new($logger, $log);
	
	} elsif ($inCodec eq 'aif'){

		$format = Plugins::C3PO::Formats::Aiff->new($logger, $log);
		
	} elsif ($inCodec eq 'flc'){

		$format = Plugins::C3PO::Formats::Flac->new($logger, $log);
		
	} elsif ($inCodec eq 'alc'){

		$format = Plugins::C3PO::Formats::Alac->new($logger, $log);
	}
	Plugins::C3PO::Logger::debugMessage("using format: ".$format->toString());
	return $format;
}

###############################################################################
# Codec independent - Helper routines.
################################################################################
###############################################################################
1;
