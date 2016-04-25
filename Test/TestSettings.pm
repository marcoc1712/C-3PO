#!/usr/bin/perl
#
# @File Setting.pm
# @Author Marco Curti <marcoc1712@gmail.com>
# @Created 6-nov-2015 15.31.31
#

package Test::TestSettings;

use strict;

###############################################################################
# Test settings subroutines
###############################################################################
sub test_cleanUp{

	$main::options->{file}=undef;
	$main::options->{inCodec}=undef
	$main::options->{outCodec}=undef
	$main::options->{startTime}=undef;
	$main::options->{endTime}=undef;
	$main::options->{startSec}=undef;
	$main::options->{endSec}=undef;
	$main::options->{durationSec}=undef;
	
	$main::options->{forcedSamplerate}=undef;
	
	$main::prefs->{resampleTo} = "S";
    $main::prefs->{resampleWhen} = "A",
    $main::prefs->{outCodec} = "wav",
	$main::prefs->{pathToFFmpeg} = "G:\\Sviluppo\\slimserver\\Plugins\\C3PO\\Bin\\MSWin32-x86-multi-thread\\ffmpeg.exe"
}
#######################################################################
# Input combinations (Incodec + stat/end expressed for FFMPEG or FLAC))
#######################################################################
sub inTypeCleanUp{

	$main::options->{file}=undef;
	$main::options->{inCodec}=undef
	$main::options->{outCodec}=undef
	$main::options->{startTime}=undef;
	$main::options->{endTime}=undef;
	$main::options->{startSec}=undef;
	$main::options->{endSec}=undef;
	$main::options->{durationSec}=undef;
}

sub wav{
	inTypeCleanUp();
	$main::options->{inCodec}='wav';
}

sub noSplit_wav {
	wav();
	$main::options->{file}="F:\\Classica\\aaa - Resampling\\wav_16_44100.wav";
}
sub split_wav{
	wav();
	$main::options->{file}="F:\\Classica\\Albinoni, Tomaso\\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\\Albinoni - Adagio.wav";
}
sub split_wav_noStart_end{
	
	split_wav();
	$main::options->{durationSec}=691.266666666667;
	
}
sub split_wav_start_end{
	
	split_wav();
	$main::options->{startSec}=1486.02666666667; #traccia 6
	$main::options->{durationSec}=218.04;

}
sub split_wav_start_noEnd {
	
	split_wav();
	$main::options->{startSec}=3716.42666666667;
	$main::options->{durationSec}=226.50633333333;

}
################################################################################

sub aif{
	inTypeCleanUp();
	$main::options->{inCodec}='aif';
}
sub noSplit_aif {
	
	aif();
	$main::options->{file}="F:\\Classica\\aaa - Resampling\\aiff_16_44100.aiff";
}
sub split_aif{

	aif();
	$main::options->{file}="F:\\Classica\\aaa - Resampling\\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\\cd.aiff";
}
sub split_aif_noStart_end{
	
	split_aif();
	$main::options->{durationSec}=304.933333333333;
}
sub split_aif_start_end{
	
	split_aif();
	$main::options->{startSec}=1014.09333333333; #traccia 6
	$main::options->{durationSec}=214.17333333334;

}
sub split_aif_start_noEnd {
	
	split_aif();
	$main::options->{startSec}=4084.42666666667;
	$main::options->{durationSec}=57.1733333333304;

}
################################################################################

