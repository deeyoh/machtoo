#ifndef MACHTOO_KEYS_H
#define MACHTOO_KEYS_H

#include <stdint.h>
#include <stdbool.h>
#include "app.h"

typedef enum {
  MACHTOO_KEY_RELEASE = 0,
  MACHTOO_KEY_PRESS = 1,
} MachtooKeyActionVariant;

enum {
  MACHTOO_MOD_SHIFT    = 1 << 0,
  MACHTOO_MOD_CONTROL  = 1 << 1,
  MACHTOO_MOD_ALT      = 1 << 2,
  MACHTOO_MOD_SUPER    = 1 << 3
};

typedef struct {
  MachtooKeyActionVariant action;
  /* macOS virtual keycode */
  uint32_t native_keycode;
  uint32_t mods;
} MachtooKeyEvent;

/*
 * Must be called on the UI thread
 * Returns true when the event should be consumed by the frontend.
 */
bool machtoo_app_key_event(
  MachtooApp *app,
  MachtooKeyEvent event
);

#endif
