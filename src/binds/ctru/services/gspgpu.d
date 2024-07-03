// required for gfx

extern(C):

import binds.ctru.types;

/**
  * @file gspgpu.h
  * @brief GSPGPU service.
  */
enum GSP_SCREEN_TOP = 0; ///< ID of the top screen.
enum GSP_SCREEN_BOTTOM = 1; ///< ID of the bottom screen.
enum GSP_SCREEN_WIDTH = 240; ///< Width of the top/bottom screens.
enum GSP_SCREEN_HEIGHT_TOP = 400; ///< Height of the top screen.
enum GSP_SCREEN_HEIGHT_TOP_2X = 800; ///< Height of the top screen (2x).
enum GSP_SCREEN_HEIGHT_BOTTOM = 320; ///< Height of the bottom screen.

/// Framebuffer information.
struct GSPGPU_FramebufferInfo
{
	uint active_framebuf; ///< Active framebuffer. (0 = first, 1 = second)
	uint* framebuf0_vaddr; ///< Framebuffer virtual address, for the main screen this is the 3D left framebuffer.
	uint* framebuf1_vaddr; ///< For the main screen: 3D right framebuffer address.
	uint framebuf_widthbytesize; ///< Value for 0x1EF00X90, controls framebuffer width.
	uint format; ///< Framebuffer format, this u16 is written to the low u16 for LCD register 0x1EF00X70.
	uint framebuf_dispselect; ///< Value for 0x1EF00X78, controls which framebuffer is displayed.
	uint unk; ///< Unknown.
}

/// Framebuffer format.
enum GSPGPU_FramebufferFormat
{
	GSP_RGBA8_OES=0, ///< RGBA8. (4 bytes)
	GSP_BGR8_OES=1, ///< BGR8. (3 bytes)
	GSP_RGB565_OES=2, ///< RGB565. (2 bytes)
	GSP_RGB5_A1_OES=3, ///< RGB5A1. (2 bytes)
	GSP_RGBA4_OES=4 ///< RGBA4. (2 bytes)
}

/// Capture info entry.
struct GSPGPU_CaptureInfoEntry
{
	uint* framebuf0_vaddr; ///< Left framebuffer.
	uint* framebuf1_vaddr; ///< Right framebuffer.
	uint format; ///< Framebuffer format.
	uint framebuf_widthbytesize; ///< Framebuffer pitch.
}

/// Capture info.
struct GSPGPU_CaptureInfo
{
	GSPGPU_CaptureInfoEntry[2] screencapture; ///< Capture info entries, one for each screen.
}

/// GSPGPU events.
enum GSPGPU_Event
{
	GSPGPU_EVENT_PSC0 = 0, ///< Memory fill completed.
	GSPGPU_EVENT_PSC1, ///< TODO
	GSPGPU_EVENT_VBlank0, ///< TODO
	GSPGPU_EVENT_VBlank1, ///< TODO
	GSPGPU_EVENT_PPF, ///< Display transfer finished.
	GSPGPU_EVENT_P3D, ///< Command list processing finished.
	GSPGPU_EVENT_DMA, ///< TODO

	GSPGPU_EVENT_MAX, ///< Used to know how many events there are.
}

/**
  * @brief Gets the number of bytes per pixel for the specified format.
  * @param format See \ref GSPGPU_FramebufferFormat.
  * @return Bytes per pixel.
  */
static uint gspGetBytesPerPixel(GSPGPU_FramebufferFormat format)
{
	switch (format) with (GSPGPU_FramebufferFormat)
	{
		case GSP_RGBA8_OES:
			return 4;
		default:
		case GSP_BGR8_OES:
			return 3;
		case GSP_RGB565_OES:
		case GSP_RGB5_A1_OES:
		case GSP_RGBA4_OES:
			return 2;
	}
}

/// Initializes GSPGPU.
Result gspInit();

/// Exits GSPGPU.
void gspExit();

/**
  * @brief Gets a pointer to the current gsp::Gpu session handle.
  * @return A pointer to the current gsp::Gpu session handle.
  */
Handle* gspGetSessionHandle();

/// Returns true if the application currently has GPU rights.
bool gspHasGpuRight();

/**
  * @brief Presents a buffer to the specified screen.
  * @param screen Screen ID (see \ref GSP_SCREEN_TOP and \ref GSP_SCREEN_BOTTOM)
  * @param swap Specifies which set of framebuffer registers to configure and activate (0 or 1)
  * @param fb_a Pointer to the framebuffer (in stereo mode: left eye)
  * @param fb_b Pointer to the secondary framebuffer (only used in stereo mode for the right eye, otherwise pass the same as fb_a)
  * @param stride Stride in bytes between scanlines
  * @param mode Mode configuration to be written to LCD register
  * @return true if a buffer had already been presented to the screen but not processed yet by GSP, false otherwise.
  * @note The most recently presented buffer is processed and configured during the specified screen's next VBlank event.
  */
bool gspPresentBuffer(uint screen, uint swap, const void* fb_a, const void* fb_b, uint stride, uint mode);

/**
  * @brief Returns true if a prior \ref gspPresentBuffer command is still pending to be processed by GSP.
  * @param screen Screen ID (see \ref GSP_SCREEN_TOP and \ref GSP_SCREEN_BOTTOM)
  */
bool gspIsPresentPending(uint screen);

/**
  * @brief Configures a callback to run when a GSPGPU event occurs.
  * @param id ID of the event.
  * @param cb Callback to run.
  * @param data Data to be passed to the callback.
  * @param oneShot When true, the callback is only executed once. When false, the callback is executed every time the event occurs.
  */
