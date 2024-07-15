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

enum immutable(char[]) url = "http://cdn.hyrule.pics/21d0fb730.png"; //"http://cdn.hyrule.pics/5ed156b41.mp4";
enum immutable(char[]) target = "../3DSHTTP_TARGET";

enum STACK_SIZE = 4 * 1024; // from devkitpro/3ds-examples / threads/thread-basic/source/main.c, why 4kb? idk! 1 page maybe?

struct DownloadThreadArgs
{
	const(char)[] url;
	const(char)[] savePath;
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

	// we pass char[]s to keep memory allocation thread-local
	auto url = String(threadArgs.url);
	auto savePath = String(threadArgs.savePath);

	auto f = fopen(savePath.toStringzManaged.ptr, "wb");

	httpcInit(0);

	auto result = http_download(
		url,
		f,
		(uint sofar, uint fullsz, float datarate) {
			currentProgress = DownloadProgress(false, sofar, fullsz, datarate);
		}
	);

	httpcExit();

	fclose(f);

	dlthrRes = DownloadThreadResult(result[0], result[1]);
	currentProgress = DownloadProgress(true, 0, 0, 0);
}

extern(C) void main()
{
	gfxInitDefault();
	consoleInit(gfxScreen_t.GFX_TOP, null);

	printf("Downloading %s\n", url.ptr); // D string *literals* are actually null terminated

	// spawn thread
	int priority;
	auto res = svcGetThreadPriority(&priority, CUR_THREAD_HANDLE);
	if (res) assert(0);

	auto dltargs = UniquePtr!DownloadThreadArgs.make(url, target);

	// set download thread to have a higher priority for ?? reason (something stdio related?)
	auto dlThreadHandle = threadCreate(&downloadThreadMain, dltargs.ptr, STACK_SIZE, priority - 1, -2, false);

	DownloadProgress last;

	while (aptMainLoop())
	{
		hidScanInput();

		// copy the struct locally to make sure nothing changes unexpectedly
		auto _progress = currentProgress;
		if (_progress.finishedDownloading) break;

		if (_progress != last)
		{
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
		}
		last = _progress;

		// commit the screen
		gfxFlushBuffers();
		gfxSwapBuffers();

		// vsync
		gspWaitForVBlank();
	}

	// download is done!
	threadJoin(dlThreadHandle, ulong.max);
	threadFree(dlThreadHandle);

	auto result = dlthrRes;
	currentProgress = DownloadProgress.init;

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

	printf("press start to exit\n");

	while (aptMainLoop())
	{
		hidScanInput();

		if (hidKeysDown() & KEY_START) break;

		gfxFlushBuffers();
		gfxSwapBuffers();
		gspWaitForVBlank();
	}

	gfxExit();
}
