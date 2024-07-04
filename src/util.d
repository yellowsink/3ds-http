private
{
	enum KiB = "KiB";
	enum MiB = "MiB";
}

// TEMPORARY - until ported druntime works
// src[] = dst[]
private void __memcpy(T)(const T[] src, T[] dst)
{
	assert(src.length == dst.length);

	for (size_t i = 0; i < src.length; i++)
		dst[i] = src[i];
}

// nicer malloc

T* malloc_d(T)()
{
	import binds.stdc : malloc;
	auto ptr = cast(T*) malloc(T.sizeof);
	*ptr = T.init;
	return ptr;
}

T[] malloc_slice(T)(uint len)
{
	import binds.stdc : malloc;

	auto slice = (cast(T*) malloc(T.sizeof * len))[0 .. len];
	slice[] = T.init;
	return slice;
}

void free_d(T)(T* ptr)
{
	import binds.stdc : free;
	free(cast(void*) ptr);
}

void free_d(T)(T[] slice)
{
	free_d(slice.ptr);
}

T[] slicedup(T)(const T[] src, bool free = false)
{
	auto dst = malloc_slice!T(src.length);
	//dst[] = src[];
	__memcpy(src, dst);
	if (free) free_d(src);
	return dst;
}

// phobos std.string.toStringz
immutable(char)* toStringz(scope const(char)[] s, bool freeInput = false)
{
	if (s.length == 0) // empty
		return "".ptr;

	// make copy
	auto copy = malloc_slice!char(s.length + 1);
	//copy[0 .. s.length] = s[];
  __memcpy(s, copy[0 .. s.length]);
	copy[s.length] = 0; // write null terminator

	if (freeInput) free_d(s);

	return &(cast(immutable) copy[0]);
}

char[] format_size(float bytesf)
{
	import binds.stdc : sprintf;

	immutable(char)* specifier;

	if (bytesf > (1024*1024))
	{
		bytesf /= (1024*1024);
		specifier = MiB.ptr;
	}
	else if (bytesf > 1024)
	{
		bytesf /= 1024;
		specifier = KiB.ptr;
	}

	char[] s = malloc_slice!char(256);
	sprintf(s.ptr, "%.2f%s", bytesf, specifier);
	return s;
}

char[] format_size(uint bytes)
{
	return format_size(cast(float) bytes);
}
