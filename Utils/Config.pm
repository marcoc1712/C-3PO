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

package Utils::Config;

use strict;

use Config;
#use Data::Dump;
#use File::Spec::Functions qw(:ALL);

sub expandINC_STD{
	
	#we could not use this method in WIN becouse it returns some warnings that mess up the result.
	my $libPath = shift;
	
	require Slim::bootstrap;
	require Slim::Utils::OSDetect;
	
	Slim::bootstrap->loadModules($libPath);
	
	return @INC;
	
}

sub expandINC{
	my $libPath = shift;

	my $arch= getArchName();
	my $perlmajorversion = getPerlMajorVersion();
	   
	#Data::Dump::dump ($arch, $perlmajorversion, $Config{'version'});
	
	my @newINC = (
	
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $arch)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $arch, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config{'version'}, $Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config{'version'}, $Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib')), 
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN')),
		File::Spec->canonpath( $libPath ),
		
	);
	
	#Data::Dump::dump (@newINC);
	
	return @newINC;
}

sub getPerlMajorVersion{

	my $perlmajorversion = $Config{'version'};
	   $perlmajorversion =~ s/\.\d+$//;
	
	return $perlmajorversion;
}
sub getArchName{

	my $arch = $Config::Config{'archname'};
	
	#Data::Dump::dump($arch);
	
	# NB: The user may be on a platform who's perl reports a
	# different x86 version than we've supplied - but it may work
	# anyways.
	
	   $arch =~ s/^i[3456]86-/i386-/;
	   $arch =~ s/gnu-//;
	
	# Check for use64bitint Perls
	my $is64bitint = $arch =~ /64int/;
	
	# Some ARM platforms use different arch strings, just assume any arm*linux system
	# can run our binaries, this will fail for some people running invalid versions of Perl
	# but that's OK, they'd be broken anyway.
	if ( $arch =~ /^arm.*linux/ ) {
		$arch = $arch =~ /gnueabihf/ 
			? 'arm-linux-gnueabihf-thread-multi' 
			: 'arm-linux-gnueabi-thread-multi';
		$arch .= '-64int' if $is64bitint;
	}
	
	# Same thing with PPC
	if ( $arch =~ /^(?:ppc|powerpc).*linux/ ) {
		$arch = 'powerpc-linux-thread-multi';
		$arch .= '-64int' if $is64bitint;
	}
	
	return $arch;
}
1;