#include <stdio.h>
#include <unistd.h>
#include <dlfcn.h>

__attribute__((constructor))
void debug_init() {
    fprintf(stderr, "🚨 C CONSTRUCTOR: App binary loaded\n");
    fflush(stderr);
}

// Add a C main function to see if we can reach it
int main_c_fallback(int argc, char* argv[]) {
    fprintf(stderr, "🚨 C MAIN: Reached C main function\n");
    fflush(stderr);
    
    // Try to find Swift main
    void *swift_main = dlsym(RTLD_DEFAULT, "main");
    if (swift_main) {
        fprintf(stderr, "🚨 C MAIN: Found Swift main symbol\n");
    } else {
        fprintf(stderr, "🚨 C MAIN: Swift main symbol not found: %s\n", dlerror());
    }
    
    fflush(stderr);
    return 0;
}