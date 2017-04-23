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
#
package Plugins::C3PO::Shared;

use strict;
use warnings;
use Data::Dump qw(dump pp);

my @clientPrefNamesScalar = qw(	id macaddress model modelName name 
								maxSupportedSamplerate maxSupportedDsdrate
								enableSeek enableStdin 
								enableConvert enableResample enableEffects
								showDetails);
								
my @clientPrefNamesHash	  = qw(	sampleRates dsdRates);

my @clientPrefNames= @clientPrefNamesScalar;
push @clientPrefNames, @clientPrefNamesHash;

my @sharedPrefNames		  = qw(	enable panel
								
								headroom gain 
                                                                
                                outCodec 
                                
                                resampleTo
								quality phase aliasing noIOpt highPrecisionClock 
								smallRollOff bandwidth  
								
								
                                effectsWhen
								loudnessGain loudnessRef 
								remixLeft remixRight flipChannels
                                extra_before_rate extra_after_rate
                                
								outBitDepth ditherType ditherPrecision
								
								sdmFilterType
                                
								dsdLowpass1Value dsdLowpass1Order 
								dsdLowpass2Value dsdLowpass2Order dsdLowpass2Active	
								dsdLowpass3Value dsdLowpass3Order dsdLowpass3Active
								dsdLowpass4Value dsdLowpass4Order dsdLowpass4Active	
								
								); #resampleWhen
				
my @globalPrefNames		  = qw(	codecs soxMultithread soxBuffer unlimitedDsdRate  
                                serverFolder logFolder C3POfolder pathToPrefFile
								pathToFlac pathToSox pathToFaad pathToFFmpeg
								pathToC3PO_exe pathToC3PO_pl pathToPerl
								C3POwillStart soxVersion isSoxDsdCapable
								pathToHeaderRestorer_pl pathToHeaderRestorer_exe);

sub getTranscoderTableFromPreferences{
	my $preferences= shift; #The Preferene instance here.
	my $client=shift; #The Client instance here.
	
	$preferences->all();
	
	my $clientString= buildClientString($client->id());
	my $prefs= prefsToHash($preferences,$client);
	
	#dump ($prefs);
	#dump (getTranscoderTable($clientString,$prefs));
	
	return (getTranscoderTable($clientString,$prefs));
}

sub getTranscoderTable{
	my $clientString=shift; #the client sting here
	my $prefs= shift; #the pref hash here
	
	return (buildTranscoderTable($clientString,$prefs));	
}

sub prefsToHash{
	my $prefs= shift; #The Preferene instance here.
	my $client=shift; #The Client instance here.
	
	my $hash={};
	
	for my $i (getGlobalPrefNameList()){
		
		$hash->{$i}=$prefs->get($i);
	}
	for my $i (getSharedPrefNameList()){

		$hash->{$i}=$prefs->get($i);
	}
	if (defined $client){ 

		my $clientString= buildClientString(
							$prefs->client($client)->get('id'));
		
		$hash->{$clientString}->{'useGlogalSettings'}=
			$prefs->client($client)->get('useGlogalSettings');
			
		for my $i (getClientPrefNameList()){

			$hash->{$clientString}->{$i}=$prefs->client($client)->get($i);
		}
		for my $i (getSharedPrefNameList()){

			$hash->{$clientString}->{$i}=$prefs->client($client)->get($i);
		}
	} 

	return $hash;
}

sub buildTranscoderTable{
	my $clientString=shift; #the client sting here
	my $prefs= shift; #the pref hash here
	my $options =shift; #the options hash here
	
	my $transcodeTable={};
	for my $i (getClientPrefNameScalarList()){
		
		$transcodeTable->{$i}=$prefs->{$clientString}->{$i};
		
	}
	my $samplerates = $prefs->{$clientString}->{'sampleRates'};
	
    my $countSampleRates= 0;
    my $countDSDRates= 0;
	
    for my $krate (keys %$samplerates){
	
		my $rate = $prefs->{$clientString}->{'sampleRates'}->{$krate};
		
		if (defined $rate and ($rate)){
            
            $countSampleRates = $countSampleRates+1;
			$transcodeTable->{'sampleRates'}->{$krate}=1;
		
		} elsif (defined $rate and $rate eq '0' ){
		
			$transcodeTable->{'sampleRates'}->{$krate}=0;
			
		} else {
		
			$transcodeTable->{'sampleRates'}->{$krate}=undef;
		}
	}
	my $dsdrates = $prefs->{$clientString}->{'dsdRates'};
	
	for my $krate (keys %$dsdrates){
        
		my $rate = $prefs->{$clientString}->{'dsdRates'}->{$krate};
		
		if (defined $rate and ($rate)){
            
            $countDSDRates = $countDSDRates+1;
			$transcodeTable->{'dsdRates'}->{$krate}=1;
		
		} elsif (defined $rate and $rate eq '0' ){
		
			$transcodeTable->{'dsdRates'}->{$krate}=0;
			
		} else {
		
			$transcodeTable->{'dsdRates'}->{$krate}=undef;
		}
	}
    
    #not used anymore but still in the code.
	my $useGlogalSettings=$prefs->{$clientString}->{'useGlogalSettings'};
    
    for my $i (getSharedPrefNameList()){
		
		$transcodeTable->{$i}= $useGlogalSettings ?
					$prefs->{$i} : $prefs->{$clientString}->{$i};
		
	}

	for my $i (getGlobalPrefNameList()) {
	
		$transcodeTable->{$i}=$prefs->{$i};
	}

	if (defined $options){
	
		$transcodeTable->{'options'}=convertStartDuration($options);
		if ($options->{'logFolder'}) {
			$transcodeTable->{'logFolder'} = $options->{'logFolder'};
		}
	}
    
    # if user selted more (or less) )than one possible target sample rate, 
    # we should investigate the the actual file and detect the best fitting target.
    # Replace RESAMPLE WHEN control.

    warn "******************************************* $countSampleRates";
    warn "******************************************* $countDSDRates";
    
    if (($countSampleRates == 1) && ($countDSDRates == 1)) {
        
        #Always to the the only (max) samplerate enabled.
        $transcodeTable->{'resampleWhen'}='A';
        $transcodeTable->{'resampleTo'}='X';
        warn "******************************************* Only ONE";
        
    }elsif  (($countSampleRates == 0) && ($countDSDRates == 0)){
    
        #Invalid setting, disable resampling.
        $transcodeTable->{'resampleWhen'}='N';
        
    }else {
        
        # On exception, when the actual sample rate is not supported, to the next 
        # (or previous if greater than the last) enabled sample rate.
        
        $transcodeTable->{'resampleWhen'}='E';
    }

	# split codec name and compression factor (for flac).
	my $outCodec= $transcodeTable->{'outCodec'};
	$transcodeTable->{'outCompression'}=undef;
	
	if (length($outCodec)>3){
		
		$transcodeTable->{'outCodec'}=substr($outCodec, 0,3);
		
		if ($transcodeTable->{'outCodec'} eq 'flc'){

			my $compression= substr($outCodec, 3,1);
			
			if (!defined $compression) {$compression=5;}
			
			$compression = ( grep { $compression eq $_ } 0,5,8 ) ? $compression : 5;
			
			$transcodeTable->{'outCompression'}=$compression;
		}
	}

	return $transcodeTable;
} 

