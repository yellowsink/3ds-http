#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <3ds.h>

#include "http.h"

const char* url = "http://cdn.hyrule.pics/5ed156b41.mp4";
const char* target = "../3DSHTTP_TARGET";

int main(int argc, char* argv[])
{
	gfxInitDefault();
	consoleInit(GFX_TOP, NULL);
	httpcInit(0);

	printf("Hello, world!\nDownloading %s\n", url);

	FILE* f = fopen(target, "wb");

	u32 size;
	u32 result = http_download(url, f, &size);

	fclose(f);

	switch (result)
	{
		case 0:
			printf("Success! Written to %s\n", target);
			break;

		case TLS1_1_ERROR:
			printf("Error: Server does not support TLSv1.1, which the 3DS requires. Try again with HTTP.\n");
			break;

		default:
			printf("Error %lx\n", result);
			break;
	}

	// Main loop
	while (aptMainLoop())
	{
		gspWaitForVBlank();
		gfxSwapBuffers();
		hidScanInput();

		// Your code goes here
		u32 kDown = hidKeysDown();
		if (kDown & KEY_START)
			break; // break in order to return to hbmenu
	}

	httpcExit();
	gfxExit();
	return 0;
}
