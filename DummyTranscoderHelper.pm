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

package Plugins::C3PO::DummyTranscoderHelper;

sub transcode{
	my $transcodeTable = shift;
	
	Plugins::C3PO::Logger::infoMessage('Start dummyTranscoder using sox');
	
	return Plugins::C3PO::SoxHelper::transcode($transcodeTable);
}
1;