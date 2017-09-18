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

	
package Plugins::C3PO::SoxHelper;

use strict;
use warnings;
use Data::Dump qw(dump pp);

sub resample{
	my $transcodeTable = shift;
    
    ############################################################################
    #
    # NOTE: depending on parameters could be called also if resampling (rate)
    # is not strictly requuired, I.E. when effect are required but sample rate is
    # the same. 
    #
    
    ############################################################################
    #  get values
    #

    my $isRuntime = Plugins::C3PO::Transcoder::isRuntime($transcodeTable);
	
	my $isTranscodingRequired = 
		Plugins::C3PO::Transcoder::isTranscodingRequired($transcodeTable);
	
	my $useSoxToEncodeWhenResampling =
		Plugins::C3PO::Transcoder::useSoxToEncodeWhenResampling($transcodeTable);
	
	my $inCodec				=$transcodeTable->{'transitCodec'};
	my $outCodec			=Plugins::C3PO::Transcoder::getOutputCodec($transcodeTable);
	
	my $exe					=$transcodeTable->{'pathToSox'};
	my $soxVersion			=$transcodeTable->{'soxVersion'} || 0;
	my $isSoxDsdCapable		=$transcodeTable->{'isSoxDsdCapable'};
	
	my $command				=$transcodeTable->{'command'};
    
    my $outSamplerate       =$transcodeTable->{'targetSamplerate'};
    
	my $outBitDepth			=$transcodeTable->{'outBitDepth'};
	my $outCompression		=$transcodeTable->{'outCompression'};
	my $quality				=$transcodeTable->{'quality'};
	my $phase				=$transcodeTable->{'phase'};
	my $aliasing			=$transcodeTable->{'aliasing'};
	my $noIOpt				=$transcodeTable->{'noIOpt'};
	my $highPrecisionClock	=$transcodeTable->{'highPrecisionClock'};
	my $bandwidth			=$transcodeTable->{'bandwidth'};
	my $smallRollOff		=$transcodeTable->{'smallRollOff'};

	my $extra_before_rate	=$transcodeTable->{'extra_before_rate'};
	my $extra_after_rate	=$transcodeTable->{'extra_after_rate'};

	my $ditherType			=$transcodeTable->{'ditherType'};
	my $ditherPrecision		=$transcodeTable->{'ditherPrecision'};

	my $sdmFilterType		=$transcodeTable->{'sdmFilterType'};

	my $dsdLowpass1Value	=$transcodeTable->{'dsdLowpass1Value'} || 50;
	my $dsdLowpass1Order	=$transcodeTable->{'dsdLowpass1Order'} || 2;

	my $dsdLowpass2Value	=$transcodeTable->{'dsdLowpass2Value'};
	my $dsdLowpass2Order	=$transcodeTable->{'dsdLowpass2Order'};
	my $dsdLowpass2Active	=$transcodeTable->{'dsdLowpass2Active'};

	my $dsdLowpass3Value	=$transcodeTable->{'dsdLowpass3Value'};
	my $dsdLowpass3Order	=$transcodeTable->{'dsdLowpass3Order'};
	my $dsdLowpass3Active	=$transcodeTable->{'dsdLowpass3Active'};

	my $dsdLowpass4Value	=$transcodeTable->{'dsdLowpass4Value'};
	my $dsdLowpass4Order	=$transcodeTable->{'dsdLowpass4Order'};
	my $dsdLowpass4Active	=$transcodeTable->{'dsdLowpass4Active'};

	my $file				=$transcodeTable->{'options'}->{'file'};
	
	Plugins::C3PO::Logger::verboseMessage('Start sox resample');
    
    ############################################################################
	# Multithread option and buffer
    
    my $execOptions= _execOptions($transcodeTable);
   
    ###########################################################################è
	# gain -h -3
    #
    my $gain= _gain($transcodeTable);
    
	############################################################################
    # translate codecs into sox language
    #
	$inCodec =_translateCodec($inCodec);
	
	if ($isTranscodingRequired &&
		$useSoxToEncodeWhenResampling){
		
		$outCodec=_translateCodec($outCodec);
		
	} else{
	
		$outCodec=$inCodec;
	}
    
	my $isDsdInput = ($inCodec eq 'dsf'  || $inCodec eq 'dff') ? 1 : 0;
	my $isDsdOutput = ($outCodec eq 'dsf'  || $outCodec eq 'dff') ? 1 : 0;
    
    ############################################################################
	# Preparing commandline
    #
    my $commandString;
	
	if ($isRuntime){
	
		$commandString = qq("$exe" );
	
	} else {
	
		$commandString = '[sox] ';
	}
	
	if ((!defined $command) || ($command eq "")){

		if ($isRuntime){
			
			$commandString = $commandString.qq(-q -t $inCodec "$file" -t );
		
		}else{
		
			$commandString = $commandString."-q -t $inCodec ".'$FILE$'." -t ";
		}
		

	} else {
	
		$commandString = $commandString.qq(-q -t $inCodec - -t );

	}
    
	$transcodeTable->{'transitCodec'}= _translateCodec($outCodec);

    ############################################################################
    # compression -C 8
    #
	my $outFormatSpec="";
	if ($outCompression){$outFormatSpec= '-C '.$outCompression};
    
    ###########################################################################è
    # effects loudness -6 65 remix -m 1v0.94 2
    #
	my $effects=_effects($transcodeTable);

    my $lowpass='';
    my $sdm='';
    my $rateString='';
    Plugins::C3PO::Logger::debugMessage('SOX output samplerate: '.($outSamplerate ? $outSamplerate : 'undef'));
    
    if ($outSamplerate) {
            
        ############################################################################
        # RATE (resamling command) # rate -v -L -n -t -a -b 90.7 -f 192000
        #
        $rateString= ' rate';

        $aliasing					= $aliasing ? "a" : undef;
        $noIOpt						= $noIOpt ? "n" : undef;
        $highPrecisionClock			= $highPrecisionClock ? "t" : undef;
        $smallRollOff				= $smallRollOff? "f" : undef;

        $bandwidth					=($bandwidth/10)."";

        if ($quality){$rateString= $rateString.' -'.$quality};
        if ($phase){$rateString= $rateString.' -'.$phase};
        if (($soxVersion > 140401) && $noIOpt){$rateString= $rateString.' -'.$noIOpt};
        if (($soxVersion > 140401) && $highPrecisionClock){$rateString= $rateString.' -'.$highPrecisionClock};
        if ($aliasing){$rateString= $rateString.' -'.$aliasing};
        if ($bandwidth){$rateString= $rateString.' -b '.$bandwidth};
        if (($soxVersion > 140401) && $smallRollOff){$rateString= $rateString.' -'.$smallRollOff};
        if ($outSamplerate){$rateString= $rateString.' '.$outSamplerate};
    
    }
    if ($isDsdInput && ($outSamplerate || !($effects eq '')) ){
        
        ############################################################################
        # LOWPASS filter to be applied when input is DSD 
        #
        $lowpass = $lowpass.'lowpass -'.$dsdLowpass1Order.' '.$dsdLowpass1Value*1000;

        if ($dsdLowpass2Active){
            $lowpass = $lowpass.' lowpass -'.$dsdLowpass2Order.' '.$dsdLowpass2Value*1000;
        }
        if ($dsdLowpass3Active){
            $lowpass = $lowpass.' lowpass -'.$dsdLowpass3Order.' '.$dsdLowpass3Value*1000;
        }
        if ($dsdLowpass4Active){
            $lowpass = $lowpass.' lowpass -'.$dsdLowpass4Order.' '.$dsdLowpass4Value*1000;
        }
    }
     if ($isDsdOutput && ($outSamplerate || !($effects eq '')) ){
         
        ############################################################################
        # SDM to by applied only to DSD output

        if (!$sdmFilterType || ($sdmFilterType eq -1) ){

            $sdm = $sdm.''; #no sdm 

        } elsif ($sdmFilterType eq 'auto'){

            $sdm = $sdm.' sdm'; #auto
            $sdm = $sdm._sdmTrellis($transcodeTable);

        } else {

            $sdm = $sdm.' sdm -f '.$sdmFilterType;
            $sdm = $sdm._sdmTrellis($transcodeTable);
        }
    
    } 

    ############################################################################
    # bit depth -b 24
    #
    my $outBitDepthSpec='';
    
    if ($isDsdOutput){

        $outBitDepthSpec = '-b 1';

    } elsif ($outBitDepth){

        $outBitDepthSpec= '-b '.$outBitDepth*8;
    }
    
    my $dither='';
    if (! $isDsdOutput){
        
    ###########################################################################
    # DITHER, to be applied only when OUTPUT IS PCM.
 
        if (! $ditherType || ($ditherType eq -1)) {
            $dither = ' -D'; #disabled
        } elsif ($ditherType eq 1 ){
            # nothing to add, auto.
        }elsif ($ditherType eq 2 ){
            $dither = ' dither'; #default
        }elsif ($ditherType eq 3 ){
            $dither = ' dither -S';
        }elsif ($ditherType eq 4 ){
            $dither = ' dither -s';
        }elsif ($ditherType eq 5 ){
            $dither = ' dither -f lipshitz';
        }elsif ($ditherType eq 6 ){
            $dither = ' dither -f f-weighted';
        }elsif ($ditherType eq 7 ){
            $dither = ' dither -f modified-e-weighted';
        }elsif ($ditherType eq 8 ){
            $dither = ' dither -f improved-e-weighted';
        }elsif ($ditherType eq 9 ){
            $dither = ' dither -f gesemann';
        }elsif ($ditherType eq 'A' ){
            $dither = ' dither -f shibata';
        }elsif ($ditherType eq 'B' ){
            $dither = ' dither -f low-shibata';
        }elsif ($ditherType eq 'C' ){
            $dither = ' dither -f high-shibata';
        }
        
        if ($ditherType && $ditherPrecision && ($ditherPrecision > 0) && ($soxVersion > 140400)){
            $dither = $dither.' -p '.$ditherPrecision;
        }
    }
    ############################################################################ 
    # build the effect chain
    #
    my $chain="";
	
    if ($lowpass && !($lowpass eq "")){

        $chain	= $chain.' '.$lowpass;
    }
    if ($gain && !($gain eq "")){

        $chain = $chain.' '.$gain;
    }

    if ($effects && !($effects eq "")){

        $chain = $chain.' '.$effects;
    }

    if ($extra_before_rate && !($extra_before_rate eq "")){

        $chain = $chain.' '.$extra_before_rate;
    }
    if ($rateString && !($rateString eq "")){

        $chain = $chain.' '.$rateString;
    }   
    
    if ($extra_after_rate && !($extra_after_rate eq "")){

        $chain = $chain." ".$extra_after_rate;
    }

	if ($isDsdOutput && $sdm && !($sdm eq "")){
		
		$chain= $chain.' '.$sdm;
		
	} elsif (!$isDsdOutput && $dither && !($dither eq "")){
	
		$chain= $chain.' '.$dither;
	} 
    
	############################################################################

	$commandString = $commandString.qq($outCodec $outFormatSpec $outBitDepthSpec $execOptions - $chain);

	return $commandString;

}

