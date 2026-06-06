/* Playdate hardware link script.

   This is the Playdate SDK's C_API/buildsupport/link_map.ld with one
   addition: the data self-quote sentinel block grafted into .text (marked
   below). The sentinels (g/flow.c DATA_SENTINEL) are each emitted into
   their own gwen_data_vt.NN input subsection; the SDK script has no
   collection for them, so used as-is they orphan and __start_/__stop_
   gwen_data_vt go undefined. We can't edit the SDK file in place and an
   INSERT fragment can't augment a full -T script (it pulls in the builtin
   default script and clobbers ENTRY/layout), so we keep a full copy here
   and inline the block -- the same approach as k/*.lds and pico/. KEEP
   shields the sentinels from --gc-sections; SORT_BY_NAME orders them by NN
   (enum q order) so g_typ() (g/i.h) recovers a kind from ap's slot index.

   If the SDK's link_map.ld changes, re-sync the rest of this file. */
ENTRY(eventHandlerShim)
GROUP(libgcc.a libc.a libm.a)

SECTIONS
{
	.text :
	{
		*(.text)
		*(.text.*)

		KEEP(*(.init))
		KEEP(*(.fini))

		/* .ctors */
		*crtbegin.o(.ctors)
		*crtbegin?.o(.ctors)
		*(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors)
		*(SORT(.ctors.*))
		*(.ctors)

		/* .dtors */
 		*crtbegin.o(.dtors)
 		*crtbegin?.o(.dtors)
 		*(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)
 		*(SORT(.dtors.*))
 		*(.dtors)

		*(.rodata*)

		KEEP(*(.eh_frame*))

		/* gwen data self-quote sentinels: contiguous, in enum order
		   (gwen_data_vt.NN), inside the executable text region. */
		. = ALIGN(16);
		__start_gwen_data_vt = .;
		KEEP(*(SORT_BY_NAME(gwen_data_vt.*)))
		__stop_gwen_data_vt = .;
	}

	.data :
	{
		__etext = .;

		__data_start__ = .;
		*(vtable)
		*(.data*)

		. = ALIGN(4);
		/* preinit data */
		PROVIDE_HIDDEN (__preinit_array_start = .);
		KEEP(*(.preinit_array))
		PROVIDE_HIDDEN (__preinit_array_end = .);

		. = ALIGN(4);
		/* init data */
		PROVIDE_HIDDEN (__init_array_start = .);
		KEEP(*(SORT(.init_array.*)))
		KEEP(*(.init_array))
		PROVIDE_HIDDEN (__init_array_end = .);

		. = ALIGN(4);
		/* finit data */
		PROVIDE_HIDDEN (__fini_array_start = .);
		KEEP(*(SORT(.fini_array.*)))
		KEEP(*(.fini_array))
		PROVIDE_HIDDEN (__fini_array_end = .);

		. = ALIGN(4);
		/* All data end */
		__data_end__ = .;

	}

	.bss :
	{
		. = ALIGN(4);
		__bss_start__ = .;
		*(.bss*)
		*(COMMON)
		*(COM)
		. = ALIGN(4);
		__bss_end__ = .;

	}

  /DISCARD/ :
  {
		*(.ARM.exidx)
  }

}
