import core.stdc.stdio : printf, fopen, fclose;

import ys3ds.ctru._3ds.gfx : gfxInitDefault, gfxScreen_t, gfxSwapBuffers, gfxExit;
import ys3ds.ctru._3ds.console : consoleInit;
import ys3ds.ctru._3ds.services.apt : aptMainLoop;
import ys3ds.ctru._3ds.services.hid : hidScanInput, hidKeysDown, KEY_START;
import ys3ds.ctru._3ds.services.gspgpu : gspWaitForVBlank;
import ys3ds.ctru._3ds.services.httpc : httpcInit, httpcExit;

import http : http_download, TLS_1_1_ERROR;

import btl.string : String;

enum immutable(char[]) url = "http://cdn.hyrule.pics/5ed156b41.mp4";
enum immutable(char[]) target = "../3DSHTTP_TARGET";

extern(C) void main()
{
	gfxInitDefault();
	consoleInit(gfxScreen_t.GFX_TOP, null);
	httpcInit(0);

	printf("Downloading %s\n", url.ptr); // D string *literals* are actually null terminated

	auto f = fopen(target.ptr, "wb");

	auto dlres = http_download(String(url), f);
	auto status = dlres[0];
	auto size = dlres[1];

	switch (status)
	{
		case 0:
			printf("Success! Target written to %s\n", target.ptr);
			break;

		case TLS_1_1_ERROR:
			printf("Error: server does not support TLSv1.1, which the 3DS requires. Try with http.\n");
			break;

		default:
			printf("Error: %lx\n", status);
			break;
	}

	// Main loop
	while (aptMainLoop())
	{
		gspWaitForVBlank();
		gfxSwapBuffers();
		hidScanInput();

		uint kDown = hidKeysDown();
		if (kDown & KEY_START)
			break; // return to hbmenu
	}

	httpcExit();
	gfxExit();
}