sub transcode{
	my $transcodeTable = shift;
	
    ############################################################################
	# Multithread option and buffer
    
    my $execOptions= _execOptions($transcodeTable);
    
    ###########################################################################è
	# gain -h -3
    #
    my $gain= _gain($transcodeTable);
    
    ############################################################################
    
	my $isRuntime		= Plugins::C3PO::Transcoder::isRuntime($transcodeTable);
	
	my $inCodec			= $transcodeTable->{'transitCodec'};
	my $outCodec		= Plugins::C3PO::Transcoder::getOutputCodec($transcodeTable);
	my $file			= $transcodeTable->{'options'}->{'file'};
	my $command			= $transcodeTable->{'command'};
	my $outCompression	= $transcodeTable->{'outCompression'};
	my $exe				= $transcodeTable->{'pathToSox'};
	
	Plugins::C3PO::Logger::verboseMessage('Start soxTranscode');

	$inCodec=_translateCodec($inCodec);
	$outCodec=_translateCodec($outCodec);

	my $commandString = "";
	
	if (!defined ($command)|| ($command eq "")){
		
		if ($isRuntime){
			
			$commandString = qq(-q -t $inCodec "$file" -t $outCodec );
		
		}else{
		
			$commandString = "-q -t $inCodec ".'$FILE$'." -t $outCodec ";
		}
		
	} else {
		
		$commandString = qq(-q -t $inCodec - -t $outCodec );
	}

	if ($outCompression){
		$commandString = $commandString.'-C '.$outCompression.' ';
	}
	
	if ($isRuntime){

		$commandString = qq("$exe" $commandString);
	
	} else{
	
		$commandString = '[sox] '.$commandString;
	}
    
	$commandString = qq($commandString - $execOptions $gain);

	return $commandString;
}

