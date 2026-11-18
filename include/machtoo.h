#ifndef MACHTOO_H
#define MACHTOO_H

#include <stddef.h>
#include <stdint.h>
#include "machtoo/app.h"
#include "machtoo/keys.h"

int32_t machtoo_add(int32_t a, int32_t b);

typedef struct {
  const uint8_t *ptr;
  size_t len;
} ApiString;

typedef struct {
  ApiString id;
  ApiString name;
  ApiString description;
} ApiCommand;

/*
 * Returns the total number of available commands.
 *
 * Writes min(capacity, total) records into out_commands.
 * Pass NULL with capacity 0 to query the required capacity.
 * If out_commands is NULL, no records are written.
 *
 * The caller owns the output buffer. String pointers borrow storage-owned
 * memory and must not be freed. Copy their bytes before storage mutation
 * or app destruction.
 *
 * Reads and string copying must not overlap storage mutation.
 * A NULL app returns 0.
 */
size_t machtoo_app_read_commands(
  MachtooApp *app,
  ApiCommand *out_commands,
  size_t capacity
);

#endif
