/* Pin the layout of the data self-quote sentinels (flow.c DATA_SENTINEL).

   Each sentinel is emitted into its own input subsection gwen_data.NN,
   NN matching its enum q slot. SORT_BY_NAME lays the subsections out in NN
   order, so the sentinels form one contiguous, enum-ordered block and
   g_typ() (g/i.h) can recover a data object's kind from its ap's slot index
   ((ap - __start) / unit). Without this the linker is free to emit the
   bodies in any order -- an earlier build did exactly that.

   KEEP stops --gc-sections from dropping sentinels that are only reached
   through the type tag. The leading-dot output name (.gwen_data) is not
   a C identifier, so the linker does not auto-define __start_/__stop_; we
   define the bounds explicitly here, which i.h declares as extern char[].

   The lone INSERT makes this augment the default linker script rather than
   replace it, so it drops in as a plain `-T` fragment on the host link.
   Frontends that supply their own full linker script (k/, pico/) must
   instead inline an equivalent .gwen_data block before g_typ is used. */
SECTIONS {
  .gwen_data : {
    __start_gwen_data = .;
    KEEP(*(SORT_BY_NAME(gwen_data.*)))
    __stop_gwen_data = .;
  }
} INSERT AFTER .text;
