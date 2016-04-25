#!/usr/bin/perl
#
# @File Wav.pm
# @Author Marco Curti <marcoc1712@gmail.com>
# @Created 6-nov-2015 15.37.11

package Test::Aif;

require Test;

#######################################################################
# Test cases Output codec == aif.
#######################################################################

###################################################
# FFMPEG_resampling_aif
#
# incodec=wav;
#

sub test_wav_noSplit_FFMPEG_resampling_aif{
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav "F:\Classica\aaa - Resampling\wav_16_44100.wav" -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_wav_split_noStart_end_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -t 691.266666666667  -i "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" -f wav - | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_wav_split_start_end_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::FFMPEG_resampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 1486.02666666667 -t 218.04  -i "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" -f wav - | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_wav_split_start_noEnd_FFMPEG_resampling_aif{

	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 3716.42666666667 -t 226.50633333333  -i "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" -f wav - | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
# incodec=aif;
#
sub test_aif_noSplit_FFMPEG_resampling_aif {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t aif "F:\Classica\aaa - Resampling\aiff_16_44100.aiff" -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_aif_split_noStart_end_FFMPEG_resampling_aif{

	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -t 304.933333333333  -i "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" -f wav - | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_aif_split_start_end_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 1014.09333333333 -t 214.17333333334  -i "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" -f wav - | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_aif_split_start_noEnd_FFMPEG_resampling_aif {
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 4084.42666666667 -t 57.1733333333304  -i "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" -f wav - | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
# incodec=flc;
#
sub test_flc_noSplit_FFMPEG_resampling_aif {
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::FFMPEG_resampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac "F:\Classica\aaa - Resampling\flac_16_44100.flac" -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_flc_split_noStart_end_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --until=11:52.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_flc_split_start_end_FFMPEG_resampling_aif{

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=34:03.00 --until=41:50.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_flc_split_start_noEnd_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::FFMPEG_resampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=72:50.00 --until=78:53.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}

###############################################################################
# FFMPEG_noResampling_aif
#
# incodec=wav;
#

sub test_wav_noSplit_FFMPEG_noResampling_aif {
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -i "F:\Classica\aaa - Resampling\wav_16_44100.wav" -f aiff -';
}
sub test_wav_split_noStart_end_FFMPEG_noResampling_aif{
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -t 691.266666666667  -i "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" -f aiff -';
}
sub test_wav_split_start_end_FFMPEG_noResampling_aif{
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::FFMPEG_noResampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 1486.02666666667 -t 218.04  -i "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" -f aiff -';
}
sub test_wav_split_start_noEnd_FFMPEG_noResampling_aif {

	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 3716.42666666667 -t 226.50633333333  -i "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" -f aiff -';
}
# incodec=aif;
#
sub test_aif_noSplit_FFMPEG_noResampling_aif {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return '';
}
sub test_aif_split_noStart_end_FFMPEG_noResampling_aif{

	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -t 304.933333333333  -i "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" -f aiff -';
}
sub test_aif_split_start_end_FFMPEG_noResampling_aif{
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 1014.09333333333 -t 214.17333333334  -i "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" -f aiff -';
}
sub test_aif_split_start_noEnd_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -ss 4084.42666666667 -t 57.1733333333304  -i "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" -f aiff -';
}
# incodec=flc;
#
sub test_flc_noSplit_FFMPEG_noResampling_aif{
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::FFMPEG_noResampling_aif();
    
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac "F:\Classica\aaa - Resampling\flac_16_44100.flac" -t aif -';
}
sub test_flc_split_noStart_end_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --until=11:52.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -i - -f aiff -';
}
sub test_flc_split_start_end_FFMPEG_noResampling_aif {

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=34:03.00 --until=41:50.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -i - -f aiff -';
}
sub test_flc_split_start_noEnd_FFMPEG_noResampling_aif{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::FFMPEG_noResampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=72:50.00 --until=78:53.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\ffmpeg.exe" -vn -v 0 -i - -f aiff -';
}

###############################################################################
# NO_FFMPEG_resampling_aif
#
# incodec=wav;
#

sub test_wav_noSplit_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav "F:\Classica\aaa - Resampling\wav_16_44100.wav" -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}

sub test_wav_split_noStart_end_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --until=11:31.26 -- "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}

sub test_wav_split_start_end_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=24:46.02 --until=28:24.06 -- "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_wav_split_start_noEnd_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=61:56.42 --until=65:42.93 -- "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
# incodec=aif;
#
sub test_aif_noSplit_NO_FFMPEG_resampling_aif {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t aif "F:\Classica\aaa - Resampling\aiff_16_44100.aiff" -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_aif_split_noStart_end_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --until=5:04.93 -- "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_aif_split_start_end_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=16:54.09 --until=20:28.26 -- "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_aif_split_start_noEnd_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=68:04.42 --until=69:01.60 -- "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
# incodec=flc;
#
sub test_flc_noSplit_NO_FFMPEG_resampling_aif {
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::NO_FFMPEG_resampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac "F:\Classica\aaa - Resampling\flac_16_44100.flac" -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_flc_split_noStart_end_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --until=11:52.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_flc_split_start_end_NO_FFMPEG_resampling_aif{

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::NO_FFMPEG_resampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=34:03.00 --until=41:50.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}
sub test_flc_split_start_noEnd_NO_FFMPEG_resampling_aif{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::NO_FFMPEG_resampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=72:50.00 --until=78:53.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -r 88200 -b 16 --buffer=8192 - gain -3 rate -v -M -a -b 90.7 88200';
}

###############################################################################
# NO_FFMPEG_noResampling_aif
#
# incodec=wav;
#
sub test_wav_noSplit_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav "F:\Classica\aaa - Resampling\wav_16_44100.wav" -t aif -';
}
sub test_wav_split_noStart_end_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --until=11:31.26 -- "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -';
}
sub test_wav_split_start_end_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=24:46.02 --until=28:24.06 -- "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -';
}
sub test_wav_split_start_noEnd_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=61:56.42 --until=65:42.93 -- "F:\Classica\Albinoni, Tomaso\Albinoni Adagios - Anthony Camden, Julia Girdwood (1993 Naxos)\Albinoni - Adagio.wav" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -';
}
# incodec=aif;
#
sub test_aif_noSplit_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return '';
}
sub test_aif_split_noStart_end_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --until=5:04.93 -- "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -';
}
sub test_aif_split_start_end_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=16:54.09 --until=20:28.26 -- "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -';
}
sub test_aif_split_start_noEnd_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -cs --totally-silent --compression-level-0 --skip=68:04.42 --until=69:01.60 -- "F:\Classica\aaa - Resampling\Pergolesi Stabat Mater; Scarlatti 3 concerti grossi - Berganza, Freni, Gracis (1989 Archiv)\cd.aiff" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac - -t aif -';
}	
# incodec=flc;
#
sub test_noSplit_flac_NO_FFMPEG_noResampling_aif{
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
    
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t flac "F:\Classica\aaa - Resampling\flac_16_44100.flac" -t aif -';
}
sub test_flc_split_noStart_end_NO_FFMPEG_noResampling_aif {
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --until=11:52.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -';
}
sub test_flc_split_start_end_NO_FFMPEG_noResampling_aif {

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();
	
	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=34:03.00 --until=41:50.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -';
}
sub test_flc_split_start_noEnd_NO_FFMPEG_noResampling_aif{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::NO_FFMPEG_noResampling_aif();

	return 'G":\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\flac.exe" -dcs --totally-silent --skip=72:50.00 --until=78:53.00 -- "F:\Classica\aaa - Resampling\Adagio Karajan (Les Rendez-Vous de DG edition)\Adagio.flac" | "G:\Sviluppo\slimserver\Bin\MSWin32-x86-multi-thread\sox.exe" -q -t wav - -t aif -';
}
1;