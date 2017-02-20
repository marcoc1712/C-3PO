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
# TODO:
# Remove $outByteOrder from parameters, should not be changed
# and handled directly by SOX for different codecs.
	
package Plugins::C3PO::SoxHelper;

use strict;
my $stdBuffer = 8192; #44100/16
my $buffer= $stdBuffer;

sub resample{
	my $transcodeTable = shift;
	my $outSamplerate= shift;
	
	my $isRuntime = Plugins::C3PO::Transcoder::isRuntime($transcodeTable);
	
	my $isTranscodingRequired = 
		Plugins::C3PO::Transcoder::isTranscodingRequired($transcodeTable);
	
	my $useSoxToEncodeWhenResampling =
		Plugins::C3PO::Transcoder::useSoxToEncodeWhenResampling($transcodeTable);
	
	my $soxVersion			=$transcodeTable->{'soxVersion'};
	my $isSoxDsdCapable		=$transcodeTable->{'isSoxDsdCapable'};

	my $outBitDepth			=$transcodeTable->{'outBitDepth'};
	my $outCompression		=$transcodeTable->{'outCompression'};
	my $quality				=$transcodeTable->{'quality'};
	my $phase				=$transcodeTable->{'phase'};
	my $aliasing			=$transcodeTable->{'aliasing'};
	my $noIOpt				=$transcodeTable->{'noIOpt'};
	my $highPrecisionClock	=$transcodeTable->{'highPrecisionClock'};
	my $bandwidth			=$transcodeTable->{'bandwidth'};
	my $smallRollOff		=$transcodeTable->{'smallRollOff'};
	my $headroom			=$transcodeTable->{'headroom'};
	my $gain				=$transcodeTable->{'gain'};
	my $loudnessGain		=$transcodeTable->{'loudnessGain'};
	my $loudnessRef			=$transcodeTable->{'loudnessRef'};
	my $remixLeft			=$transcodeTable->{'remixLeft'};
	my $remixRight			=$transcodeTable->{'remixRight'};
	my $flipChannels		=$transcodeTable->{'flipChannels'};
		
	my $extra_before_rate	=$transcodeTable->{'extra_before_rate'};
	my $extra_after_rate	=$transcodeTable->{'extra_after_rate'};
	
	#my $outChannels		=$transcodeTable->{'outChannels'};
	#my $outEncoding		=$transcodeTable->{'outEncoding'};
	#my $outByteOrder		=$transcodeTable->{'outByteOrder'};
	#my $dither				=$transcodeTable->{'dither'};
	
	my $ditherType			=$transcodeTable->{'ditherType'};
	my $ditherPrecision		=$transcodeTable->{'ditherPrecision'};

	my $sdmFilterType		=$transcodeTable->{'sdmFilterType'};

	my $dsdLowpass1Value	=22;
	my $dsdLowpass1Order	=2;
	my $dsdLowpass1Active	=1;

	my $dsdLowpass2Value	=33;
	my $dsdLowpass2Order	=2;
	my $dsdLowpass2Active	=0;

	my $dsdLowpass3Value	=44;
	my $dsdLowpass3Order	=2;
	my $dsdLowpass3Active	=0;
	
	my $dsdLowpass4Value	=48;
	my $dsdLowpass4Order	=2;
	my $dsdLowpass4Active	=0;

	#my $dsdLowpass4Value	=$transcodeTable->('dsdLowpass4Value');
	#my $dsdLowpass4Order	=$transcodeTable->('dsdLowpass4Order');
	#my $dsdLowpass4Active	=$transcodeTable->('dsdLowpass4Active');
	
	#my $dsdLowpass1Value	=$transcodeTable->('dsdLowpass1Value');
	#my $dsdLowpass1Order	=$transcodeTable->('dsdLowpass1Order');
	#my $dsdLowpass1Active	=$transcodeTable->('dsdLowpass1Active');

	#my $dsdLowpass2Value	=$transcodeTable->('dsdLowpass2Value');
	#my $dsdLowpass2Order	=$transcodeTable->('dsdLowpass2Order');
	#my $dsdLowpass2Active	=$transcodeTable->('dsdLowpass2Active');

	#my $dsdLowpass3Value	=$transcodeTable->('dsdLowpass3Value');
	#my $dsdLowpass3Order	=$transcodeTable->('dsdLowpass3Order');
	#my $dsdLowpass3Active	=$transcodeTable->('dsdLowpass3Active');

	#my $dsdLowpass4Value	=$transcodeTable->('dsdLowpass4Value');
	#my $dsdLowpass4Order	=$transcodeTable->('dsdLowpass4Order');
	#my $dsdLowpass4Active	=$transcodeTable->('dsdLowpass4Active');

	my $file				=$transcodeTable->{'options'}->{'file'};
	
	my $inCodec				=$transcodeTable->{'transitCodec'};
	my $outCodec			=Plugins::C3PO::Transcoder::getOutputCodec($transcodeTable);
	
	my $exe					=$transcodeTable->{'pathToSox'};
	my $command				=$transcodeTable->{'command'};

	Plugins::C3PO::Logger::verboseMessage('Start sox resample');

	my $outFormatSpec="";

	# -r 19200 -b 24 -C 8

	if ($outSamplerate){$outFormatSpec= $outFormatSpec.' -r '.$outSamplerate};
	
	if ($outBitDepth){$outFormatSpec= $outFormatSpec.' -b '.$outBitDepth*8};# short form deprecation in sox since 14.4.2
	
	if ($outCompression){$outFormatSpec= $outFormatSpec.' -C '.$outCompression};
	
	#if ($outChannels){$outFormatSpec= $outFormatSpec.' -c '.$outChannels};
	#if ($outEncoding){$outFormatSpec= $outFormatSpec.' -'.$outEncoding};
	#if ($outByteOrder){$outFormatSpec= $outFormatSpec.' -'.$outByteOrder};
	
	# LOWPASS filter to be applied when input is DSD 
	
	my $lowpass="";
	
	if ($dsdLowpass1Active){
		$lowpass = $lowpass.' -'.$dsdLowpass1Order.' '.$dsdLowpass1Value*1000;
	}
	if ($dsdLowpass2Active){
		$lowpass = $lowpass.' -'.$dsdLowpass2Order.' '.$dsdLowpass2Value*1000;
	}
	if ($dsdLowpass3Active){
		$lowpass = $lowpass.' -'.$dsdLowpass3Order.' '.$dsdLowpass3Value*1000;
	}
	if ($dsdLowpass4Active){
		$lowpass = $lowpass.' -'.$dsdLowpass4Order.' '.$dsdLowpass4Value*1000;
	}
	
	my 	$rateString= ' rate';
	
	$aliasing					= $aliasing ? "a" : undef;
	$noIOpt						= $noIOpt ? "n" : undef;
	$highPrecisionClock			= $highPrecisionClock ? "t" : undef;
	$smallRollOff				= $smallRollOff? "f" : undef;
	
	$bandwidth					=($bandwidth/10)."";
	
	# rate -v -L -n -t -a -b 90.7 -f 192000
	if ($quality){$rateString= $rateString.' -'.$quality};
	if ($phase){$rateString= $rateString.' -'.$phase};
	if ($noIOpt){$rateString= $rateString.' -'.$noIOpt};
	if ($highPrecisionClock){$rateString= $rateString.' -'.$highPrecisionClock};
	if ($aliasing){$rateString= $rateString.' -'.$aliasing};
	if ($bandwidth){$rateString= $rateString.' -b '.$bandwidth};
	if ($smallRollOff){$rateString= $rateString.' -'.$smallRollOff};
	if ($outSamplerate){$rateString= $rateString.' '.$outSamplerate};
	
	# effects gain -h gain -3 loudness -6 65 remix -m 1v0.94 2
	my $effects="";
	
	if ($headroom){$effects= $effects.' gain -h'};
	
	if ($gain){$effects= $effects.' gain -'.$gain};
	
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

	# DITHER, yo be applied only when OUTPUT IS PCM.

	#if (!defined $dither){$effects= $effects.' -D'};
	my $dither='';
	
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
	
	# SDM to by applied only to DSD output
	
	my $sdm='';;
	
	if (!$sdmFilterType){
		
		$sdm = $sdm.' sdm' #auto
		
	} elsif ($sdmFilterType == -1 ){
		
		$sdm = $sdm.''; #no sdm 
		
	} else {
	
		$sdm = $sdm.' sdm -f '.$sdmFilterType;
	}
	############################################################################
	$inCodec=_translateCodec($inCodec);
	
	if ($isTranscodingRequired &&
		$useSoxToEncodeWhenResampling){
		
		$outCodec=_translateCodec($outCodec);
		
	} else{
	
		$outCodec=$inCodec;
	}
	
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
	
	if (($inCodec eq "dsf" || $inCodec eq "dff") && 
	    $effects && !($lowpass eq "")){

			$effects= $lowpass.' '.$effects;
		
	}

	if ($extra_before_rate && !($extra_before_rate eq "")){
	
		$effects = $effects.' '.$extra_before_rate;
	}
	
	$effects=$effects.$rateString;
	
	if ($extra_after_rate && !($extra_after_rate eq "")){
	
		$effects = $effects." ".$extra_after_rate;
	}
	
	if (!($outCodec eq "dsf" || $outCodec eq "dff") &&
		($dither && !($dither eq ""))){
	
		$effects= $effects.' '.$dither;
	
	} elsif (($outCodec eq "dsf" || $outCodec eq "dff") &&
			 ($sdm && !($sdm eq ""))){
	
		$effects= $effects.' '.$sdm;
	}
	
	############################################################################
	
	$commandString = $commandString.qq($outCodec$outFormatSpec --buffer=$buffer - $effects);
	
	return $commandString;

}

sub transcode{
	my $transcodeTable = shift;
	
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
	$commandString = $commandString."-";
	return $commandString;
}
sub _translateCodec{
	my $codec= shift;
	
	if ($codec eq 'flc') {return 'flac';}
	if ($codec eq 'flac') {return 'flc';}
	return $codec;
}
1;
