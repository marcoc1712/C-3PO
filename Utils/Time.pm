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

package Utils::Time;

use Time::HiRes qw(time usleep);
use POSIX qw(strftime);

use strict;

sub getTimeString {
    my $time = shift || time;
    
    return POSIX::strftime('%Y%m%d%H%M%S', localtime($time));
    
}
sub getNiceTimeString {
    my $time = shift || time;
    
    return POSIX::strftime('%Y/%m/%d %H:%M:%S', localtime($time));
    
}
sub getTimestamp{
    
    usleep(1000);
    
    return time;
}
1;