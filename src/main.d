import core.stdc.stdio : printf, fopen, fclose;

import ys3ds.ctru._3ds.types : Result;
import ys3ds.ctru._3ds.thread : threadCreate, threadFree, threadJoin;

import ys3ds.ctru._3ds.gfx : gfxInitDefault, gfxScreen_t, gfxSwapBuffers, gfxFlushBuffers, gfxExit;
import ys3ds.ctru._3ds.console : consoleInit, consoleClear;
import ys3ds.ctru._3ds.services.apt : aptMainLoop;
import ys3ds.ctru._3ds.services.hid : hidScanInput, hidKeysDown, KEY_START;
import ys3ds.ctru._3ds.services.gspgpu : gspWaitForVBlank;
import ys3ds.ctru._3ds.services.httpc : httpcInit, httpcExit;
import ys3ds.ctru._3ds.svc : svcGetThreadPriority, CUR_THREAD_HANDLE, svcSleepThread;

import ys3ds.utility : toStringzManaged;

import http : http_download, TLS_1_1_ERROR;

import util : format_size;

import btl.string : String;
import btl.autoptr : UniquePtr;

@nogc nothrow:

enum immutable(char[]) url = "http://cdn.hyrule.pics/5ed156b41.mp4";
enum immutable(char[]) target = "../3DSHTTP_TARGET";

enum STACK_SIZE = 1 * 1024; // from devkitpro/3ds-examples / threads/thread-basic/source/main.c, why 4kb? idk! 1 page maybe?

struct DownloadThreadArgs
{
	String url;
	String savePath;
}

struct DownloadThreadResult
{
	Result res;
	uint bytesWritten;
}

struct DownloadProgress
{
	bool finishedDownloading;
	uint currentBytes;
	uint totalBytes; // 0 = unknown
	float dataRate; // bytes / sec
}

// safety: this should only be accessed by main() from program start until the download thread is created,
//         then only accessed by the download thread for its entire lifetime
//         then only accessed by main() from the dl thread exiting until either exit or a new thread spawn.
__gshared DownloadThreadResult dlthrRes;

// safety: fuck it we ball, just write and read it i'm sure it'll be fine
//         it is the main thread's responsibility to clear this before and after running the dl thread
__gshared DownloadProgress currentProgress;


extern(C) void downloadThreadMain(void* threadArgPtr)
{
	// this deref should copy the data to live locally on this thread
	auto threadArgs = *(cast(DownloadThreadArgs*) threadArgPtr);

	auto f = fopen(threadArgs.savePath.toStringzManaged.ptr, "wb");

	auto result = http_download(
		threadArgs.url,
		f,
		(uint sofar, uint fullsz, float datarate) {
			currentProgress = DownloadProgress(false, sofar, fullsz, datarate);
		}
	);

	dlthrRes = DownloadThreadResult(result[0], result[1]);
	currentProgress = DownloadProgress(true, 0, 0, 0);

	svcSleepThread(5_000_000_000);
}

extern(C) void main()
{
	gfxInitDefault();
	consoleInit(gfxScreen_t.GFX_TOP, null);
	httpcInit(0);

	printf("Downloading %s\n", url.ptr); // D string *literals* are actually null terminated

	// spawn thread
	int priority;
	auto res = svcGetThreadPriority(&priority, CUR_THREAD_HANDLE);
	if (res) assert(0);

	auto dltargs = UniquePtr!DownloadThreadArgs.make(String(url), String(target));

	// set download thread to have a higher priority for ?? reason (something stdio related?)
	auto dlThreadHandle = threadCreate(&downloadThreadMain, dltargs.ptr, STACK_SIZE, priority - 1, -2, true);

	// Downloading loop
	while (aptMainLoop())
	{
		hidScanInput();

		// copy the struct locally to make sure nothing changes unexpectedly
		auto _progress = currentProgress;
		if (_progress.finishedDownloading) break;

		if (!_progress.currentBytes) continue; // waiting for it to start!

		//consoleClear();
		printf("\x1b[1;1H");

		if (!_progress.totalBytes)
			printf(
				"%s | %s/s           \n",
				_progress.currentBytes.format_size.toStringzManaged.ptr,
				_progress.dataRate.format_size.toStringzManaged.ptr,
			);
		else
			printf(
				"%.1f%% | %s / %s | %s/s         \n",
				100. * (cast(float) _progress.currentBytes) / (cast(float) _progress.totalBytes),
				_progress.currentBytes.format_size.toStringzManaged.ptr,
				_progress.totalBytes.format_size.toStringzManaged.ptr,
				_progress.dataRate.format_size.toStringzManaged.ptr,
			);

		// commit the screen
		gfxFlushBuffers();
		gfxSwapBuffers();

		// vsync
		gspWaitForVBlank();

		/* uint kDown = hidKeysDown();
		if (kDown & KEY_START)
			break; // return to hbmenu */
	}

	printf("loop exited, getting globals\n");
	svcSleepThread(1_000_000_000);

	// download is done!
	auto result = dlthrRes;
	currentProgress = DownloadProgress.init;

	printf("got globals\n");
	svcSleepThread(1_000_000_000);

	switch (result.res)
	{
	case 0:
		printf("Success! %s written to %s\n", result.bytesWritten.format_size.toStringzManaged.ptr, target.ptr);
		break;

	case TLS_1_1_ERROR:
		printf("Error: server does not support TLSv1.1, which the 3DS requires. Try with http.\n");
		break;

	default:
		printf("Error: %lx\n", result.res);
		break;
	}

	httpcExit();
	gfxExit();
}
