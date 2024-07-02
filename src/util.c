#include <stdio.h>
#include <stdlib.h>
#include <3ds.h>

const char* KiB = "KiB";
const char* MiB = "MiB";

char* format_size_f(float bytesf)
{
    const char* specifier = "";

    if (bytesf > (1024*1024))
    {
        bytesf /= (1024*1024);
        specifier = MiB;
    }
    else if (bytesf > 1024)
    {
        bytesf /= 1024;
        specifier = KiB;
    }

    char* s = malloc(256);
    sprintf(s, "%.2f%s", bytesf, specifier);
    return s;
}

char* format_size(u32 bytes)
{
    return format_size_f(bytes);
}