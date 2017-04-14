#!/usr/bin/perl
# $Id$
#
# Handles server side file type conversion and resampling.
# Replace custom-convert.conf.
#
# To be used mainly with Squeezelite-R2 
# (https://github.com/marcoc1712/squeezelite/releases)
#
# Logitech Media Server Copyright 2001-2011 Logitech.
# This Plugin Copyright 2015 Marco Curti (marcoc1712 at gmail dot com)
#
# C3PO is inspired by the DSD Player Plugin by Kimmo Taskinen <www.daphile.com>
# and Adrian Smith (triode1@btinternet.com), but it  does not replace it, 
# DSD Play is still needed to play dsf and dff files.
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
################################################################################
package Plugins::C3PO::LMSSongHelper;

use strict;
use warnings;

use Data::Dump qw(dump pp);

use Slim::Player::Song;
use Slim::Utils::Log;
use Slim::Schema;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;
use Slim::Player::CapabilitiesHelper;


my $class;
my $plugin;
my $log;
my $prefs;

my %streamFormatMap = (
	wav => 'pcm',
	mp4 => 'aac',
);

sub new {
    $class  = shift;
	$plugin = shift;
    my $song   = shift;
	
    $prefs = $plugin->getServerPreferences();
    
    my $logger = $plugin->getLogger();
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'}};
   
	my $self = bless {
        _song => $song,
     
    }, $class;

    return $self;
}
sub getSong{
    my $self= shift;
    
    return $self->{_song};
}
################################################################################
#
sub getTrack{
    my $self = shift;
    my $LMSSong = $self->getSong();
    
    return $LMSSong->track();
}
sub getDuration{
    my $self = shift;
    
    my $track=$self->getTrack();

    my $virtual         = $track->virtual;
    my $secs            = $track->secs;
    
    my $channels        = $track->channels;
    my $samplerate      = $track->samplerate;
    my $samplesize      = $track->samplesize;
   
    my $vbr_scale       = $track->vbr_scale;
    my $bitrate         = $track->bitrate;
    my $audio_size      = $track->audio_size;
    my $audio_offset    = $track->audio_offset;
    
    if (!$channels || !$samplesize || !$samplerate){return undef}
    
    my $duration = ($audio_size - $audio_offset)*8 / ($channels * $samplesize * $samplerate);
    
    $log->warn("virtual     : ".($virtual ? 'Yes' :'No'));
    $log->warn("secs        : $secs");
    $log->warn("channels    : $channels");
    $log->warn("samplerate  : $samplerate");
    $log->warn("samplesize  : $samplesize");
    $log->warn("vbr_scale   : ".($vbr_scale ? $vbr_scale :''));
    $log->warn("bitrate     : $bitrate");
    $log->warn("audio_size  : $audio_size");
    $log->warn("audio_offset: $audio_offset");
    
    $log->warn("duration    : $duration");
   
   return $duration;
}
# copy of  Slim::Player::Song::open, returning the command.
sub getTranscoder {
	my ($self, $seekdata) = @_;
	
    my $LMSSong = $self->getSong();
    
    my $command;
    
	my $handler = $LMSSong->currentTrackHandler();
	my $client  = $LMSSong->master();
	my $track   = $LMSSong->currentTrack();
	assert($track);
	my $url     = $track->url;

	# Reset seekOffset - handlers will set this if necessary
	$LMSSong->startOffset(0);
	
	# Restart direct-stream
	$LMSSong->directstream(0);
    
	main::DEBUGLOG && $log->debug("**************************************************************************");
	main::DEBUGLOG && $log->debug($url);
	
	$LMSSong->seekdata($seekdata) if $seekdata;
	my $sock;
	my $format = Slim::Music::Info::contentType($track);

	if ($handler->can('formatOverride')) {
		$format = $handler->formatOverride($LMSSong);
	}
		
	main::DEBUGLOG && $log->debug("seek=", ($LMSSong->seekdata() ? 'true' : 'false'), ' time=', ($LMSSong->seekdata() ? $LMSSong->seekdata()->{'timeOffset'} : 0),
		 ' canSeek=', $LMSSong->canSeek());
		 
	my $transcoder;
	my $error;
	
	if (main::TRANSCODING) {
		my $wantTranscoderSeek = $LMSSong->seekdata() && $LMSSong->seekdata()->{'timeOffset'} && $LMSSong->canSeek() == 2;
		my @wantOptions;
		push (@wantOptions, 'T') if ($wantTranscoderSeek);
		
		my @streamFormats;
		push (@streamFormats, 'I') if (! $wantTranscoderSeek);
		
		push @streamFormats, ($handler->isRemote && !Slim::Music::Info::isVolatile($handler) ? 'R' : 'F');
		
		($transcoder, $error) = Slim::Player::TranscodingHelper::getConvertCommand2(
			$LMSSong,
			$format,
			\@streamFormats, [], \@wantOptions);
		
		if (! $transcoder) {
			logError("Couldn't create command line for $format playback for [$url]");
			return (undef, ($error || 'PROBLEM_CONVERT_FILE'), $url);
		
        } elsif (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Transcoder: streamMode=", $transcoder->{'streamMode'}, ", streamformat=", $transcoder->{'streamformat'});
		}
		
		if ($wantTranscoderSeek && (grep(/T/, @{$transcoder->{'usedCapabilities'}}))) {
			$transcoder->{'start'} = $LMSSong->startOffset($LMSSong->seekdata()->{'timeOffset'});
		}
	} else {
		require Slim::Player::CapabilitiesHelper;
		
		# Set the correct format for WAV/AAC playback
		if ( exists $streamFormatMap{$format} ) {
			$format = $streamFormatMap{$format};
		}
		
		# Is format supported by all players?
		if (!grep {$_ eq $format} Slim::Player::CapabilitiesHelper::supportedFormats($client)) {
			$error = 'PROBLEM_CONVERT_FILE';
		}
		# Is samplerate supported by all players?
		elsif (Slim::Player::CapabilitiesHelper::samplerateLimit($LMSSong)) {
			$error = 'UNSUPPORTED_SAMPLE_RATE';
		}

		if ($error) {
			logError("$error [$url]");
			return (undef, $error, $url);
		}
		
		$transcoder = {
			command => '-',
			streamformat => $format,
			streamMode => 'I',
			rateLimit => 0,
		};
	}
	
	# TODO work this out for each player in the sync-group
	my $directUrl;
	if ($transcoder->{'command'} eq '-' && ($directUrl = $client->canDirectStream($url, $LMSSong))) {
		main::INFOLOG && $log->info( "URL supports direct streaming [$url->$directUrl]" );
		$LMSSong->directstream(1);
		$LMSSong->streamUrl($directUrl);
        
        $transcoder->{'tokenized'}= $transcoder->{'command'};
        return $transcoder;
       
	
    } else {
		my $handlerWillTranscode = $transcoder->{'command'} ne '-'
			&& $handler->can('canHandleTranscode') && $handler->canHandleTranscode($LMSSong);

		if ($transcoder->{'streamMode'} eq 'I' || $handlerWillTranscode) {
			main::INFOLOG && $log->info("Opening stream (no direct streaming) using $handler [$url]");
		
			$sock = $handler->new({
				url        => $url, # it is just easier if we always include the URL here
				client     => $client,
				song       => $LMSSong,
				transcoder => $transcoder,
			});
		
			if (!$sock) {
				logWarning("stream failed to open [$url].");
				#$LMSSong->setStatus(STATUS_FAILED);
				#return (undef, $LMSSong->isRemote() ? 'PROBLEM_CONNECTING' : 'PROBLEM_OPENING', $url);
			}
					
			my $contentType = Slim::Music::Info::mimeToType($sock->contentType) || $sock->contentType;
		
			# if it's an audio stream, try to stream,
			# either directly, or via transcoding.
			if (Slim::Music::Info::isSong($track, $contentType)) {
	
				main::INFOLOG && $log->info("URL is a song (audio): $url, type=$contentType");
	
				if ($sock->opened() && !defined(Slim::Utils::Network::blocking($sock, 0))) {
					logError("Can't set nonblocking for url: [$url]");
					return (undef, 'PROBLEM_OPENING', $url);
				}
				
				if ($handlerWillTranscode) {
					$LMSSong->_transcoded(1);
					$LMSSong->_streambitrate($sock->getStreamBitrate($transcoder->{'rateLimit'}) || 0);
				}
				
				# If the protocol handler has the bitrate set use this
				if ($sock->can('bitrate') && $sock->bitrate) {
					$LMSSong->_bitrate($sock->bitrate);
				}
			}	
			# if it's one of our playlists, parse it...
			elsif (Slim::Music::Info::isList($track, $contentType)) {
	
				# handle the case that we've actually
				# got a playlist in the list, rather
				# than a stream.
	
				# parse out the list
				my @items = Slim::Formats::Playlists->parseList($url, $sock);
	
				# hack to preserve the title of a song redirected through a playlist
				if (scalar(@items) == 1 && $items[0] && defined($track->title)) {
					Slim::Music::Info::setTitle($items[0], $track->title);
				}
	
				# close the socket
				$sock->close();
				$sock = undef;
	
				Slim::Player::Source::explodeSong($client, \@items);
	
				my $new = $LMSSong->new ($LMSSong->owner(), $LMSSong->index());
				%$LMSSong = %$new;
				
				# try to open the first item in the list, if there is one.
				$LMSSong->getNextSong (
					sub {return $LMSSong->open();}, # success
					sub {return(undef, @_);}    # fail
				);
				
			} else {
				logWarning("Don't know how to handle content for [$url] type: $contentType");
	
				$sock->close();
				$sock = undef;

				#$LMSSong->setStatus(STATUS_FAILED);
				#return (undef, $LMSSong->isRemote() ? 'PROBLEM_CONNECTING' : 'PROBLEM_OPENING', $url);
			}		
		}	
       
		if (main::TRANSCODING) {
			if ($transcoder->{'command'} ne '-' && ! $handlerWillTranscode) {
				# Need to transcode
					
				my $quality = $prefs->client($client)->get('lameQuality');
				
				# use a pipeline on windows when remote as we need socketwrapper to ensure we get non blocking IO
				my $usepipe = (defined $sock || (main::ISWINDOWS && $handler->isRemote)) ? 1 : undef;
		
				$command = Slim::Player::TranscodingHelper::tokenizeConvertCommand2(
					$transcoder, $sock ? '-' : $track->path, $LMSSong->streamUrl(), $usepipe, $quality
				);
	
				if (!defined($command)) {
					logError("Couldn't create command line for $format playback for [$LMSSong->streamUrl()]");
					return (undef, 'PROBLEM_CONVERT_FILE', $url);
				}
                $transcoder->{'tokenized'}= $command;
				main::DEBUGLOG && $log->is_debug('Tokenized command: ', Slim::Utils::Unicode::utf8decode_locale($command));
			}
		} # ENDIF main::TRANSCODING
	}
    if ($sock){
        $sock->close();
		$sock = undef;
    }

	return $transcoder;
}
1;