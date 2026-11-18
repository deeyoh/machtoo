#ifndef MACHTOO_APP_H
#define MACHTOO_APP_H

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
