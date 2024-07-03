// useful stdc bindings

extern(C):

// printf

pragma(printf)
int printf(scope const char* format, scope const ...);

pragma(printf)
int sprintf(scope const char* s, scope const char* format, scope const ...);

// memory allocation

void* malloc(uint size);

void* calloc(uint nmemb, uint size);

void* realloc(void* ptr, uint size);

void free(void* ptr);

// files
alias FILE = void;

FILE* fopen(scope const char* filename, scope const char* mode);

int fclose(FILE* stream);

uint fwrite(scope const char* ptr, uint size, uint nmemb, FILE* stream);