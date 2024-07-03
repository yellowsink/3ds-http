
extern (C)
{
	void gfxInitDefault();

	void* consoleInit(int screen, void* console);

	bool aptMainLoop();

	void gspWaitForEvent(int, bool);

	void gfxSwapBuffers();

	void hidScanInput();

	uint hidKeysDown();

	void gfxExit();

	pragma(printf)
	int printf(scope const char* format, scope const ...);
}


extern(C) void main()
{
	gfxInitDefault();
	consoleInit(0, null); // 0 is top screen

	printf("hi?");

	while (aptMainLoop())
	{
		//gspWaitForVBlank();
		gspWaitForEvent(2, true); // 2: vblank0
		gfxSwapBuffers();
		hidScanInput();

		uint kDown = hidKeysDown();
		if (kDown & 0b1000)
			break; // break in order to return to hbmenu
	}

	gfxExit();
}