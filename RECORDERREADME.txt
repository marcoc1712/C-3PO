Allo stato ho verificato che in WIndows con SocketWrapper non è possibile usare direttamente C-3PO nella configurazione 
necessaria per gestire il resampling a frequenza sincrona.

In particolare, usando SOCHETWRAPPER non si è in grado di gestire situazioni in cui il processo lanci processi figli, 
con EXEC , SYSTEM o ''. NOn funziona nemmeno in C, in questo caso.

Funziona invece un processo 'semplice' che recepisca in input STDIN e fornisca in output STDOUT, a qualsiasi livello 
intermedio della pipe di comando o alla fine, ma NON in PERL, è necessario unsare C ed anche in questo caso con un 
piccolo inconveniente: La read è bloccante e fa abortire socketwrapper, cos' che l'ultimo 'chunk' di dati letto si perde,
ma almeno il processo porcede senza mandare in errore LMS.

IL turnaround è usare chunk di dati sufficientemente piccoli affinchè questo non costituisca un problema.

ATTENZIONE: può provocare che i file prodotti vengano considerati 'broken' da alcuni programmi, megli procedere alla conversione 
in WAV con foobar, così da risolvere.