sub buildClientString{
	my $clientId = shift;

	$clientId =~ s/-/:/g;
	return '_client:'.$clientId;
}

sub getClientPrefNameList{
	
	return @clientPrefNames;
}
sub getSharedPrefNameList{
	
	return @sharedPrefNames;
}
sub getGlobalPrefNameList{
	
	return @globalPrefNames;
}
sub getClientPrefNameScalarList{
	
	return @clientPrefNamesScalar;
}
sub convertStartDuration{
	my $options=shift;

	Plugins::C3PO::Logger::verboseMessage('options in '.Data::Dump::dump($options));
	
	#$options->{startTime}=undef;   # t
	#$options->{endTime}=undef;     # v
	#$options->{startSec}=undef;    # s
	#$options->{endSec}=undef;      # u
	#$options->{durationSec}=undef; # w

    my $durationSec			= $options->{durationSec};
	my $startSec			= $options->{startSec}||0;

    if ($durationSec){
        $options->{endSec}		= $durationSec+$startSec;
        }

	$options->{startTime}	= $options->{startSec} ? 
								fracSecToMinSec($startSec) : undef;
								
	$options->{endTime}		= $options->{endSec} ? 
								fracSecToMinSec($options->{endSec}) : undef;
						
	return $options;
}

sub fracSecToMinSec {
	my $seconds = shift;

	my ($min, $sec, $frac, $fracrounded);

	$min = int($seconds/60);
	$sec = $seconds%60;
	$sec = "0$sec" if length($sec) < 2;
	
	# We want to round the last two decimals but we
	# always round down to avoid overshooting EOF on last track
	$fracrounded = int($seconds * 100) + 100;
	$frac = substr($fracrounded, -2, 2);
	
	return "$min:$sec.$frac";
}
sub finalizeCommand{
	my $command=shift;
	
	if (!defined $command || $command eq "") {return ""}

	if (main::ISWINDOWS){

		# command could not start with ", should move it after the volume ID.
		if (substr($command,0,1) eq '"'){

			my $str= substr($command,2,length($command)-2);
			my $vol= substr($command,1,1);
			
			$command=$vol.'"'.$str;
		}
	}
	return $command;
}
sub unstringVersion{
	my $versionString = shift;
	my $log = shift;
	
	my @versionArray = split /[.]/, $versionString;
	
	my $major;
	my $minor;
	my $patchlevel;
	my $extra;
	
	my $patchlevelString;
	
	$major=$versionArray[0];
	$minor=$versionArray[1];
	
	if ((scalar @versionArray) == 4) {
	
		$extra=$versionArray[3];
	
	} elsif ((scalar @versionArray) == 3) {
		
		$patchlevelString=$versionArray[2];
		
		if (!Scalar::Util::looks_like_number($patchlevelString)) {

			for (my $i=0; $i <= length($patchlevelString); $i++){
				
				my $c= substr($patchlevelString,$i,1);
				
				if (Scalar::Util::looks_like_number($c)){
				
					$patchlevel=$patchlevel.$c;
					
				} else{

					$extra= substr($patchlevelString,$i,length($patchlevelString));
					last;
				}
			}
		} else {
		
			$patchlevel = $patchlevelString;
		}
		
		if (!$patchlevel){
		
			$patchlevel=0;
			
		} elsif ($patchlevel*1 >99){
			
			$extra = substr($patchlevel,0,length($patchlevel)).($extra ? $extra : '');
			$patchlevel = substr($patchlevel,0,2);
		}
		
	} else{
	
		$log->warn('WARNING: invalid version string: '.$versionString);
		return undef;
	}

	if ($minor*1 > 99) {
		warn('WARNING: invalid version string: '.$versionString);
		return undef;
	}
	
	my $version = $major*10000 + $minor *100 + $patchlevel;
	
	if ($version == 0) {
		$log->warn('WARNING: invalid version string: '.$versionString);
		return undef;
	}
	
	return $version, $extra;
}
1;