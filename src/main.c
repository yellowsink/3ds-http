#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <3ds.h>

// starts a request, and follows all redirects
Result http_start_req(httpcContext* ctx, const char* url, u32* res_code)
{
	Result ret = 0;
	char* redir_url_buf = NULL;

	for (;;)
	{
		ret = httpcOpenContext(ctx, HTTPC_METHOD_GET, url, 0);

		// disable cert verification, as the 3ds is fuckin old lmao
		ret |= httpcSetSSLOpt(ctx, SSLCOPT_DisableVerify);

		// purposefully don't enable keep-alive, we don't need it

		// set a UA
		ret |= httpcAddRequestHeaderField(ctx, "User-Agent", "3ds-http/1.0.0");

		// request!
		ret |= httpcBeginRequest(ctx);
		if (ret)
		{
			httpcCloseContext(ctx); // unhandled ret
			if (redir_url_buf)
				free(redir_url_buf);

			return ret;
		}

		ret |= httpcGetResponseStatusCode(ctx, res_code);
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

			printf("URL Redirect from\n%s\nto\n%s\n", url, redir_url_buf);

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

	ret |= httpcGetDownloadSizeState(&ctx, NULL, &content_len);
	if (ret)
	{
		httpcCloseContext(&ctx);
		return ret;
	}

	u8* buf, *lastbuf; // buffer we read into, and the previous one in case realloc fails and we gotta free it

	// init first buffer - one page
	buf = malloc(4096);
	if (!buf)
	{
		httpcCloseContext(&ctx);
		return -1;
	}

	u32 bufoset = 0; // the offset to start reading into (the size of the previous buffer)

	// download loop
	for (;;)
	{
		// TODO: buffer into the file system, not into ram - we only have 128MB of RAM for the whole system!
		u32 read;
		ret = httpcDownloadData(&ctx, buf + bufoset, 4096, &read);
		bufoset += read;

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

	printf("downloaded size: %li\n", bufoset);

	// note as per documentation - closing the context before downloading the entire file will hang
	httpcCloseContext(&ctx);
	*buffero = buf;
	*sizeo = bufoset;

	return 0;
}

const char* url = "https://f.yellows.ink/powerline_ethernet.jpg";

int main(int argc, char* argv[])
{
	gfxInitDefault();
	consoleInit(GFX_TOP, NULL);

	printf("Hello, world!\nDownloading %s...\n", url);

	u8* buf;
	u32 size;
	u8 result = http_download(url, &buf, &size);

	if (result)
	{
		printf("Download failed! %i\n", result);
	}
	else
	{
		printf("Success!\n");
		printf("Byte 5 is %i\n", buf[4]);
	}

	free(buf);

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

	gfxExit();
	return 0;
}
