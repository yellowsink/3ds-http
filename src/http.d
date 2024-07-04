import binds.stdc : FILE, fwrite, printf;

import util : format_size, free_d, slicedup, toStringz;

import ys3ds.ctru._3ds.types : Result;
import ys3ds.ctru._3ds.services.httpc;
import ys3ds.ctru._3ds.services.sslc : SSLCOPT_DisableVerify;
import ys3ds.ctru._3ds.os : osGetTime;

enum TLS_1_1_ERROR = 0xd8a0a03c;

Result http_start_req(httpcContext* ctx, const(char)[] url, uint* res_code)
{
	Result ret = 0;
	// allocate on stack
	char[4096] redir_url_buf;

	for (;;)
	{
		auto urlz = url.toStringz;

		ret = httpcOpenContext(ctx, HTTPC_RequestMethod.HTTPC_METHOD_GET, urlz, 1);
		//printf("[http_start_req] opened %lx\n", ret);

		// disable cert verification, as the 3ds is fuckin old lmao
		ret |= httpcSetSSLOpt(ctx, SSLCOPT_DisableVerify);
		//printf("[http_start_req] disabled certs %lx\n", ret);

		// purposefully don't enable keep-alive, we don't need it
		ret |= httpcSetKeepAlive(ctx, HTTPC_KeepAlive.HTTPC_KEEPALIVE_DISABLED);
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
			/* if (redir_url_buf)
				free(redir_url_buf); */

			return ret;
		}

		ret |= httpcGetResponseStatusCode(ctx, res_code);
		//printf("[http_start_req] res status %li %lx\n", *res_code, ret);
		if (ret)
		{
			httpcCloseContext(ctx); // unhandled ret
			/* if (redir_url_buf)
				free(redir_url_buf); */

			return ret;
		}

		// handle redirects
		if ((*res_code >= 301 && *res_code <= 303) || (*res_code >= 307 && *res_code <= 308))
		{
			// expect the redirect url to fit in 4k chars
			/* if (!redir_url_buf)
				redir_url_buf = malloc(4096); */

			/* if (!redir_url_buf)
			{
				httpcCloseContext(ctx);
				return -1;
			} */

			ret |= httpcGetResponseHeader(ctx, "Location", redir_url_buf.ptr, 4096);

			printf("[http_start_req] redirect from\n%s\nto\n%s\n", urlz, redir_url_buf.ptr);

			url = redir_url_buf[];

			free_d(urlz);

			// we'll start from scratch with a new ctx
			httpcCloseContext(ctx);
		}

		// we didn't redirect -> break out of the loop!
		else
			break;
	}

	/* free(redir_url_buf); */
	return ret;
}

Result http_download(const(char)[] url, FILE* f, uint* sizeo)
{
	Result ret; // basically errno for the httpc functions
	httpcContext ctx; // httpc context
	uint res_code; // http resp status code

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
	uint content_len = 0;
	char[] cl_fmt;

	ret |= httpcGetDownloadSizeState(&ctx, null, &content_len);
	if (ret)
	{
		httpcCloseContext(&ctx);
		return ret;
	}

	if (content_len)
		cl_fmt = format_size(content_len);
	else
		cl_fmt = "?".slicedup;

	auto clfmtz = cl_fmt.toStringz;
	printf("total download size: %li (%s)\n", content_len, clfmtz);

	// buffer we read into
	ubyte[4096] buf;

	// init buffer - one page
	/* buf = malloc(4096);
	if (!buf)
	{
		httpcCloseContext(&ctx);
		return -1;
	} */

	uint size_so_far = 0; // the offset to start reading into (the size of the previous buffer)
	char[] size_fmt = null, speed_fmt = null; // formatted size & speed so far

	ulong prev_time = osGetTime();
	// download loop
	do
	{
		// get from http
		uint read;
		ret = httpcDownloadData(&ctx, buf.ptr, buf.length, &read);
		size_so_far += read;

		// write to SD
		fwrite(cast(char*) buf.ptr, ubyte.sizeof, read, f);

		ulong time = osGetTime();
		float time_diff = cast(float)(time - prev_time) / 1000; // to seconds
		prev_time = time;
		float data_rate = 4096 / time_diff; // bytes / sec

		if (size_fmt)
			free_d(size_fmt);
		if (speed_fmt)
			free_d(speed_fmt);

		size_fmt = format_size(size_so_far);
		speed_fmt = format_size(data_rate);

		// the output of format_size is null terminated
		printf("\x1b[2JDownloaded: %s / %s (%s/s)\n", size_fmt.ptr, clfmtz, speed_fmt.ptr);

	}
	while (ret == HTTPC_RESULTCODE_DOWNLOADPENDING);

	if (ret)
	{
		httpcCloseContext(&ctx);
		free_d(buf);
		return ret;
	}

	printf("downloaded size: %li (%s)\n", size_so_far, size_fmt.ptr);
	free_d(size_fmt);
	free_d(speed_fmt);
	//free_d(buf);
	free_d(clfmtz);

	// note as per documentation - closing the context before downloading the entire file will hang
	httpcCloseContext(&ctx);
	*sizeo = size_so_far;

	return 0;
}
