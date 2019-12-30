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
use Data::Dump qw(dump pp);

my $logger;
my $log;

#####################################################################
# Plugin entry point
#####################################################################

sub initTranscoder{
	my $transcodeTable= shift;
	$logger= shift;

	if ($logger && $logger->{'log'}) {$log=$logger->{'log'};}
	
	#TODO: unificare i sistemi di log da una unica classe.
    #warn isLMSDebug() ? "is LMS Debug" : " is not LMS Debug";
    #warn isLMSInfo() ? "is LMS Info" : " is not LMS Info";
    
	if (isLMSDebug()) {
		$log->debug('Start initTranscoder');
	}

	my $commandTable={};
	my $codecs=$transcodeTable->{'codecs'};
    
    #save selected settings.
    my $resampleTo =   $transcodeTable->{'resampleTo'};
	my $resampleWhen = $transcodeTable->{'resampleWhen'};

	for my $codec (keys %$codecs){
        
		#restore selected settings.
        $transcodeTable->{'resampleTo'}=$resampleTo;
        $transcodeTable->{'resampleWhen'}= $resampleWhen;
        
		$transcodeTable->{'command'}="";
		
		if (!$codecs->{$codec}) {next;}
				
		my $cmd={};
		if (isLMSInfo()) {
			$log->info("checking $codec");
		}
		$transcodeTable->{'inCodec'}=$codec;

		if (_ceckC3PO($transcodeTable)){
			
			if (isLMSInfo()) {
				$log->info("Use C3PO for $codec");
			}

			$cmd=_useC3PO($transcodeTable);
			#Data::Dump::dump ($cmd);

		} else {
		
			if (isLMSInfo()) {
				$log->info("Use Server for $codec");
			}
			
			$cmd=_useServer($transcodeTable);
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
################################################################################
# Private
#
sub _ceckC3PO{
	my $transcodeTable= shift;
	my $willStart=$transcodeTable->{'C3POwillStart'}||0;
	my $codec = $transcodeTable->{'inCodec'};
	
	if (isLMSInfo()) {
		$log->info('inCodec '.$codec.',  willStart '.$willStart);
        $log->info('resampling to :'.$transcodeTable->{'resampleTo'});
	}
	
	if (!((defined $willStart) &&
		  (($willStart eq 'pl') ||($willStart eq 'exe')))){

		#Fault back, resample to max supported samplerate.
		$transcodeTable->{'resampleTo'}='X';
		$transcodeTable->{'resampleWhen'}='A';
		return 0;
	}
	
	# safety
	if (isRuntime($transcodeTable)) {return 0;}
    
	if (isLMSInfo()) {
		$log->info('is Native :'._isNative($transcodeTable));
		$log->info('_isSOXrequired :'._isSOXrequired($transcodeTable));
		$log->info('resampling to :'.$transcodeTable->{'resampleTo'});
	} else{
		Plugins::C3PO::Logger::infoMessage('is Native :'._isNative($transcodeTable));
		Plugins::C3PO::Logger::infoMessage('_isSOXrequired :'._isSOXrequired($transcodeTable));
		Plugins::C3PO::Logger::infoMessage('resampling to :'.$transcodeTable->{'resampleTo'});
	}
	
	# there is nothing to do, native.
	if (_isNative($transcodeTable)) {return 0;}
    
	if (! _isSOXrequired($transcodeTable)){return 0;}
	if (!($transcodeTable->{'resampleWhen'} eq 'E') && $transcodeTable->{'resampleTo'} eq 'X') {return 0;}

    # if we have only one possible target sample rate, just use it.
    
    if (($codec eq 'dsf'  || $codec eq 'dff') && (_countRates($transcodeTable->{'dsdRates'})== 1)){
		$transcodeTable->{'resampleTo'}='X';
        $transcodeTable->{'resampleWhen'}='A';
        return 0;
    }
    if (!($codec eq 'dsf'  || $codec eq 'dff') && (_countRates($transcodeTable->{'sampleRates'}) == 1)){
		$transcodeTable->{'resampleTo'}='X';
        $transcodeTable->{'resampleWhen'}='A';
        return 0;
    }
    
	# In windows STDIN does not works inside C3PO.
    # In Linux works, but we have unexpected stops in playlist, caused by borken pipe errors,
    # better alwais fault back to max samplerate resampling.
    
    if (_isStdInEnabled($transcodeTable)){
        $transcodeTable->{'resampleTo'}='X';
        $transcodeTable->{'resampleWhen'}='A';
        return 0;
	}
    
    return 1;
}
sub _buildProfile{
	my $transcodeTable = shift;
	
	if (isLMSDebug()) {
		$log->debug('Start _buildProfile');
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

sub _useC3PO{
	my $transcodeTable= shift;

	if (isLMSDebug()) {
		$log->debug('Start _useC3PO');
	} else {
        Plugins::C3PO::Logger::debugMessage('Start _useC3PO');
    }

	my $result={};

	my $macaddress= $transcodeTable->{'macaddress'};
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec=getOutputCodec($transcodeTable);
	my $prefFile = $transcodeTable->{'pathToPrefFile'};
	my $pathToC3PO_pl = $transcodeTable->{'pathToC3PO_pl'};
	my $logFolder = $transcodeTable->{'logFolder'};
	my $serverFolder = $transcodeTable->{'serverFolder'};
	
	
	$result->{'profile'} =  _buildProfile($transcodeTable);
	
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
		D => 'RESAMPLE=-r %d'
	};
	
	#Enable stdIn pipes (Quboz) but disable seek (cue sheets)
	# In windows I does not works insiede C3PO, so it's disabled.)
	
	if(_isStdInEnabled($transcodeTable) && !main::ISWINDOWS){

	#if(_isStdInEnabled($transcodeTable)){
	
		#Disabling "I" and enabling "T" and "U"  LMS will use R capabilities and 
		# pass the Qobuz link to C3PO, but it does not works, needs the quboz plugin pipe 
		# to be activated via I.
		
		$capabilities->{I}= 'noArgs';  
		#$capabilities->{T}='START=-s %s';
		#$capabilities->{U}='END=-w %w';
		
	} elsif (_isSeekEnabled($transcodeTable))  {

		$capabilities->{T}='START=-s %s';
		$capabilities->{U}='END=-w %w';
	}

	$result->{'capabilities'}=$capabilities;
	
	return $result;
}
sub _useServer {
	my $transcodeTable= shift;

	if (isLMSDebug()) {
		$log->debug('Start _useServer');
	}
	
	my $result={};

	$result->{'profile'} =  _buildProfile($transcodeTable);

	if (_isNative($transcodeTable)) {
	
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
		my $format= _getFormat($inCodec);

		if(_isStdInEnabled($transcodeTable)){

			# cue files will always play from the beginning of first track.
			$capabilities->{I}= 'noArgs';

			# enabling the following, track > 1 in cue file will not play at all.
			#$capabilities->{T}='START=--skip=%t';
			#$capabilities->{U}='END=--until=%v';

		}elsif (_isSeekEnabled($transcodeTable) && $format->useFFMpegToSplit($transcodeTable)){

			$capabilities->{T}='START=-ss %s';
			$capabilities->{U}='END=-t %w';

		} elsif (_isSeekEnabled($transcodeTable) && $format->useFAADToSplit($transcodeTable)){

			$capabilities->{T}='START=-j %s';
			$capabilities->{U}='END=-e %u';

		} elsif (_isSeekEnabled($transcodeTable)){ #use flac

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
sub _isNative{

	my $transcodeTable =shift;
	my $inCodec = $transcodeTable->{'inCodec'};
    
    if (! isTranscodingEnabled($transcodeTable) &&
        ! isResamplingEnabled($transcodeTable) &&
        ! areEffectsEnabled($transcodeTable))
        {return 1;}
    
	#if (! isTranscodingEnabled($transcodeTable) &&
	#	! _isSOXrequired($transcodeTable)) {return 1;}
	#	
	
    return 0;
}
################################################################
# C-3PO executable entry point.
################################################################

sub buildCommand {
	my $transcodeTable = shift;

	my $command="";
	
	if (isLMSInfo()) {
		$log->info('Start buildCommand');
	} else{
	
		Plugins::C3PO::Logger::infoMessage('Start buildCommand');
	}
	
	$transcodeTable=_normalizeCodecs($transcodeTable);
	
    my $willUseSOX;
	if (_isSOXrequired($transcodeTable)) {
	
		$transcodeTable= _checkResample($transcodeTable);
        $willUseSOX = _willUseSOX($transcodeTable);
	}
    
	#save incodec.
    my $inCodec = $transcodeTable->{'inCodec'};
	$transcodeTable->{'transitCodec'}=$inCodec;
    
    my $outCodec=getOutputCodec($transcodeTable);

	if (isLMSInfo()) {
		$log->info('inCodec: '.$transcodeTable->{'inCodec'});
		$log->info('transitCodec: '.$transcodeTable->{'transitCodec'});
		$log->info('outCodec: '.$outCodec);
        $log->info('Is resampling requested? '.isResamplingEnabled($transcodeTable));
        $log->info('Is SOX required? '._isSOXrequired($transcodeTable));
		$log->info('will SOX be Used ? '.$willUseSOX);
		$log->info('Is splitting requested? '._isSplittingRequested($transcodeTable));
	} else{
		Plugins::C3PO::Logger::infoMessage('inCodec: '.$transcodeTable->{'inCodec'});
		Plugins::C3PO::Logger::infoMessage('transitCodec: '.$transcodeTable->{'transitCodec'});
		Plugins::C3PO::Logger::infoMessage('outCodec: '.$outCodec);
		Plugins::C3PO::Logger::infoMessage('Is resampling requested? '.isResamplingEnabled($transcodeTable));
		Plugins::C3PO::Logger::infoMessage('Is SOX required? '._isSOXrequired($transcodeTable));
		Plugins::C3PO::Logger::infoMessage('will SOX be Used ? '.$willUseSOX);
		Plugins::C3PO::Logger::infoMessage('Is splitting requested? '._isSplittingRequested($transcodeTable));
	}
    
	if ($willUseSOX){
	
		$transcodeTable=_splitResampleAndTranscode($transcodeTable);
	
	} elsif (_isSplittingRequested($transcodeTable)){
		
		$transcodeTable=_splitAndTranscode($transcodeTable);

	} else {
		
		$transcodeTable=_transcodeOnly($transcodeTable);
		$transcodeTable->{'command'}=$transcodeTable->{transcode};
	
	}
	$command = $transcodeTable->{'command'}||"";
    
	if (isLMSInfo()) {
		$log->info('Transcode command: '.$command);
	} else{
		Plugins::C3PO::Logger::infoMessage('Transcode command: '.$command);
	}
	
	if ($command eq ""){
		
		if (isRuntime($transcodeTable)){

			# Using native to just pass IN to OUT via a dummy transcoder.
			$transcodeTable = _native($transcodeTable);

		} else {
			
			# Native LMS pipe method.
			$transcodeTable->{'command'}="-";		
		}
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::debugMessage('Safe command    : '.$command);
	
	if (_needRestoreHeader($transcodeTable)){
	
		$transcodeTable = _restoreHeader($transcodeTable);
	}
	$command = $transcodeTable->{'command'}||"";
	Plugins::C3PO::Logger::debugMessage('Final command    : '.$command);
    
	return $transcodeTable;
}

###############################################################################
# C-3PO sub cases
###############################################################################

sub _splitResampleAndTranscode{
	my $transcodeTable = shift;
	
	if (isLMSDebug()) {
		$log->debug('Start splitTranscodeAndResample')
	} else{
		Plugins::C3PO::Logger::debugMessage('Start splitTranscodeAndResample');
	}
	my $inCodec=$transcodeTable->{'inCodec'};
	my $format= _getFormat($inCodec);
	
	my $sox=$format->useSoxToTranscodeWhenResampling($transcodeTable);
	
	if (isLMSDebug()) {
		$log->debug("useSoxToTranscodeWhenResampling: ".$sox)
	} else{
		Plugins::C3PO::Logger::debugMessage("useSoxToTranscodeWhenResampling: ".$sox);
	}
 
	my $commandString;
	
	if (_isSplittingRequested($transcodeTable)){
		
		if (isLMSDebug()) {
			$log->debug('isSplittingRequested : 1')
		} else{
			Plugins::C3PO::Logger::debugMessage('isSplittingRequested : 1');
		}
        
        #no compression applied, we need to resample firts.
		$commandString=$format->splitBeforeResampling($transcodeTable);
			
	} elsif (_isAStdInPipe($transcodeTable)){
		
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

    my $resampleString = Plugins::C3PO::SoxHelper::resample($transcodeTable);

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
sub _splitAndTranscode{
	my $transcodeTable = shift;
	
	if (isLMSDebug()) {
		$log->debug('Start _splitAndTranscode')
	} else{
		Plugins::C3PO::Logger::debugMessage('Start _splitAndTranscode');
	}

	my $inCodec=$transcodeTable->{'inCodec'};
	$transcodeTable->{'transitCodec'}=$inCodec;
	
	my $format= _getFormat($inCodec);
	
	my $commandString="";
	$transcodeTable->{'command'}=$commandString;
	
	# SOx is not going to be called fo resampling, so we need to perform all
	# the transcoding in the split fase or immediatly after.
	
	if (_isSplittingRequested($transcodeTable)){
		
		#Split and encode to final codec when possible,
		$commandString=$format->splitAndEncode($transcodeTable);	
		$transcodeTable->{'command'}=$commandString;
	}
	
	if (isLMSDebug()) {
		$log->debug('Is transcoding Required? '.isTranscodingRequired($transcodeTable));
	} else{
		Plugins::C3PO::Logger::debugMessage('Is transcoding Required? '.isTranscodingRequired($transcodeTable));
	}

	if (isTranscodingRequired($transcodeTable)) {
	
		my $codec=$transcodeTable->{'transitCodec'};
		$format= _getFormat($codec);
		my $transcodeString = $format->transcode($transcodeTable);
		
		if (! ($transcodeString eq "")){
			$commandString= $commandString." | ".$transcodeString;
		}
		$transcodeTable->{'command'}=$commandString;
	}
	
	return $transcodeTable;
}
sub _transcodeOnly{
	my $transcodeTable = shift;
	
	if (isLMSDebug()) {
		$log->debug('Start transcode Only')
	} else{
		Plugins::C3PO::Logger::debugMessage('Start transcode Only');
	}

	my $inCodec=$transcodeTable->{'inCodec'};
	
	my $format= _getFormat($inCodec);
	my $commandstring="";
	
	if (isTranscodingRequired($transcodeTable)){
		$commandstring= $format->transcode($transcodeTable);
	}
	
	$transcodeTable->{transcode}=$commandstring; 
	return $transcodeTable;
}
sub _native{
	my $transcodeTable = shift;
	
	if (isLMSInfo()) {
		$log->info('Start _native')
	} else{
		Plugins::C3PO::Logger::infoMessage('Start _native');
	}
	
	# maybe transcoding and/or resampling was requested but is not needed
	# and we could not issue an empty command from C-3PO, '-' does not works, 
	# so let's use a 'dummy' transcoder.
	
	my $inCodec=$transcodeTable->{'transitCodec'};
	
	my $format= _getFormat($inCodec);
	my $commandstring="";
   
	$commandstring= $format->native($transcodeTable);
	
	$transcodeTable->{'command'}=$commandstring;
    
	Plugins::C3PO::Logger::debugMessage('commandstring is: '.($commandstring ? $commandstring :'undef'));
	
    return $transcodeTable;
}
###############################################################################
# Repair some LMS misuse
###############################################################################

sub _normalizeCodecs{
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

sub _checkResample{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::debugMessage('Start _checkResample');
	
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec= getOutputCodec($transcodeTable);
	
	my $isDsdInput = ($inCodec eq 'dsf'  || $inCodec eq 'dff') ? 1 : 0;
	my $isDsdOutput = ($outCodec eq 'dsf'  || $outCodec eq 'dff') ? 1 : 0;

	my $maxSupportedSamplerate = $transcodeTable->{'maxSupportedSamplerate'};
	my $samplerates=$transcodeTable->{'sampleRates'};
	my $maxsamplerate = _getMaxRate($samplerates,44100);
	
	my $maxSupportedDsdrate = $transcodeTable->{'maxSupportedDsdrate'};
	my $dsdrates=$transcodeTable->{'dsdRates'};
	my $maxDsdrate = _getMaxRate($dsdrates,0);

	Plugins::C3PO::Logger::debugMessage('$maxsamplerate :'.$maxsamplerate);
	Plugins::C3PO::Logger::debugMessage('sampleRates :'.Data::Dump::dump($samplerates));
	Plugins::C3PO::Logger::debugMessage('$maxDsdrate :'.$maxDsdrate);
	Plugins::C3PO::Logger::debugMessage('dsdrates :'.Data::Dump::dump($dsdrates));

	my $forcedSamplerate= $transcodeTable->{'options'}->{'forcedSamplerate'};
	my $resampleWhen= $transcodeTable->{'resampleWhen'};
	my $resampleTo= $transcodeTable->{'resampleTo'};

	my $file = $transcodeTable->{'options'}->{'file'};
	my $fileSamplerate;
	
	my $filedsdRate;
	my $isSupported;
	my $maxSyncrounusRate;
    my $targetRate;
	
	my $willStart=$transcodeTable->{'C3POwillStart'};
	
	if (isRuntime($transcodeTable) && defined $willStart && $willStart){
	
		my $testfile=$file;
		if (_isAStdInPipe($transcodeTable)){
			
			$testfile= _getTestFile($transcodeTable);
			Plugins::C3PO::Logger::debugMessage('testfile: '.$testfile);
			$transcodeTable->{'testfile'}=$testfile;
		}
        
        Plugins::C3PO::Logger::infoMessage('testfile: '.$testfile);
        my $audioFile = Plugins::C3PO::AudioFile->new($testfile,$logger,$log); 
        
		Plugins::C3PO::Logger::infoMessage('AudioScan: '.Data::Dump::dump ($audioFile));
		
        $transcodeTable->{'fileInfo'}=$audioFile->getFileInfo();
        
        Plugins::C3PO::Logger::infoMessage('transcodeTable fileInfo: '.Data::Dump::dump ($transcodeTable->{'fileInfo'}));
    
        $fileSamplerate     = $audioFile->getSamplerate();
        my $bitsPerSample   = $audioFile->getBitsPerSample();
        my $isFilesDsd      = $audioFile->isDsd();
        
        Plugins::C3PO::Logger::debugMessage('file samplerate: '.$fileSamplerate);
		Plugins::C3PO::Logger::debugMessage('bits Per Sample: '.($bitsPerSample ? $bitsPerSample : 0 ));
        
        if (($isDsdInput && !$isFilesDsd) || (!$isDsdInput && $isFilesDsd)){
		
			Plugins::C3PO::Logger::debugMessage("Inputtype is: ".$inCodec. 
				" bit per sample is: ".$bitsPerSample );

		} elsif ($isDsdInput) {
		
			$filedsdRate = $fileSamplerate/44100;

			Plugins::C3PO::Logger::debugMessage('isDsdIn: '.$isDsdInput);
			Plugins::C3PO::Logger::debugMessage('file dsdrate: '.$filedsdRate);
		
		}
		if ($fileSamplerate){

			$isSupported= _isSamplerateSupported(
									$fileSamplerate,
									$samplerates,
									$isDsdOutput,
									$filedsdRate,
									$dsdrates);
			
            $targetRate =  _getTargetRate($fileSamplerate,
										$samplerates,
										$isDsdOutput,
										$filedsdRate,
										$dsdrates,
                                        $resampleTo);
										   
			Plugins::C3PO::Logger::debugMessage('samplerate is '.($isSupported ? '' : 'not ').'supported');
			Plugins::C3PO::Logger::debugMessage('target rate : '.($targetRate ? $targetRate : ''));
		}
	}
	my $targetSamplerate;
	my $resamplestring="";
	
    #TODO check and change if input is DSD and not a 44100 multiple.
	$maxDsdrate = $maxDsdrate*44100;
		
	Plugins::C3PO::Logger::debugMessage('is runtime :                 '.(isRuntime($transcodeTable)));
	Plugins::C3PO::Logger::debugMessage('forced Samplerate :          '.($forcedSamplerate ? $forcedSamplerate :'undef'));
	Plugins::C3PO::Logger::debugMessage('resampleWhen :               '.$resampleWhen);
	Plugins::C3PO::Logger::debugMessage('file samplerate:             '.($fileSamplerate ? $fileSamplerate : 'undef'));
    Plugins::C3PO::Logger::debugMessage('is supported:                '.($isSupported ? 'Yes' : 'No'));
	Plugins::C3PO::Logger::debugMessage('resampleTo :                 '.$resampleTo);
	Plugins::C3PO::Logger::debugMessage('Max syncrounus sample rate : '.($maxSyncrounusRate ? $maxSyncrounusRate : 'undef'));
	Plugins::C3PO::Logger::debugMessage('isDsdinput :                 '.($isDsdInput? 'Yes' : 'No'));
    Plugins::C3PO::Logger::debugMessage('isDsdOutput :                '.($isDsdOutput? 'Yes' : 'No'));
	Plugins::C3PO::Logger::debugMessage('maxDsdrate :                 '.$maxDsdrate);
	Plugins::C3PO::Logger::debugMessage('maxsamplerate :              '.$maxsamplerate);
	
	
	# lms always force it to max samplerate.
	$forcedSamplerate = undef;

	if (!isRuntime($transcodeTable)){
		
		$targetSamplerate=$isDsdOutput ? $maxDsdrate : $maxsamplerate;
		
	} elsif (defined $forcedSamplerate && $forcedSamplerate>0){

		$targetSamplerate=$forcedSamplerate;

	} elsif ($resampleWhen eq'N'){ #do nothing, obsolete.
        
	} elsif (!$fileSamplerate){
	
		$targetSamplerate= $isDsdOutput ? $maxDsdrate : $maxsamplerate;;
	
	} elsif (($resampleWhen eq 'E') && ($isSupported)){ #do nothing
        
	} elsif (defined $targetRate){
	
		$targetSamplerate=$targetRate;
		
	} else {
		
		$targetSamplerate= $isDsdOutput ? $maxDsdrate : $maxsamplerate;
	}
	
	$transcodeTable->{'targetSamplerate'}=$targetSamplerate;
	
	Plugins::C3PO::Logger::debugMessage('Target Sample rate :         '.($targetSamplerate ? $targetSamplerate : "undef"));
	
	return $transcodeTable;
	
}

sub _willUseSOX{
	my $transcodeTable=shift;

	if (!_isSOXrequired($transcodeTable)) {return 0;}
	
	# Keep it short and always resample if asked for.
	#return 1;

	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec= getOutputCodec($transcodeTable);
	my $isDsdInput = ($inCodec eq 'dsf'  || $inCodec eq 'dff') ? 1 : 0;
	my $isDsdOutput = ($outCodec eq 'dsf'  || $outCodec eq 'dff') ? 1 : 0;
    
    # needs sdm. and maybe lowpass.
    if (!$isDsdInput && $isDsdOutput) {return 1;}
    if ($isDsdInput && !$isDsdOutput) {return 1;}
    if ($isDsdInput && !($inCodec eq $outCodec )) {return 1;}
    
	#Always process if any effect is requested
    Plugins::C3PO::Logger::debugMessage('isAnyEffectRequested :       '.(_isAnyEffectRequested($transcodeTable)));
    if (_isAnyEffectRequested($transcodeTable)) {return 1;}
    
	#Resample if sample rate or bit depth are different.
	my $targetSamplerate=$transcodeTable->{'targetSamplerate'};
	my $fileSamplerate = $transcodeTable->{'fileInfo'}->{info}->{samplerate};
	
	Plugins::C3PO::Logger::debugMessage("targetSamplerate: ".(defined $targetSamplerate ? $targetSamplerate : 'undef'));
	Plugins::C3PO::Logger::debugMessage("fileSamplerate: ".(defined $fileSamplerate ? $fileSamplerate : 'undef'));

	if (!defined $targetSamplerate) {return 1;}
	if (!$fileSamplerate || !($fileSamplerate == $targetSamplerate)){return 1;}

	my $targetBitDepth = $transcodeTable->{'outBitDepth'};
	my $fileBitDepth   = $transcodeTable->{'fileInfo'}->{info}->{bits_per_sample} ? 
							$transcodeTable->{'fileInfo'}->{info}->{bits_per_sample}/8 :
							undef;
	
	Plugins::C3PO::Logger::debugMessage("targetBitDepth: ".(defined $targetBitDepth ? $targetBitDepth : 'undef'));
	Plugins::C3PO::Logger::debugMessage("fileBitDepth: ".(defined $fileBitDepth ? $fileBitDepth : 'undef'));
	
	if (!defined $targetBitDepth) {return 1;}
	if (!$fileBitDepth || !($fileBitDepth == $targetBitDepth)){return 1;}
	
	return 0;
}

sub _isAnyEffectRequested{
    my $transcodeTable=shift;
    my $inCodec= $transcodeTable->{'inCodec'};
    
    if (! areEffectsEnabled($transcodeTable)) {return 0;}
    if (! isResamplingEnabled($transcodeTable) &&
        ! $transcodeTable->{'effectsWhen'} eq "A") {return 0;}
    
    if ($transcodeTable->{'gain'}) {return 1;}
	if ($transcodeTable->{'loudnessGain'}) {return 1;}
	if ($transcodeTable->{'remixLeft'} && !($transcodeTable->{'remixLeft'} eq 100)) {return 1;}
	if ($transcodeTable->{'remixRight'} && !($transcodeTable->{'remixRight'} eq 100)) {return 1;}
	if ($transcodeTable->{'flipChannels'}) {return 1;}
    
    if ($transcodeTable->{'extra_before_rate'} && !($transcodeTable->{'extra_before_rate'} eq "")) {return 1;}
	if ($transcodeTable->{'extra_after_rate'} && !($transcodeTable->{'extra_after_rate'} eq "")) {return 1;}
    return 0;
}
sub _countRates{
    my $rates= shift;
    my $count=0;
    
    for my $rs (keys %$rates){
		
		if ( $rates->{$rs}){
			$count = $count+1;
		}
	} 
    return $count;
}
sub _getMaxRate{
	my $rates= shift;
	my $faultback = shift;

	my $max=0;

	for my $rs (keys %$rates){
		
		my $rate = $rs/1;
		
		if (($rate>$max) && $rates->{$rs}){
			$max = $rate;
		}
	} 
	#Data::Dump::dump ($max);
	return (($max>0) ? $max : $faultback);
}
sub _getTestFile{
	my $transcodeTable =shift;
	
	my $fileName = "header.".$transcodeTable->{'inCodec'};
	my $outfile  = Plugins::C3PO::OsHelper::getTemporaryFile($fileName);
		
	Plugins::C3PO::Logger::debugMessage('out file : '.$outfile);
	
	_saveHeaderFile(\*STDIN, $outfile);
	
	Plugins::C3PO::Logger::debugMessage('returning : '.$outfile);
	return $outfile;
}

sub _isSamplerateSupported{
	my $fileSamplerate = shift;
	my $samplerates = shift;
	my $isDsd = shift;
	my $filedsdRate = shift;
    my $dsdrates = shift;
 
	if ($isDsd){
        if (!defined $filedsdRate || $filedsdRate==0){
		
			return undef;
        }
        for my $rate (keys %$dsdrates){

			if ($dsdrates->{$rate} && $filedsdRate==$rate) {return 1;}
		}
        
	} else{
        
		if (!defined $fileSamplerate || $fileSamplerate==0){
		
			return undef;
        }
        for my $rate (keys %$samplerates){

			if ($samplerates->{$rate} && $fileSamplerate==$rate) {return 1;}
		}
	}
	return 0;
}
sub _getTargetRate{
	my $fileSamplerate=shift;
	my $samplerates=shift;
	my $isDsd = shift;
	my $filedsdRate = shift;
    my $dsdrates = shift;
    my $sync= shift || "X";
	
	Plugins::C3PO::Logger::debugMessage('fileSamplerate : '.($fileSamplerate ? $fileSamplerate : ''));
	Plugins::C3PO::Logger::debugMessage('Samplerates : '.Data::Dump::dump($samplerates));
	Plugins::C3PO::Logger::debugMessage('is dsd : '.$isDsd);
	Plugins::C3PO::Logger::debugMessage('filedsdRate : '.($filedsdRate ? $filedsdRate : ''));
	Plugins::C3PO::Logger::debugMessage('dsdrates : '.Data::Dump::dump($dsdrates));
    Plugins::C3PO::Logger::debugMessage('sync : '.Data::Dump::dump($sync));

	if ($isDsd && (!defined $filedsdRate || $filedsdRate==0)){
	
		return undef;
	} 
	if (!$isDsd && (!defined $fileSamplerate || $fileSamplerate==0)){
		
		return undef;
	}
    $fileSamplerate= $fileSamplerate/1;
	
    my $ratefamily;
    my $fileRate;
	my $target=0;
    
	if ($isDsd){

		if ($fileSamplerate % 48000 == 0) {
		
			$ratefamily=48000;
	
		} else {
		
			$ratefamily=44100;
		}
        
        $fileRate= $fileSamplerate/$ratefamily;
        
        my $ratefamily = $sync eq "N" ? $ratefamily == 44100 ? 48000 : 44100 :  $ratefamily;
        
        $target = _getNextEnabledRate($fileRate, $dsdrates ,1, $sync)*$ratefamily;
       
	} else {
        
        if ($fileSamplerate % 11025 == 0) {

            $ratefamily=11025;

        } elsif ($fileSamplerate % 12000 == 0) {

            $ratefamily=12000;

        } elsif ($fileSamplerate % 8000 == 0) {

            $ratefamily=8000;

        } else {

            return undef;
        }
        
        $target = _getNextEnabledRate($fileSamplerate, $samplerates, $ratefamily, $sync);
    }
    
    Plugins::C3PO::Logger::debugMessage('target : '.Data::Dump::dump($target));
    
    return (($target && $target > 0) ? $target : undef);
	
}
sub _getNextEnabledRate{
    my $fileRate        = shift;
	my $rates           = shift;
    my $family          = shift || 1;
    my $sync            = shift || "X";
    
    Plugins::C3PO::Logger::debugMessage('fileRate : '.($fileRate ? $fileRate : ''));
	Plugins::C3PO::Logger::debugMessage('rates : '.Data::Dump::dump($rates));
	Plugins::C3PO::Logger::debugMessage('family : '.($family ? $family : ''));
    Plugins::C3PO::Logger::debugMessage('sync : '.Data::Dump::dump($sync));
    
    my $last=0;
    
	Plugins::C3PO::Logger::debugMessage('rates : '.Data::Dump::dump(sort { $a <=> $b } keys %$rates));
	for my $rate (sort { $a <=> $b } keys %$rates){
        
        Plugins::C3PO::Logger::debugMessage('rate : '.$rate);
        if (! $rates->{$rate}){next;}
        
        Plugins::C3PO::Logger::debugMessage('rate : '.$rate);
        Plugins::C3PO::Logger::debugMessage('family : '.$family);
        Plugins::C3PO::Logger::debugMessage('mod : '.($rate % $family));
        Plugins::C3PO::Logger::debugMessage('sync : '.$sync);
        Plugins::C3PO::Logger::debugMessage('$last : '.$last);
        Plugins::C3PO::Logger::debugMessage('fileRate : '.($fileRate ? $fileRate : ''));
        
        if (($rate % $family == 0) && ($sync eq "S") && ($rate > $last) ){
            
            $last = $rate;
            if ($rate >= $fileRate) {return $rate;}
        }
        
        if (!($rate % $family == 0) && ($sync eq "N") && ($rate > $last)){
            
            $last = $rate;
            if ($rate >= $fileRate) {return $rate;}
        }
       
        if (($sync eq "X") && ($rate > $last)){
        
            $last = $rate;
            if ($rate >= $fileRate) {return $rate;}
        }
        
    }
    if (($sync eq "S") && $last){ return $last;}
    if (($sync eq "N") && $last){ return $last;}
    
    if (!($sync eq "X")){
        
         return _getNextEnabledRate($fileRate, $rates, $family, "X");
    
    }
    return $last;
}
sub _saveHeaderFile{
	my $fh = shift;
	my $testHeaderFile = shift;
	
	my $head = FileHandle->new;
	$head->open("> $testHeaderFile") or die $!;
	binmode ($head);

	my $headbuffer;
	Plugins::C3PO::Logger::infoMessage('start reading from STDIN');
	
	if (
		sysread ($fh, $headbuffer, 8192)	# read in (up to) 8192 bit chunks, write
		and syswrite $head, $headbuffer	# exit if read or write fails
	) {};
	die "Problem writing: $!\n" if $!;
	
	flush $head;
	close $head;
	
	Plugins::C3PO::Logger::infoMessage('header file created');
	return 1;
}

sub _restoreHeader{
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
sub _isStdInEnabled{
	my $transcodeTable =shift;
	
	my $inCodec= $transcodeTable->{'inCodec'};
	
	my $enable = $transcodeTable->{'enableStdin'}->{$inCodec} ? 1 : 0;
	Plugins::C3PO::Logger::debugMessage("codec: $inCodec - isStdInEnabled: $enable");
	
	return $enable;
}
sub _isSeekEnabled{
	my $transcodeTable =shift;
	
	my $inCodec= $transcodeTable->{'inCodec'};
	
	my $enable = $transcodeTable->{'enableSeek'}->{$inCodec} ? 1 : 0;
	Plugins::C3PO::Logger::debugMessage("codec: $inCodec - _isSeekEnabled: $enable");
	
	return $enable;
}

sub _needRestoreHeader{
	my $transcodeTable =shift;
	
	my $testFile=$transcodeTable->{'testfile'};
	
	return (defined $testFile);

}
#####################################################################
# Transcoding flow control: general, not codec depending 
# TO BE MOVED in a NEW transcoder class.
#####################################################################

# should be _isLMSDebug
sub isLMSDebug{
	
	if ($logger && $logger->{DEBUGLOG} && $log && $log->is_debug) {return 1}
	return 0;
}
# should be _isLMSInfo
sub isLMSInfo{

	if (isLMSDebug()) {return 1;}
	if ($logger && $logger->{INFOLOG} && $log && $log->is_info) {return 1}
	return 0;
}
sub isRuntime{
	my $transcodeTable =shift;

	return (defined $transcodeTable->{'options'}->{clientId} ? 1 : 0)
}

sub _isSplittingRequested{
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
sub _isAStdInPipe {
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
sub isTranscodingEnabled{ 
    my $transcodeTable =shift;
    my $inCodec= $transcodeTable->{'inCodec'};
    return $transcodeTable->{'enableConvert'}->{$inCodec};  
}
sub isResamplingEnabled{
    my $transcodeTable =shift;
    my $inCodec= $transcodeTable->{'inCodec'};
    return $transcodeTable->{'enableResample'}->{$inCodec};  
}

sub areEffectsEnabled{
    my $transcodeTable =shift;
    my $inCodec= $transcodeTable->{'inCodec'};
    return $transcodeTable->{'enableEffects'}->{$inCodec};
    
}

sub _isSOXrequired{
	my $transcodeTable =shift;
	
	my $inCodec= $transcodeTable->{'inCodec'};
	my $outCodec= getOutputCodec($transcodeTable);
	
	Plugins::C3PO::Logger::debugMessage('In codec '.$inCodec);
	Plugins::C3PO::Logger::debugMessage('In codec '.$outCodec);
	Plugins::C3PO::Logger::debugMessage('enable Effects: '.
		(areEffectsEnabled($transcodeTable) ?  1 : 0));
    Plugins::C3PO::Logger::debugMessage('enable Resample: '.
		(isResamplingEnabled($transcodeTable) ? 1 : 0));
	
	Plugins::C3PO::Logger::debugMessage('resampleWhen: '.$transcodeTable->{'resampleWhen'});
	
    if (($outCodec eq 'dsf'  || $outCodec eq 'dff') &&
        isTranscodingEnabled($transcodeTable)){return 1;}
    
    if (isResamplingEnabled($transcodeTable)) {return 1;}
    
    if (areEffectsEnabled($transcodeTable) && 
        $transcodeTable->{'effectsWhen'} eq "A") {return 1;}

	return 0;
    
}

sub isTranscodingRequired{
	my $transcodeTable =shift;
	
	my $isRuntime	   = isRuntime($transcodeTable);
	my $inCodec		   = $transcodeTable->{'inCodec'};
	my $outCodec	   = getOutputCodec($transcodeTable);
	my $transitCodec   = $transcodeTable->{'transitCodec'};
    
	my $enableConvert  = isTranscodingEnabled($transcodeTable);
	
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
		Plugins::C3PO::Logger::debugMessage('enableConvert '.($enableConvert ? '1' : '0'));
	}
	
	if (! $isRuntime && ! $enableConvert) {return 0;}
	if (compareCodecs($transitCodec, $outCodec)) {return 0;}
    
    return 1;
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
	if (isTranscodingEnabled($transcodeTable)){return $outCodec;}
	
	if (isResamplingEnabled($transcodeTable) && 
	    compareCodecs($inCodec, 'alc')){return $outCodec;}
        
    if (areEffectsEnabled($transcodeTable) && 
	    compareCodecs($inCodec, 'alc')){return $outCodec;}

	return $inCodec;
}

#NOT TO BE USED with ALAC input.	
# encode to the output codec (FLAC) )wile resampling, 
# no meaning if not resampling.

sub useSoxToEncodeWhenResampling {
	my $transcodeTable =shift;

	my $inCodec=$transcodeTable->{'transitCodec'};
	
	my $format= _getFormat($inCodec);
	return $format->useSoxToEncodeWhenResampling($transcodeTable);
}
###############################################################################
# Get procedure details depending on the input format.
###############################################################################
	
sub _getFormat{
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
	
	} elsif ($inCodec eq 'dsf'){

		$format = Plugins::C3PO::Formats::Dsf->new($logger, $log);
	
	}elsif ($inCodec eq 'dff'){

		$format = Plugins::C3PO::Formats::Dff->new($logger, $log);
		
	} else{
	
		Plugins::C3PO::Logger::errorMessage("unknown format: ".$inCodec);
		return undef;
	}
	Plugins::C3PO::Logger::debugMessage("in codec: ".$inCodec);
	Plugins::C3PO::Logger::debugMessage("using format: ".$format->toString());
	return $format;
}

1;
