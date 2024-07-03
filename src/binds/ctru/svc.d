// PARTIAL: ONLY IMPLEMENTS WHAT IS NEEDED FOR os.d: svcGetSystemTick, svcGetSystemInfo, MemRegion

import binds.ctru.types;

enum MemRegion
{
	MEMREGION_ALL = 0, ///< All regions.
	MEMREGION_APPLICATION = 1, ///< APPLICATION memory.
	MEMREGION_SYSTEM = 2, ///< SYSTEM memory.
	MEMREGION_BASE = 3, ///< BASE memory.
}

/**
  * @brief Gets the current system tick.
  * @return The current system tick.
  */
ulong svcGetSystemTick();

/**
  * @brief Gets the system info.
  * @param[out] out Pointer to output the system info to.
  * @param type Type of system info to retrieve.
  * @param param Parameter clarifying the system info type.
  */
Result svcGetSystemInfo(long* _out, ulong type, long param);