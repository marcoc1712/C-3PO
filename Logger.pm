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

package Plugins::C3PO::Logger;

use strict;

#use File::Spec::Functions qw(:ALL);

sub getLogFile{
	my $logFolder=shift;
	my $filemane= shift || 'C-3PO.log';

	return File::Spec->catdir($logFolder, $filemane);
}

sub writeLog {
	my $msg = shift;
	Utils::Log::writeLog($main::logfile,$msg,$main::isDebug,$main::logLevel,'info');
}
sub verboseMessage{
	my $msg=shift;
	Utils::Log::verboseMessage($main::logfile,$msg,$main::isDebug,$main::logLevel);
}
sub debugMessage{
	my $msg=shift;
	Utils::Log::debugMessage($main::logfile,$msg,$main::isDebug,$main::logLevel);
}
sub infoMessage{
	my $msg=shift;
	Utils::Log::infoMessage($main::logfile,$msg,$main::isDebug,$main::logLevel);
}
sub warnMessage{
	my $msg=shift;
	Utils::Log::warnMessage($main::logfile,$msg,$main::isDebug,$main::logLevel);
}
sub errorMessage{
	my $msg=shift;
	Utils::Log::errorMessage($main::logfile,$msg,$main::isDebug,$main::logLevel);
}
sub dieMessage{
	my $msg=shift;
	Utils::Log::dieMessage($main::logfile,$msg,$main::isDebug,$main::logLevel);
}
sub guessFileFatal{
	my $filemane= shift || 'C-3PO.fatal';
	
	my $dir = Plugins::C3PO::OsHelper::getFatalDir();
	my $fatal=File::Spec->catfile($dir, $filemane);
	return $fatal;
}
1;