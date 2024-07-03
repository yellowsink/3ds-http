
import binds.stdc : printf;

import binds.ctru : gfxInitDefault, consoleInit, gfxScreen_t, gspWaitForVBlank, gfxSwapBuffers, gfxExit;

extern (C)
{
	bool aptMainLoop();

	void hidScanInput();

	uint hidKeysDown();
}


extern(C) void main()
{
	gfxInitDefault();
	consoleInit(gfxScreen_t.GFX_TOP, null); // 0 is top screen

	printf("hi?");

	while (aptMainLoop())
	{
		gspWaitForVBlank();
		//gspWaitForEvent(2, true); // 2: vblank0
		gfxSwapBuffers();
		hidScanInput();

		uint kDown = hidKeysDown();
		if (kDown & 0b1000)
			break; // break in order to return to hbmenu
	}

	gfxExit();
}