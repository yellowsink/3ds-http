import core.stdc.stdio : FILE, fwrite, printf;
import core.time : MonoTime;

import util : format_size;

import ys3ds.ctru._3ds.types : Result;
import ys3ds.ctru._3ds.services.httpc;
import ys3ds.ctru._3ds.services.sslc : SSLCOPT_DisableVerify;
import ys3ds.ctru._3ds.console : consoleClear;

import ys3ds.utility : toStringzManaged, fromStringzManaged;

import btl.string : String;
import btl.autoptr : UniquePtr;
import core.lifetime : move;

import std.typecons : Tuple, tuple;

enum TLS_1_1_ERROR = 0xd8a0a03c;

// result, status code
Tuple!(Result, uint) http_start_req(httpcContext* ctx, const ref String url_)
{
	Result ret = 0;
	uint res_code;

	auto url = String(url_);

	for (;;)
	{
		auto urlz = url.toStringzManaged; // UniquePtr

		ret = httpcOpenContext(ctx, HTTPC_RequestMethod.HTTPC_METHOD_GET, urlz.ptr, 1);
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

			return tuple(ret, 0u);
		}

		ret |= httpcGetResponseStatusCode(ctx, &res_code);
		//printf("[http_start_req] res status %li %lx\n", res_code, ret);
		if (ret)
		{
			httpcCloseContext(ctx); // unhandled ret

			return tuple(ret, 0u);
		}

		// handle redirects
		if ((res_code >= 301 && res_code <= 303) || (res_code >= 307 && res_code <= 308))
		{
			char[4096] redir_url_buf;

			ret |= httpcGetResponseHeader(ctx, "Location", redir_url_buf.ptr, 4096);

			printf("[http_start_req] redirect from\n%s\nto\n%s\n", urlz.ptr, redir_url_buf.ptr);

			url = redir_url_buf.ptr.fromStringzManaged;

			// we'll start from scratch with a new ctx
			httpcCloseContext(ctx);
		}

		// we didn't redirect -> break out of the loop!
		else
			break;
	}

	return tuple(ret, res_code);
}

// result, size of file
Tuple!(Result, uint) http_download(const String url, FILE* f)
{
	Result ret; // basically errno for the httpc functions
	httpcContext ctx; // httpc context

	// [result, status code]
	auto started = http_start_req(&ctx, url);
	ret |= started[0];
	if (ret)
	{
		httpcCloseContext(&ctx);
		return tuple(ret, 0u);
	}

	auto res_code = started[1];

	if (res_code != 200)
	{
		httpcCloseContext(&ctx);
		printf("response status was %li, not 200 OK\n", res_code);
		return tuple(-2, 0u);
	}

	// content-length if exists, 0 else
	uint content_len = 0;

	ret |= httpcGetDownloadSizeState(&ctx, null, &content_len);
	if (ret)
	{
		httpcCloseContext(&ctx);
		return tuple(ret, 0u);
	}

	String cl_fmt = content_len ? format_size(content_len) : String("?");

	auto clfmtz = cl_fmt.toStringzManaged;
	printf("total download size: %li (%s)\n", content_len, clfmtz.ptr);

	// 4 pages
	ubyte[4 * 4096] buf; // buffer to be read into
	uint size_so_far = 0; // the offset to start reading into (the size of the previous buffer)
	String size_fmt, speed_fmt; // formatted size & speed so far
	UniquePtr!(immutable char) size_fmt_z;

	auto prev_time = MonoTime.currTime;
	// download loop
	do
	{
		// get from http
		uint read;
		ret = httpcDownloadData(&ctx, buf.ptr, buf.length, &read);
		size_so_far += read;

		// write to SD
		fwrite(cast(char*) buf.ptr, ubyte.sizeof, read, f);

		auto time = MonoTime.currTime;
		float time_diff = (cast(float) (time - prev_time).total!"msecs") / 1000; // to seconds
		prev_time = time;

		float data_rate = 4096 / time_diff; // bytes / sec

		size_fmt = format_size(size_so_far);
		speed_fmt = format_size(data_rate);

		size_fmt_z = size_fmt.toStringzManaged;

		consoleClear();

		printf(
			"%s / %s (%.1f%%) (%s/s)\n",
			size_fmt_z.ptr,
			clfmtz.ptr,
			100. * cast(float) size_so_far / cast(float) content_len,
			speed_fmt.toStringzManaged.ptr
		);
	}
	while (ret == HTTPC_RESULTCODE_DOWNLOADPENDING);

	if (ret)
	{
		httpcCloseContext(&ctx);
		return tuple(ret, 0u);
	}

	printf("downloaded size: %li (%s)\n", size_so_far, size_fmt_z.ptr);

	// note as per documentation - closing the context before downloading the entire file will hang
	httpcCloseContext(&ctx);

	return tuple(0, size_so_far);
}
