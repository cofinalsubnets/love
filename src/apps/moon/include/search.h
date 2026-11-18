#pragma once
typedef enum { preorder, postorder, endorder, leaf } VISIT;
void *tsearch(void const*, void**, int (*)(void const*, void const*)),
     *tfind(void const*, void *const*, int (*)(void const*, void const*)),
     *tdelete(void const*, void**, int (*)(void const*, void const*)),
     twalk(void const*, void (*)(void const*, VISIT, int));
void  tdestroy(void*, void (*)(void*));         /* gnu: free every node, its key through f */