sub flc{
	inTypeCleanUp();
	$main::options->{inCodec}='flc';
}
sub noSplit_flc {
	
	flc();
	$main::options->{file}="F:\\Classica\\aaa - Resampling\\flac_16_44100.flac";

}
sub split_flc{
	
	flc();
	$main::options->{file}="F:\\Classica\\aaa - Resampling\\Adagio Karajan (Les Rendez-Vous de DG edition)\\Adagio.flac";
}
sub split_flc_noStart_end{
	
	split_flc();
	$main::options->{startSec}=undef;
	$main::options->{durationSec}=712;
	
}
sub split_flc_start_end{
	
	split_flc();
	$main::options->{startSec}=2043;# traccia 6
	$main::options->{durationSec}=467;

}
sub split_flc_start_noEnd{
	
	split_flc();
	$main::options->{startSec}=4370;
	$main::options->{durationSec}=363;
	
}
################################################################################
sub alc{
	inTypeCleanUp();
	$main::options->{inCodec}='alc';
}
sub noSplit_alc {
	
	alc();
	$main::options->{file}="F:\\Classica\\aaa - Resampling\\alc_16_44100.m4a";

}
sub split_alc{
	
	alc();
	$main::options->{file}="F:\\Classica\\aaa - Resampling\\Alac image + cue\\Image.m4a";
}
sub split_alc_noStart_end{
	
	split_alc();
	$main::options->{startSec}=undef;
	$main::options->{durationSec}=122.026666666667;
	
}
sub split_alc_start_end{
	
	split_alc();
	$main::options->{startSec}=122.026666666667;# traccia 2
	$main::options->{durationSec}=713.818333333333;

}
sub split_alc_start_noEnd{
	
	split_alc();
	$main::options->{startSec}=122.026666666667;
	$main::options->{durationSec}=713.818333333333;
	
}

#######################################################################
# Atomic Settings
#######################################################################
sub outCodec_wav{
	$main::options->{outCodec}='wav';	
	$main::prefs->{outCodec} = "wav";
}
sub outCodec_aif{
	$main::options->{outCodec}='aif';	
	$main::prefs->{outCodec} = "aif";
}
sub outCodec_flc8{
	$main::options->{outCodec}='flc';	
	$main::prefs->{outCodec} = "flc8";# test also another compresion?
}

sub resampling{

	$main::prefs->{resampleTo} = "S";
    $main::prefs->{resampleWhen} = "A";
	$main::prefs->{$main::client}->{sampleRates}->{'88200'}='on';
	$main::prefs->{$main::client}->{sampleRates}->{'96000'}='on';
}
sub noResampling{
	
	$main::prefs->{resampleTo} = "S";
    $main::prefs->{resampleWhen} = "A";
	$main::prefs->{$main::client}->{sampleRates}->{'88200'}=undef;
	$main::prefs->{$main::client}->{sampleRates}->{'96000'}=undef;
}
sub FFMpegIsInstalled{
	
	$main::prefs->{pathToFFmpeg} = "G:\\Sviluppo\\slimserver\\Bin\\MSWin32-x86-multi-thread\\ffmpeg.exe";
	
}
sub FFMpegIsNotInstalled{
	
	$main::prefs->{pathToFFmpeg} = undef;
	
}
#######################################################################
# Test cases settings (to use with any input codec).
#######################################################################

# Outcodec == wav:

sub FFMPEG_resampling_wav{
	FFMpegIsInstalled();
	outCodec_wav();
	resampling();
}
sub FFMPEG_noResampling_wav{
	FFMpegIsInstalled();
	outCodec_wav();
	noResampling();
}
sub NO_FFMPEG_resampling_wav{
	FFMpegIsNotInstalled();
	outCodec_wav();
	resampling();
}
sub NO_FFMPEG_noResampling_wav{
	FFMpegIsNotInstalled();
	outCodec_wav();
	noResampling();
}
# Outcodec == aif:

sub FFMPEG_resampling_aif{
	FFMpegIsInstalled();
	outCodec_aif();
	resampling();
}
sub FFMPEG_noResampling_aif{
	FFMpegIsInstalled();
	outCodec_aif();
	noResampling();
}
sub NO_FFMPEG_resampling_aif{
	FFMpegIsNotInstalled();
	outCodec_aif();
	resampling();
}
sub NO_FFMPEG_noResampling_aif{
	FFMpegIsNotInstalled();
	outCodec_aif();
	noResampling();
}
# Outcodec == flc8:

sub FFMPEG_resampling_flc8{
	FFMpegIsInstalled();
	outCodec_flc8();
	resampling();
}
sub FFMPEG_noResampling_flc8{
	FFMpegIsInstalled();
	outCodec_flc8();
	noResampling();
}
sub NO_FFMPEG_resampling_flc8{
	FFMpegIsNotInstalled();
	outCodec_flc8();
	resampling();
}
sub NO_FFMPEG_noResampling_flc8{
	FFMpegIsNotInstalled();
	outCodec_flc8();
	noResampling();
}

1;