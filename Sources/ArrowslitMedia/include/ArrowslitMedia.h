#ifndef ARROWSLIT_MEDIA_H
#define ARROWSLIT_MEDIA_H

#include <stddef.h>

/// Entry point loaded by Perl. Writes JSON lines to stdout and reads commands from stdin.
void arrowslit_media_stream(void *interpreter, void *cv);

#endif
