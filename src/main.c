#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <3ds.h>

#define TLS1_1_ERROR 0xd8a0a03c

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

// starts a request, and follows all redirects
Result http_start_req(httpcContext* ctx, const char* url, u32* res_code)
{
	Result ret = 0;
	char* redir_url_buf = NULL;

	for (;;)
	{
		ret = httpcOpenContext(ctx, HTTPC_METHOD_GET, url, 1);
		//printf("[http_start_req] opened %lx\n", ret);

		// disable cert verification, as the 3ds is fuckin old lmao
		ret |= httpcSetSSLOpt(ctx, SSLCOPT_DisableVerify);
		//printf("[http_start_req] disabled certs %lx\n", ret);

		// purposefully don't enable keep-alive, we don't need it
		ret |= httpcSetKeepAlive(ctx, HTTPC_KEEPALIVE_DISABLED);
		//printf("[http_start_req] disabled keepalive %lx\n", ret);

		// set a UA
		ret |= httpcAddRequestHeaderField(ctx, "User-Agent", "3ds-http/1.0.0");
		//printf("[http_start_req] set UA %lx\n", ret);

		// request!
		ret |= httpcBeginRequest(ctx);
		//printf("[http_start_req] sent %lx\n", ret);
		if (ret)
		{
			httpcCloseContext(ctx); // unhandled ret
			if (redir_url_buf)
				free(redir_url_buf);

			return ret;
		}

		ret |= httpcGetResponseStatusCode(ctx, res_code);
		//printf("[http_start_req] res status %li %lx\n", *res_code, ret);
		if (ret)
		{
			httpcCloseContext(ctx); // unhandled ret
			if (redir_url_buf)
				free(redir_url_buf);

			return ret;
		}

		// handle redirects
		if ((*res_code >= 301 && *res_code <= 303) || (*res_code >= 307 && *res_code <= 308))
		{
			// expect the redirect url to fit in 4k chars
			if (!redir_url_buf)
				redir_url_buf = malloc(4096);

			if (!redir_url_buf)
			{
				httpcCloseContext(ctx);
				return -1;
			}

			ret |= httpcGetResponseHeader(ctx, "Location", redir_url_buf, 4096);

			printf("[http_start_req] redirect from\n%s\nto\n%s\n", url, redir_url_buf);

			url = redir_url_buf;

			// we'll start from scratch with a new ctx
			httpcCloseContext(ctx);
		}

		// we didn't redirect -> break out of the loop!
		else break;
	}

	free(redir_url_buf);
	return ret;
}

Result http_download(const char* url, u8** buffero, u32* sizeo)
{
	Result ret = 0;   // basically errno for the httpc functions
	httpcContext ctx; // httpc context
	u32 res_code = 0; // http resp status code

	ret |= http_start_req(&ctx, url, &res_code);
	if (ret)
	{
		httpcCloseContext(&ctx);
		return ret;
	}

	if (res_code != 200)
	{
		httpcCloseContext(&ctx);
		printf("response status was %li, not 200 OK\n", res_code);
		return -2;
	}

	// content-length if exists, 0 else
	u32 content_len = 0;
	char* cl_fmt;

	ret |= httpcGetDownloadSizeState(&ctx, NULL, &content_len);
	if (ret)
	{
		httpcCloseContext(&ctx);
		return ret;
	}

	if (content_len)
		cl_fmt = format_size(content_len);
	else
		cl_fmt = "?";

	printf("total download size: %li (%s)\n", content_len, cl_fmt);

	u8* buf = NULL, *lastbuf = NULL; // buffer we read into, and the previous one in case realloc fails and we gotta free it

	// init first buffer - one page
	buf = malloc(4096);
	if (!buf)
	{
		httpcCloseContext(&ctx);
		return -1;
	}

	u32 bufoset = 0; // the offset to start reading into (the size of the previous buffer)
	char* size_fmt = NULL, * speed_fmt = NULL; // formatted size & speed so far

	u64 prev_time = osGetTime();
	// download loop
	for (;;)
	{
		// TODO: buffer into the file system, not into ram - we only have 128MB of RAM for the whole system!
		u32 read;
		ret = httpcDownloadData(&ctx, buf + bufoset, 4096, &read);
		bufoset += read;

		u64 time = osGetTime();
		float time_diff = (float)(time - prev_time) / 1000; // to seconds
		prev_time = time;

		float data_rate = 4096 / time_diff; // bytes / sec

		if (size_fmt) free(size_fmt);
		if (speed_fmt) free(speed_fmt);
		size_fmt = format_size(bufoset);
		speed_fmt = format_size_f(data_rate);
		iprintf("\x1b[2JDownloaded: %s / %s (%s/s)\n", size_fmt, cl_fmt, speed_fmt);

		if (ret != HTTPC_RESULTCODE_DOWNLOADPENDING) break;

		// see comment at lastbuf decl
		lastbuf = buf;
		buf = realloc(buf, bufoset + 4096);
		if (!buf)
		{
			httpcCloseContext(&ctx);
			free(lastbuf);
			return -1;
		}
	}

	if (ret)
	{
		httpcCloseContext(&ctx);
		free(buf);
		return ret;
	}

	// at this point, our buffer is the size of the file *rounded up to a page*
	// `bufoset` contains the actual file size

	printf("downloaded size: %li (%s)\n", bufoset, size_fmt);
	free(size_fmt);

	// note as per documentation - closing the context before downloading the entire file will hang
	httpcCloseContext(&ctx);
	*buffero = buf;
	*sizeo = bufoset;

	return 0;
}

const char* url = "https://cdn.hyrule.pics/21ca0f0d1.png"; // will not work on hardware on purpose

int main(int argc, char* argv[])
{
	gfxInitDefault();
	consoleInit(GFX_TOP, NULL);
	httpcInit(0);

	printf("Hello, world!\nDownloading %s\n", url);

	u8* buf;
	u32 size;
	u32 result = http_download(url, &buf, &size);
	free(buf);

	switch (result)
	{
		case 0:
			printf("Success!\n");
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