sub _execOptions{
    my $transcodeTable = shift;

    my $soxMultithread      = $transcodeTable->{'soxMultithread'};
    my $soxBuffer           = $transcodeTable->{'soxBuffer'};
    
    $soxBuffer = $soxBuffer ? $soxBuffer : 8;
    my $execOptions = "--buffer ".$soxBuffer*1024;
    my $multiOptions = qq(--multi-threaded);

    if ($soxMultithread) {
        
        $execOptions = qq ($execOptions $multiOptions);
    } 
    
    return $execOptions;
}
sub _gain{
    my $transcodeTable = shift;
    
    my $headroom			=$transcodeTable->{'headroom'};
	my $gain				=$transcodeTable->{'gain'};
    
    my $effects="";
    
    if ($headroom && $gain){$effects= $effects.' gain -h -'.$gain;}
    
	elsif ($headroom){$effects= $effects.' gain -h';}
	
	elsif ($gain){$effects= $effects.' gain -'.$gain;}
    
    return $effects;
    
}
sub _sdmTrellis{
    my $transcodeTable = shift;
    
    my $sdmTrellis              =$transcodeTable->{'sdmTrellis'};
    my $sdmTrellisOrder         =$transcodeTable->{'sdmTrellisOrder'};
    my $sdmTrellisNum           =$transcodeTable->{'sdmTrellisNum'};
    my $sdmTrellisLatency       =$transcodeTable->{'sdmTrellisLatency'};
    my $sdmTrellisOrderActive	=$transcodeTable->{'sdmTrellisOrderActive'};
    my $sdmTrellisNumActive		=$transcodeTable->{'sdmTrellisNumActive'};
    my $sdmTrellisLatencyActive =$transcodeTable->{'sdmTrellisLatencyActive'};
    
    my $out="";
    
    if ($sdmTrellis && ($sdmTrellisOrderActive || $sdmTrellisNumActive || $sdmTrellisLatencyActive)){
        $out=" ";
    } else {return "";}
   
    if ($sdmTrellisOrderActive){ # 3 - 32, def 13.
        
        $sdmTrellisOrder = $sdmTrellisOrder ? $sdmTrellisOrder : 13;
        $out = qq($out -t $sdmTrellisOrder);
        
    }
    if ($sdmTrellisNumActive){
        $sdmTrellisNum = $sdmTrellisNum ? $sdmTrellisNum : 8; # 4 -32, def. 8.
        $out = qq($out -n $sdmTrellisNum); 
    
    }
    if ($sdmTrellisLatencyActive){
        $sdmTrellisLatency = $sdmTrellisLatency ? $sdmTrellisLatency : 1024;
        $out = qq($out -l $sdmTrellisLatency); # 100 - 2048, def 1024.
    
    }
    return $out;
}
sub _effects{
    my $transcodeTable = shift;
    
    # BE SURE not to use transitCodec here.
    my $inCodec             =$transcodeTable->{'inCodec'};
    my $outSamplerate       =$transcodeTable->{'targetSamplerate'};
    
    if (!$transcodeTable->{'enableEffects'}->{$inCodec}){return '';}
    if ($transcodeTable->{'effectsWhen'} eq "N"){return '';}
    if ($transcodeTable->{'effectsWhen'} eq "R" && !$outSamplerate){return '';}
   
    my $loudnessGain		=$transcodeTable->{'loudnessGain'};
	my $loudnessRef			=$transcodeTable->{'loudnessRef'};
	my $remixLeft			=$transcodeTable->{'remixLeft'};
	my $remixRight			=$transcodeTable->{'remixRight'};
	my $flipChannels		=$transcodeTable->{'flipChannels'};

    my $effects='';

	if ($loudnessGain){$effects= $effects.' loudness '.$loudnessGain.' '.$loudnessRef};
	
	my $leftCh = 1;
	my $rightCh = 2;
	
	if ($flipChannels){
	
		$leftCh = 2;
		$rightCh = 1;
	
	}
    
	my $leftVol		= $remixLeft  < 100 ? $leftCh.'v'.$remixLeft/100 : "";
	my $rightVol	= $remixRight < 100 ? $rightCh.'v'.$remixRight/100 : "";
	
	if (!($leftVol eq "") && !($rightVol eq "")){
		
		$effects= $effects.' remix -m '.$leftVol.' '.$rightVol;
		
	} elsif (!($leftVol eq "")){
	
		$effects= $effects.' remix -m '.$leftVol.' '.$rightCh;
		
	} elsif (!($rightVol eq "")){
	
		$effects= $effects.' remix -m '.$leftCh.' '.$rightVol;
		
	} elsif ($flipChannels){ #already flipped
	
		$effects= $effects.' remix -m '.$leftCh.' '.$rightCh;
	}
	#nothing to add if not flipped.
    
    return $effects;
}
sub _translateCodec{
	my $codec= shift;
	
	if ($codec eq 'flc') {return 'flac';}
	if ($codec eq 'flac') {return 'flc';}
	return $codec;
}

1;