void gspSetEventCallback(GSPGPU_Event id, ThreadFunc cb, void* data, bool oneShot);

/**
  * @brief Waits for a GSPGPU event to occur.
  * @param id ID of the event.
  * @param nextEvent Whether to discard the current event and wait for the next event.
  */
void gspWaitForEvent(GSPGPU_Event id, bool nextEvent);

/**
  * @brief Waits for any GSPGPU event to occur.
  * @return The ID of the event that occurred.
  *
  * The function returns immediately if there are unprocessed events at the time of call.
  */
GSPGPU_Event gspWaitForAnyEvent();

/// Waits for PSC0
void gspWaitForPSC0()
{
	gspWaitForEvent(GSPGPU_Event.GSPGPU_EVENT_PSC0, false);
}

/// Waits for PSC1
void gspWaitForPSC1()
{
	gspWaitForEvent(GSPGPU_Event.GSPGPU_EVENT_PSC1, false);
}

/// Waits for VBlank.
void gspWaitForVBlank()
{
	gspWaitForVBlank0();
}

/// Waits for VBlank0.
void gspWaitForVBlank0()
{
	gspWaitForEvent(GSPGPU_Event.GSPGPU_EVENT_VBlank0, true);
}

/// Waits for VBlank1.
void gspWaitForVBlank1()
{
	gspWaitForEvent(GSPGPU_Event.GSPGPU_EVENT_VBlank1, true);
}

/// Waits for PPF.
void gspWaitForPPF()
{
	gspWaitForEvent(GSPGPU_Event.GSPGPU_EVENT_PPF, false);
}

/// Waits for P3D.
void gspWaitForP3D()
{
	gspWaitForEvent(GSPGPU_Event.GSPGPU_EVENT_P3D, false);
}

/// Waits for DMA.
void gspWaitForDMA()
{
	gspWaitForEvent(GSPGPU_Event.GSPGPU_EVENT_DMA, false);
}

/**
  * @brief Submits a GX command.
  * @param gxCommand GX command to execute.
  */
Result gspSubmitGxCommand(const uint[0x8] gxCommand);

/**
  * @brief Acquires GPU rights.
  * @param flags Flags to acquire with.
  */
Result GSPGPU_AcquireRight(ubyte flags);

/// Releases GPU rights.
Result GSPGPU_ReleaseRight();

/**
  * @brief Retrieves display capture info.
  * @param captureinfo Pointer to output capture info to.
  */
Result GSPGPU_ImportDisplayCaptureInfo(GSPGPU_CaptureInfo* captureinfo);

/// Saves the VRAM sys area.
Result GSPGPU_SaveVramSysArea();

/// Resets the GPU
Result GSPGPU_ResetGpuCore();

/// Restores the VRAM sys area.
Result GSPGPU_RestoreVramSysArea();

/**
  * @brief Sets whether to force the LCD to black.
  * @param flags Whether to force the LCD to black. (0 = no, non-zero = yes)
  */
Result GSPGPU_SetLcdForceBlack(ubyte flags);

/**
  * @brief Updates a screen's framebuffer state.
  * @param screenid ID of the screen to update.
  * @param framebufinfo Framebuffer information to update with.
  */
Result GSPGPU_SetBufferSwap(uint screenid, const GSPGPU_FramebufferInfo* framebufinfo);

/**
  * @brief Flushes memory from the data cache.
  * @param adr Address to flush.
  * @param size Size of the memory to flush.
  */
Result GSPGPU_FlushDataCache(const void* adr, uint size);

/**
  * @brief Invalidates memory in the data cache.
  * @param adr Address to invalidate.
  * @param size Size of the memory to invalidate.
  */
Result GSPGPU_InvalidateDataCache(const void* adr, uint size);

/**
  * @brief Writes to GPU hardware registers.
  * @param regAddr Register address to write to.
  * @param data Data to write.
  * @param size Size of the data to write.
  */
Result GSPGPU_WriteHWRegs(uint regAddr, const uint* data, ubyte size);

/**
  * @brief Writes to GPU hardware registers with a mask.
  * @param regAddr Register address to write to.
  * @param data Data to write.
  * @param datasize Size of the data to write.
  * @param maskdata Data of the mask.
  * @param masksize Size of the mask.
  */
Result GSPGPU_WriteHWRegsWithMask(uint regAddr, const uint* data, ubyte datasize, const uint* maskdata, ubyte masksize);

/**
  * @brief Reads from GPU hardware registers.
  * @param regAddr Register address to read from.
  * @param data Buffer to read data to.
  * @param size Size of the buffer.
  */
Result GSPGPU_ReadHWRegs(uint regAddr, uint* data, ubyte size);

/**
  * @brief Registers the interrupt relay queue.
  * @param eventHandle Handle of the GX command event.
  * @param flags Flags to register with.
  * @param outMemHandle Pointer to output the shared memory handle to.
  * @param threadID Pointer to output the GSP thread ID to.
  */
Result GSPGPU_RegisterInterruptRelayQueue(Handle eventHandle, uint flags, Handle* outMemHandle, ubyte* threadID);

/// Unregisters the interrupt relay queue.
Result GSPGPU_UnregisterInterruptRelayQueue();

/// Triggers a handling of commands written to shared memory.
Result GSPGPU_TriggerCmdReqQueue();

/**
  * @brief Sets 3D_LEDSTATE to the input state value.
  * @param disable False = 3D LED enable, true = 3D LED disable.
  */
Result GSPGPU_SetLedForceOff(bool disable);