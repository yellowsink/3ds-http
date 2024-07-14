import btl.string : String;

private
{
	enum KiB = "KiB";
	enum MiB = "MiB";
}

String format_size(float bytesf)
{
	import core.stdc.stdio : snprintf;

	string specifier;

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

	char[128] buf; // 128 bytes should be wayyy overkill
	// the returned length excludes the null terminator
	auto fltlen = snprintf(buf.ptr, 128, "%.2f", bytesf);

	return String(buf[0 .. fltlen]) ~ String(specifier);
}

String format_size(uint bytes)
{
	return format_size(cast(float) bytes);
}
