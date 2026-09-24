#include "game/common/loader_rpc_types.h"
#include "game/sce/sif_ee.h"

// Host libruntime.a still lacks this pointer (kdgo.cpp in-tree has it).
// The GAME fixture links the product iOS sif path, which references it.
extern ee::sceSifClientData cd[6];
ee::sceSifClientData* g_ottsel_loader_rpc_bd = &cd[LOADER_RPC_CHANNEL];
