// TODO: stdc binds in ys3ds
import binds.stdc : printf, fopen, fclose;

import ys3ds.ctru._3ds.gfx : gfxInitDefault, gfxScreen_t, gfxSwapBuffers, gfxExit;
import ys3ds.ctru._3ds.console : consoleInit;
import ys3ds.ctru._3ds.services.apt : aptMainLoop;
import ys3ds.ctru._3ds.services.hid : hidScanInput, hidKeysDown, KEY_START;
import ys3ds.ctru._3ds.services.gspgpu : gspWaitForVBlank;
import ys3ds.ctru._3ds.services.httpc : httpcInit, httpcExit;

import util : toStringz;
import http : http_download, TLS_1_1_ERROR;

immutable char[] url = "http://cdn.hyrule.pics/5ed156b41.mp4";
immutable char[] target = "../3DSHTTP_TARGET";

extern(C) void main()
{
	gfxInitDefault();
	consoleInit(gfxScreen_t.GFX_TOP, null);
	httpcInit(0);

	printf("Downloading %s\n", url.ptr); // D string *literals* are actually null terminated

	auto f = fopen(target.ptr, "wb");

	uint size;
	auto result = http_download(url, f, &size);

	switch (result)
	{
		case 0:
			printf("Success! Target written to %s\n", target.ptr);
			break;

		case TLS_1_1_ERROR:
			printf("Error: server does not support TLSv1.1, which the 3DS requires. Try with http.\n");
			break;

		default:
			printf("Error: %lx\n", result);
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
