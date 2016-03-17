# C-3PO
Squeezebox server plugin. Handles server side file type conversion and resampling. 
Replace custom-convert.conf.

Best used with Squeezelite-r2 (https://github.com/marcoc1712/squeezelite) as player,
in order to upsample and decode to PCM at server side, let you handle transcoding and upsampling
parameters via the server web interface instead of custom-convert.conf.

Perform different decoding and resampling operations based on the format of the incoming file
or stream (i.e. upsampling at the max syncronous sample rate allowed by the player).

PLEASE NOTE:

Starting form March, 15 2016 the mod that originate squeezelite-R2 is included in the squeezebox community official version of squeezelite, mantained by Ralph Irving. You could then use also that version, just remember to activate -W option.
