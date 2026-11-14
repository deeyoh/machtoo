#ifndef MACHTOO_H
#define MACHTOO_H

#include <stdint.h>

int32_t machtoo_add(int32_t a, int32_t b);

/* 
 * App struct intentionally incomplete to enforce that callers
 * cannot inspect its fields. App usage relies on an opaque pointer.
 */
typedef struct MachtooApp MachtooApp;

/* Returns NULL if app allocation fails */
MachtooApp *machtoo_app_create(void);

/* Accepts NULL, otherwise app must be a live handle */
void machtoo_app_destroy(MachtooApp *app);

#endif
