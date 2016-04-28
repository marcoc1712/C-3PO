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
	
	#my $outChannels		=$transcodeTable->{'outChannels'};
	my $outBitDepth			=$transcodeTable->{'outBitDepth'};
	#my $outEncoding		=$transcodeTable->{'outEncoding'};
	#my $outByteOrder	=$transcodeTable->{'outByteOrder'};
	my $outCompression	=$transcodeTable->{'outCompression'};
	my $quality			=$transcodeTable->{'quality'};
	my $phase			=$transcodeTable->{'phase'};
	my $aliasing		=$transcodeTable->{'aliasing'};
	my $bandwidth		=$transcodeTable->{'bandwidth'};
	
	my $headroom		=$transcodeTable->{'headroom'};
	my $gain			=$transcodeTable->{'gain'};
	my $loudnessGain	=$transcodeTable->{'loudnessGain'};
	my $loudnessRef		=$transcodeTable->{'loudnessRef'};
	my $remixLeft		=$transcodeTable->{'remixLeft'};
	my $remixRight		=$transcodeTable->{'remixRight'};
	my $flipChannels	=$transcodeTable->{'flipChannels'};

	#my $dither			=$transcodeTable->{'dither'};
	my $ditherType		=$transcodeTable->{'ditherType'};
	my $ditherPrecision	=$transcodeTable->{'ditherPrecision'};
	
	my $extra_before_rate			=$transcodeTable->{'extra_before_rate'};
	my $extra_after_rate			=$transcodeTable->{'extra_after_rate'};
	
	my $file			=$transcodeTable->{'options'}->{'file'};
	
	my $inCodec			=$transcodeTable->{'transitCodec'};
	my $outCodec		=Plugins::C3PO::Transcoder::getOutputCodec($transcodeTable);
	
	my $exe				=$transcodeTable->{'pathToSox'};
	my $command			=$transcodeTable->{'command'};

	Plugins::C3PO::Logger::verboseMessage('Start sox resample');

	my $outFormatSpec="";

	# -r 19200 -b 24 -C 8

	if ($outSamplerate){$outFormatSpec= $outFormatSpec.' -r '.$outSamplerate};
	#if ($outChannels){$outFormatSpec= $outFormatSpec.' -c '.$outChannels};

	if ($outBitDepth){$outFormatSpec= $outFormatSpec.' -b '.$outBitDepth*8};# short form deprecation in sox since 14.4.2
	
	#if ($outEncoding){$outFormatSpec= $outFormatSpec.' -'.$outEncoding};
	#if ($outByteOrder){$outFormatSpec= $outFormatSpec.' -'.$outByteOrder};

	if ($outCompression){$outFormatSpec= $outFormatSpec.' -C '.$outCompression};
	
	my 	$rateString= ' rate';
	
	$aliasing		= $aliasing ? "a" : undef;
	$bandwidth		=($bandwidth/10)."";
	
	# rate -v -M -a -b 90.7 192000
	if ($quality){$rateString= $rateString.' -'.$quality};
	if ($phase){$rateString= $rateString.' -'.$phase};
	if ($aliasing){$rateString= $rateString.' -'.$aliasing};
	if ($bandwidth){$rateString= $rateString.' -b '.$bandwidth};
	if ($outSamplerate){$rateString= $rateString.' '.$outSamplerate};
	
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
	
	warn "left: ".$leftCh.' '.$leftVol.' right: '.$rightCh.' '.$rightVol."\n";

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

	if ($extra_before_rate && !($extra_before_rate eq "")){
	
		$effects = $effects." ".$extra_before_rate;
	}
	
	$effects=$effects.$rateString;
	
	if ($extra_after_rate && !($extra_after_rate eq "")){
	
		$effects = $effects." ".$extra_after_rate;
	}
	
	#if (!defined $dither){$effects= $effects.' -D'};

	if (! $ditherType || ($ditherType eq -1)) {
		$effects= ' -D '.$effects; # as last of the options, before the first effect (gain))
	} elsif ($ditherType eq 1 ){
		# $effects = $effects 
	}elsif ($ditherType eq 2 ){
		$effects= $effects.' dither';
	}elsif ($ditherType eq 3 ){
		$effects= $effects.' dither -S';
	}elsif ($ditherType eq 4 ){
		$effects= $effects.' dither -s';
	}elsif ($ditherType eq 5 ){
		$effects= $effects.' dither -f lipshitz';
	}elsif ($ditherType eq 6 ){
		$effects= $effects.' dither -f f-weighted';
	}elsif ($ditherType eq 7 ){
		$effects= $effects.' dither -f modified-e-weighted';
	}elsif ($ditherType eq 8 ){
		$effects= $effects.' dither -f improved-e-weighted';
	}elsif ($ditherType eq 9 ){
		$effects= $effects.' dither -f gesemann';
	}elsif ($ditherType eq 'A' ){
		$effects= $effects.' dither -f shibata';
	}elsif ($ditherType eq 'B' ){
		$effects= $effects.' dither -f low-shibata';
	}elsif ($ditherType eq 'C' ){
		$effects= $effects.' dither -f high-shibata';
	}

	if ($ditherType && $ditherPrecision && ($ditherPrecision > 0) && ($soxVersion > 140400)){
		$effects= $effects.' -p '.$ditherPrecision;
	}
	
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
