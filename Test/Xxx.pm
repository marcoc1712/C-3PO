#!/usr/bin/perl
#
# @File Wav.pm
# @Author Marco Curti <marcoc1712@gmail.com>
# @Created 6-nov-2015 15.37.11
#
# TEMPLATE to be used if and when a new Output codec is added.
# Rename package and replace xxx with the new codec name.
# Remember to add the module to the c3poTest namespaces.
#
package Test::Xxx;

require Test;

#######################################################################
# Test cases Output codec == xxx.
#######################################################################

###################################################
# FFMPEG_resampling_xxx
#
# incodec=wav;
#

sub test_wav_noSplit_FFMPEG_resampling_xxx{
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
sub test_wav_split_noStart_end_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
sub test_wav_split_start_end_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::FFMPEG_resampling_xxx();

	return '';
}
sub test_wav_split_start_noEnd_FFMPEG_resampling_xxx{

	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
# incodec=aif;
#
sub test_aif_noSplit_FFMPEG_resampling_xxx {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
sub test_aif_split_noStart_end_FFMPEG_resampling_xxx{

	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
sub test_aif_split_start_end_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
sub test_aif_split_start_noEnd_FFMPEG_resampling_xxx {
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
# incodec=flc;
#
sub test_flc_noSplit_FFMPEG_resampling_xxx {
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::FFMPEG_resampling_xxx();

	return '';
}
sub test_flc_split_noStart_end_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
sub test_flc_split_start_end_FFMPEG_resampling_xxx{

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::FFMPEG_resampling_xxx();
	
	return '';
}
sub test_flc_split_start_noEnd_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::FFMPEG_resampling_xxx();

	return '';
}

###############################################################################
# FFMPEG_noResampling_xxx
#
# incodec=wav;
#

sub test_wav_noSplit_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_wav_split_noStart_end_FFMPEG_noResampling_xxx{
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_wav_split_start_end_FFMPEG_noResampling_xxx{
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::FFMPEG_noResampling_xxx();

	return '';
}
sub test_wav_split_start_noEnd_FFMPEG_noResampling_xxx {

	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
# incodec=aif;
#
sub test_aif_noSplit_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_aif_split_noStart_end_FFMPEG_noResampling_xxx{

	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_aif_split_start_end_FFMPEG_noResampling_xxx{
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_aif_split_start_noEnd_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
# incodec=flc;
#
sub test_flc_noSplit_FFMPEG_noResampling_xxx{
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::FFMPEG_noResampling_xxx();
    
	return '';
}
sub test_flc_split_noStart_end_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_flc_split_start_end_FFMPEG_noResampling_xxx {

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_flc_split_start_noEnd_FFMPEG_noResampling_xxx{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::FFMPEG_noResampling_xxx();

	return '';
}

###############################################################################
# NO_FFMPEG_resampling_xxx
#
# incodec=wav;
#

sub test_wav_noSplit_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}

sub test_wav_split_noStart_end_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}

sub test_wav_split_start_end_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
sub test_wav_split_start_noEnd_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
# incodec=aif;
#
sub test_aif_noSplit_NO_FFMPEG_resampling_xxx {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
sub test_aif_split_noStart_end_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
sub test_aif_split_start_end_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
sub test_aif_split_start_noEnd_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
# incodec=flc;
#
sub test_flc_noSplit_NO_FFMPEG_resampling_xxx {
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();

	return '';
}
sub test_flc_split_noStart_end_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
sub test_flc_split_start_end_NO_FFMPEG_resampling_xxx{

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();
	
	return '';
}
sub test_flc_split_start_noEnd_NO_FFMPEG_resampling_xxx{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::NO_FFMPEG_resampling_xxx();

	return '';
}

###############################################################################
# NO_FFMPEG_noResampling_xxx
#
# incodec=wav;
#
sub test_wav_noSplit_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::noSplit_wav();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_wav_split_noStart_end_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_wav_noStart_end();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_wav_split_start_end_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_wav_start_end();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_wav_split_start_noEnd_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_wav_start_noEnd();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
# incodec=aif;
#
sub test_aif_noSplit_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::noSplit_aif();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_aif_split_noStart_NO_FFMPEG_end_noResampling_xxx {
	
	Test::TestSettings::split_aif_noStart_end();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_aif_split_start_end_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_aif_start_end();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_aif_split_start_noEnd_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_aif_start_noEnd();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}	
# incodec=flc;
#
sub test_noSplit_flac_NO_FFMPEG_noResampling_xxx{
	
	Test::TestSettings::noSplit_flc();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
    
	return '';
}
sub test_flc_split_noStart_end_NO_FFMPEG_noResampling_xxx {
	
	Test::TestSettings::split_flc_noStart_end();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_flc_split_start_end_NO_FFMPEG_noResampling_xxx {

	Test::TestSettings::split_flc_start_end();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();
	
	return '';
}
sub test_flc_split_start_noEnd_NO_FFMPEG_noResampling_xxx{
	
	Test::TestSettings::split_flc_start_noEnd();
	Test::TestSettings::NO_FFMPEG_noResampling_xxx();

	return '';
}
1;