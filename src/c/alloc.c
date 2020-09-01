#include <stddef.h>
#include <stdint.h>
#include "std.h"

// interface https://doc.rust-lang.org/1.19.0/src/alloc/heap.rs.html

#define MEM_TABLE    (uintptr_t) 0x03000000
#define MEM_MIN      (uintptr_t) 0x10000000
#define MEM_MAX      (uintptr_t) 0xC0000000
#define MIN_SIZE     (uint32_t)  (1 << 2)   // 4 bytes     (word)
#define MED_SIZE     (uint32_t)  (1 << 12)  // 4 kilobytes (page)
#define BIG_SIZE     (uint32_t)  (1 << 22)  // 4 megabytes
#define MAX_CHUNKS   (uint32_t)  1024
#define MAX_ALLOCS   (uint32_t)  1024
#define BYTEMAP_SIZE (uint32_t)  1024

// table entry corresponding to a chunk of contiguous memory
// TODO initialize as free list
// TODO to add entry, pop head of free list, append (or prepend?) to in-use list
// TODO to remove entry, extract from in-use list, prepend (or append?) to free list
struct chunk_entry {
  uint32_t  flags;
  // entry flags:
  // (flags & 0x1): 1 denotes that entry is valid and in use, 0 denotes entry is free
  struct chunk_entry* prev;     // pointer to prev chunk entry/prev free entry
  struct chunk_entry* next;     // pointer to next chunk entry/next free entry
  uintptr_t min;                // points to first byte in chunk
  uintptr_t max;                // points to first byte not in chunk
  uint32_t  align;              // minimum align of memory allocated from chunk
  uint32_t  fsize;              // bytes remaining in chunk
  uint8_t   fmap[BYTEMAP_SIZE]; // byte map of free space, 0 = free
};

struct alloc_entry {
  uint32_t flags;
  // entry flags:
  // (flags & 0x1): 1 denotes that entry is valid and in use, 0 denotes entry is free
  struct alloc_entry* parent; // pointer to parent allocator entry/next free entry
  uint32_t align;
  uint32_t fsize;
  uint32_t nchunks;
  struct chunk_entry* uhead;  // points to head of in-use list
  struct chunk_entry* utail;  // points to tail of in-use list
  struct chunk_entry* fhead;  // points to head of free list
  struct chunk_entry chunk_table[MAX_CHUNKS];
};

struct alloc_tree {
  uint32_t nallocs;
  struct alloc_entry* uroot; // points to root of in-use tree
  struct alloc_entry* fhead; // points to head of free list
  struct alloc_entry alloc_table[MAX_ALLOCS];
};

static struct alloc_tree* g_alloc_tree = (struct alloc_tree*) MEM_TABLE;

/* inserts a new allocator entry into the global allocator tree.
 * returns the new alloc_entry if successful, NULL if failure
 */
struct alloc_entry* insert_alloc(struct alloc_entry* parent, uint32_t align) {
  // pop head from free list
  struct alloc_entry* alloc = g_alloc_tree->fhead;
  if (alloc == NULL) {
    // fail if free list empty
    return NULL;
  }
  // TODO do we even need to track root?
  // check if adding new root
  if (parent == NULL) {
    // check if root already exists
    if (g_alloc_tree->uroot == NULL) {
      g_alloc_tree->uroot = alloc;
    } else {
      // fail if adding root, but root already exists
      return NULL;
    }
  }
  g_alloc_tree->fhead = alloc->parent;

  // set fields
  alloc->flags   = 0x1;
  alloc->parent  = parent;
  alloc->align   = align;
  alloc->fsize   = 0;
  alloc->nchunks = 0;
  alloc->uhead   = NULL;
  alloc->utail   = NULL;
  alloc->fhead   = alloc->chunk_table;

  // initialize free list
  for (uint32_t i = 0; i < MAX_CHUNKS; i++) {
    struct chunk_entry* chunk = alloc->chunk_table + i;
    chunk->flags = 0;
    chunk->next  = (i == MAX_CHUNKS - 1) ? NULL : alloc->chunk_table + i + 1;
  }
  g_alloc_tree->nallocs += 1;
  return alloc;
}

/* inserts a new chunk entry to the specified allocator entry.
 * returns the new chunk_entry if successful, NULL if failure
 */
struct chunk_entry* insert_chunk(struct alloc_entry* alloc, uintptr_t min, uintptr_t max) {
  // pop head from free list
  struct chunk_entry* chunk = alloc->fhead;
  if (chunk == NULL) {
    // fail if free list empty
    return NULL;
  }
  alloc->fhead = chunk->next;

  // set fields
  chunk->flags = 0x1;
  chunk->prev  = alloc->utail;
  chunk->next  = NULL;
  chunk->min   = min;
  chunk->max   = max;
  chunk->align = alloc->align;
  chunk->fsize = max - min;
  memset(chunk->fmap, 0, BYTEMAP_SIZE);

  // append to in-use list
  if (alloc->uhead == NULL) {
    alloc->uhead = chunk;
  } else {
    alloc->utail->next = chunk;
  }
  alloc->utail = chunk;
  alloc->nchunks += 1;
  alloc->fsize += chunk->fsize;
  return chunk;
}

