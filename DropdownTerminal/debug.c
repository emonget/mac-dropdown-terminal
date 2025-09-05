#include <stdio.h>
#include <unistd.h>
#include <dlfcn.h>
#include <CoreFoundation/CoreFoundation.h>

// Build-time version info (injected by build system)
#ifndef GIT_COMMIT
#define GIT_COMMIT "unknown"
#endif

__attribute__((constructor))
void debug_init() {
    fprintf(stderr, "🚨 C CONSTRUCTOR: App binary loaded\n");
    fflush(stderr);
    
    // Read version info from bundle
    CFBundleRef bundle = CFBundleGetMainBundle();
    if (bundle) {
        CFStringRef commit = CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("GitCommit"));
        if (commit) {
            char commitStr[64];
            CFStringGetCString(commit, commitStr, sizeof(commitStr), kCFStringEncodingUTF8);
            fprintf(stderr, "📦 BUNDLE INFO: Commit %.7s\n", commitStr);
        } else {
            fprintf(stderr, "📦 BUNDLE INFO: No GitCommit found\n");
        }
        
        CFStringRef version = CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("CFBundleShortVersionString"));
        if (version) {
            char versionStr[32];
            CFStringGetCString(version, versionStr, sizeof(versionStr), kCFStringEncodingUTF8);
            fprintf(stderr, "📦 BUNDLE INFO: Version %s\n", versionStr);
        }
    } else {
        fprintf(stderr, "📦 BUNDLE INFO: Could not get main bundle\n");
    }
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