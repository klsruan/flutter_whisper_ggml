#if defined(__aarch64__) || defined(__arm64__)
#include "../../whisper/v1.9.2/ggml/src/ggml-cpu/arch/arm/quants.c"
#elif defined(__x86_64__)
#include "../../whisper/v1.9.2/ggml/src/ggml-cpu/arch/x86/quants.c"
#endif