// initialize global allocator tree
void init_alloc_tree() {
  g_alloc_tree->nallocs = 0;
  g_alloc_tree->uroot   = NULL;
  g_alloc_tree->fhead   = g_alloc_tree->alloc_table;

  // initialize free list
  for (uint32_t i = 0; i < MAX_ALLOCS; i++) {
    struct alloc_entry* alloc = g_alloc_tree->alloc_table + i;
    alloc->flags  = 0;
    alloc->parent = (i == MAX_ALLOCS - 1) ? NULL : g_alloc_tree->alloc_table + i + 1;
  }

  // add top level allocator
  struct alloc_entry* alloc = insert_alloc(NULL, BIG_SIZE);
  // owns single chunk of memory = all memory
  insert_chunk(alloc, MEM_MIN, MEM_MAX);
}

/* assumes align is a power of 2 and greater than or equal to allocator align
 * returns address if allocation successful, returns NULL if fails
 */
void* allocate_internal_chunk(struct chunk_entry* chunk, uint32_t size, uint32_t align) {
  if (size > chunk->fsize) {
    // if not enough space, fail immediately
    return NULL;
  }

  // look for contiguous memory of requisite size and alignment
  uint32_t contig = 0; // counts contiguous memory areas with size allocator->align
  for (uint32_t i = 0; i < BYTEMAP_SIZE; i++) {
    if (chunk->fmap[i] == 0 && (contig > 0 || i % (align / chunk->align) == 0)) {
      /* increment contiguous counter if:
       *   -mem location is free and already counting (is contiguous with already counted mem)
       *   -mem location is free and alignment matches (can start counting new contiguous mem)
       */
      contig++;
    } else {
      // otherwise reset contiguous counter
      contig = 0;
    }
    // check if enough contiguous memory found
    if (contig * chunk->align >= size) {
      // mark as used
      for (uint32_t j = i - contig + 1; j <= i; j++) {
        chunk->fmap[j] = 1;
      }
      // decrease free mem counters
      chunk->fsize -= contig * chunk->align;
      // alloc->fsize -= contig * chunk->align; TODO propagate upwards
      return (void*) (chunk->min + chunk->align * (i - contig + 1));
    }
  }
  return NULL;
}

// main allocate method
void* allocate_internal(struct alloc_entry* alloc, uint32_t size, uint32_t align) {
  if (alloc == NULL) {
    // if no allocator specified, fails
    return NULL;
  }

  if ((align & (align - 1)) != 0) {
    // if align is not a power of 2 or 0, fails
    return NULL;
  }

  // set align to be max of two aligns
  if (alloc->align > align) {
    align = alloc->align;
  }

  // if size does not fit, get more memory from parent and retry
  if (size > alloc->fsize) {
    uint32_t csize = size << 1; // size to allocate for new chunk // TODO overflow checking?
    // TODO just round up to power of 2? or round to alloc->align << 2?
    uintptr_t chunk_mem = (uintptr_t) allocate_internal(alloc->parent, csize, align);
    if (chunk_mem) {
      struct chunk_entry* chunk = insert_chunk(alloc, chunk_mem, chunk_mem + csize);
      if (chunk != NULL) {
        void* mem = allocate_internal_chunk(chunk, size, align);
        if (mem != NULL) {
          return mem;
        }
        // if mem cannot be allocated from chunk, remove chunk entry
        // TODO remove chunk
      }
      // if new chunk cannot be inserted free chunk memory in parent
      // TODO free chunk_mem
    }
    // if no new memory for a new chunk can be allocated from parent, fails
    return NULL;
  }

  // try allocate from each chunk in chunk list
  for (struct chunk_entry* chunk = alloc->uhead; chunk != NULL; chunk = chunk->next) {
    void* mem = allocate_internal_chunk(chunk, size, align);
    if (mem != NULL) {
      return mem;
    }
  }

  // could not find free space, so request parent
  uint32_t csize = size << 1; // size to allocate for new chunk // TODO overflow checking?
  // TODO just round up to power of 2? or round to alloc->align << 2?
  uintptr_t chunk_mem = (uintptr_t) allocate_internal(alloc->parent, csize, align);
  if (chunk_mem) {
    struct chunk_entry* chunk = insert_chunk(alloc, chunk_mem, chunk_mem + csize);
    if (chunk != NULL) {
      void* mem = allocate_internal_chunk(chunk, size, align);
      if (mem != NULL) {
        return mem;
      }
      // if mem cannot be allocated from chunk, remove chunk entry
      // TODO remove chunk
    }
    // if new chunk cannot be inserted free chunk memory in parent
    // TODO free chunk_mem
  }
  // if no new memory for a new chunk can be allocated from parent, fails
  return NULL;
}

/*void* allocate(uint32_t size, uint32_t align) {
  return NULL;
}

void* reallocate_inplace(void* ptr, uint32_t old_size, uint32_t size, uint32_t align) {
  if (old_size <= size) {
    return ptr; // TODO weird
  }
  return NULL;
}

void* reallocate(void* ptr, uint32_t old_size, uint32_t size, uint32_t align) {
  void* newptr = reallocate_inplace(ptr, old_size, size, align);
  if (newptr) {
    return newptr;
  }
  newptr = malloc(size, align);
  if (newptr) {
    free(ptr);
    return newptr;
  }
  return NULL;
}

void deallocate(void* ptr, uint32_t old_size, uint32_t align) {}

uint32_t usable_size(uint32_t size, uint32_t align) {
  return size;
}*/
