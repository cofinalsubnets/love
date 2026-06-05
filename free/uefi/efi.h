// Minimal UEFI typedefs -- just enough to call GetMemoryMap, AllocatePool,
// LocateProtocol (for the Graphics Output Protocol) and ExitBootServices.
// We deliberately avoid gnu-efi; this header is ~10 kB and pulls nothing in.
//
// Function pointers in the Boot/Runtime Services tables use the firmware's
// native ABI, which on x86_64 is the Microsoft x64 calling convention --
// hence the EFIAPI tag. Other arches (aarch64/riscv64/loongarch64) all use
// the platform's standard AAPCS-ish ABI, so EFIAPI is empty there.
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

typedef uint64_t UINTN;             // pointer-sized unsigned
typedef int64_t  INTN;
typedef UINTN    EFI_STATUS;
typedef void *   EFI_HANDLE;
typedef uint16_t CHAR16;

#if defined(__x86_64__)
# define EFIAPI __attribute__((ms_abi))
#else
# define EFIAPI
#endif

#define EFI_SUCCESS           0
#define EFI_BUFFER_TOO_SMALL  0x8000000000000005ULL
#define EFI_ERROR(s)          ((INTN)(s) < 0)

typedef struct { uint32_t d1; uint16_t d2, d3; uint8_t d4[8]; } EFI_GUID;

// --- memory map ------------------------------------------------------
typedef enum {
  EfiReservedMemoryType, EfiLoaderCode, EfiLoaderData,
  EfiBootServicesCode, EfiBootServicesData, EfiRuntimeServicesCode,
  EfiRuntimeServicesData, EfiConventionalMemory, EfiUnusableMemory,
  EfiACPIReclaimMemory, EfiACPIMemoryNVS, EfiMemoryMappedIO,
  EfiMemoryMappedIOPortSpace, EfiPalCode, EfiPersistentMemory,
  EfiMaxMemoryType,
} EFI_MEMORY_TYPE;

typedef struct {
  uint32_t Type;
  uint32_t Pad;                     // implicit in spec; explicit here for clarity
  uint64_t PhysicalStart;
  uint64_t VirtualStart;
  uint64_t NumberOfPages;
  uint64_t Attribute;
} EFI_MEMORY_DESCRIPTOR;

// --- table header ----------------------------------------------------
typedef struct {
  uint64_t Signature;
  uint32_t Revision;
  uint32_t HeaderSize;
  uint32_t CRC32;
  uint32_t Reserved;
} EFI_TABLE_HEADER;

// --- boot services ---------------------------------------------------
// Members we don't call are declared as void* so we don't have to type
// out every signature -- the offsets are still correct because each slot
// is one pointer wide.
typedef struct EFI_BOOT_SERVICES {
  EFI_TABLE_HEADER Hdr;
  // task priority
  void *RaiseTPL;
  void *RestoreTPL;
  // memory
  void *AllocatePages;
  void *FreePages;
  EFI_STATUS (EFIAPI *GetMemoryMap)(UINTN *Size, EFI_MEMORY_DESCRIPTOR *Map,
                                    UINTN *Key, UINTN *DescSize, uint32_t *DescVer);
  EFI_STATUS (EFIAPI *AllocatePool)(EFI_MEMORY_TYPE Type, UINTN Size, void **Buf);
  EFI_STATUS (EFIAPI *FreePool)(void *Buf);
  // events & timers
  void *CreateEvent;
  void *SetTimer;
  void *WaitForEvent;
  void *SignalEvent;
  void *CloseEvent;
  void *CheckEvent;
  // protocol handlers (legacy)
  void *InstallProtocolInterface;
  void *ReinstallProtocolInterface;
  void *UninstallProtocolInterface;
  void *HandleProtocol;
  void *Reserved;
  void *RegisterProtocolNotify;
  void *LocateHandle;
  void *LocateDevicePath;
  void *InstallConfigurationTable;
  // image services
  void *LoadImage;
  void *StartImage;
  void *Exit;
  void *UnloadImage;
  EFI_STATUS (EFIAPI *ExitBootServices)(EFI_HANDLE ImageHandle, UINTN MapKey);
  // misc
  void *GetNextMonotonicCount;
  void *Stall;
  void *SetWatchdogTimer;
  // driver support
  void *ConnectController;
  void *DisconnectController;
  // OpenProtocol family
  void *OpenProtocol;
  void *CloseProtocol;
  void *OpenProtocolInformation;
  // library
  void *ProtocolsPerHandle;
  void *LocateHandleBuffer;
  EFI_STATUS (EFIAPI *LocateProtocol)(EFI_GUID *Protocol, void *Registration, void **Interface);
  // ... remaining members omitted; we don't call them.
} EFI_BOOT_SERVICES;

// --- system table ----------------------------------------------------
typedef struct EFI_SYSTEM_TABLE {
  EFI_TABLE_HEADER  Hdr;
  CHAR16           *FirmwareVendor;
  uint32_t          FirmwareRevision;     // 4 bytes of natural padding before ConsoleInHandle
  EFI_HANDLE        ConsoleInHandle;
  void             *ConIn;
  EFI_HANDLE        ConsoleOutHandle;
  void             *ConOut;
  EFI_HANDLE        StandardErrorHandle;
  void             *StdErr;
  void             *RuntimeServices;
  EFI_BOOT_SERVICES *BootServices;
  UINTN             NumberOfTableEntries;
  void             *ConfigurationTable;
} EFI_SYSTEM_TABLE;

// --- Graphics Output Protocol ---------------------------------------
typedef enum {
  PixelRedGreenBlueReserved8BitPerColor,
  PixelBlueGreenRedReserved8BitPerColor,
  PixelBitMask,
  PixelBltOnly,
  PixelFormatMax,
} EFI_GRAPHICS_PIXEL_FORMAT;

typedef struct {
  uint32_t RedMask, GreenMask, BlueMask, ReservedMask;
} EFI_PIXEL_BITMASK;

typedef struct {
  uint32_t                  Version;
  uint32_t                  HorizontalResolution;
  uint32_t                  VerticalResolution;
  EFI_GRAPHICS_PIXEL_FORMAT PixelFormat;
  EFI_PIXEL_BITMASK         PixelInformation;
  uint32_t                  PixelsPerScanLine;
} EFI_GRAPHICS_OUTPUT_MODE_INFORMATION;

typedef struct {
  uint32_t                              MaxMode;
  uint32_t                              Mode;
  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *Info;
  UINTN                                 SizeOfInfo;
  uint64_t                              FrameBufferBase;
  UINTN                                 FrameBufferSize;
} EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE;

typedef struct EFI_GRAPHICS_OUTPUT_PROTOCOL {
  void                              *QueryMode;
  void                              *SetMode;
  void                              *Blt;
  EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *Mode;
} EFI_GRAPHICS_OUTPUT_PROTOCOL;

#define EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID \
  { 0x9042a9de, 0x23dc, 0x4a38, { 0x96,0xfb,0x7a,0xde,0xd0,0x80,0x51,0x6a } }
