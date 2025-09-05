#include <stdio.h>
#include <unistd.h>

__attribute__((constructor))
void debug_init() {
    fprintf(stderr, "🚨 C CONSTRUCTOR: App binary loaded\n");
    fflush(stderr);
}