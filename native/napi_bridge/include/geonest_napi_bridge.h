#ifndef GEONEST_NAPI_BRIDGE_H
#define GEONEST_NAPI_BRIDGE_H

#include "napi/native_api.h"

EXTERN_C_START
napi_value InitGeoNestGisModule(napi_env env, napi_value exports);
EXTERN_C_END

#endif // GEONEST_NAPI_BRIDGE_H
