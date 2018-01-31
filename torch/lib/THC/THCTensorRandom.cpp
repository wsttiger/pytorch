#include "THCTensorRandom.h"

#include <random>
#if defined(__HIP_PLATFORM_HCC__)
#include <hiprand.h>
#else
#include <curand.h>
#endif

void initializeGenerator(THCState *state, Generator* gen);
void createGeneratorState(Generator* gen, uint64_t seed);


/* Frees memory allocated during setup. */
void destroyGenerator(THCState *state, Generator* gen)
{
  if (gen->gen_states)
  {
    THCudaCheck(THCudaFree(state, gen->gen_states));
    gen->gen_states = NULL;
  }
  if (gen->kernel_params)
  {
    THCudaCheck(THCudaFree(state, gen->kernel_params));
    gen->kernel_params = NULL;
  }
}

static uint64_t createSeed(std::random_device& rd)
{
  // limit to 53 bits to ensure unique representation in double
  uint64_t seed = (((uint64_t)rd()) << 32) + rd();
  return seed & 0x1FFFFFFFFFFFFF;
}

/* Initialize generator array (must be called before any other function) */
void THCRandom_init(THCState* state, int devices, int current_device)
{
  THCRNGState* rng_state = THCState_getRngState(state);
  rng_state->num_devices = devices;
  rng_state->gen = (Generator*)malloc(rng_state->num_devices * sizeof(Generator));
  std::random_device rd;
  for (int i = 0; i < rng_state->num_devices; ++i)
  {
    rng_state->gen[i].initf = 0;
    rng_state->gen[i].initial_seed = createSeed(rd);
    rng_state->gen[i].gen_states = NULL;
    rng_state->gen[i].kernel_params = NULL;
  }
}

/* Destroy generators and free memory */
void THCRandom_shutdown(THCState* state)
{
  THCRNGState* rng_state = THCState_getRngState(state);
  if (rng_state->gen == NULL) return;
  for (int i = 0; i < rng_state->num_devices; ++i)
  {
    destroyGenerator(state, &rng_state->gen[i]);
  }
  free(rng_state->gen);
  rng_state->gen = NULL;
}

/* Get the generator for the current device, but does not initialize the state */
static Generator* THCRandom_rawGenerator(THCState* state)
{
  THCRNGState* rng_state = THCState_getRngState(state);
  int device;
  THCudaCheck(cudaGetDevice(&device));
  if (device >= rng_state->num_devices) THError("Invalid device index.");
  return &rng_state->gen[device];
}

/* Get the generator for the current device and initializes it if necessary */
Generator* THCRandom_getGenerator(THCState* state)
{
  Generator* gen = THCRandom_rawGenerator(state);
  if (gen->initf == 0)
  {
    initializeGenerator(state, gen);
    createGeneratorState(gen, gen->initial_seed);
    gen->initf = 1;
  }
  return gen;
}

#if defined(__HIP_PLATFORM_HCC__)
hiprandStateMtgp32_t* THCRandom_generatorStates(struct THCState* state)
#else
struct curandStateMtgp32* THCRandom_generatorStates(struct THCState* state)
#endif
{
  return THCRandom_getGenerator(state)->gen_states;
}

/* Random seed */
uint64_t THCRandom_seed(THCState* state)
{
  std::random_device rd;
  uint64_t s = createSeed(rd);
  THCRandom_manualSeed(state, s);
  return s;
}

uint64_t THCRandom_seedAll(THCState* state)
{
  std::random_device rd;
  uint64_t s = createSeed(rd);
  THCRandom_manualSeedAll(state, s);
  return s;
}

/* Manually set the seed */
void THCRandom_manualSeed(THCState* state, uint64_t seed)
{
  Generator* gen = THCRandom_rawGenerator(state);
  gen->initial_seed = seed;
  if (gen->initf) {
    createGeneratorState(gen, seed);
  }
}

void THCRandom_manualSeedAll(THCState* state, uint64_t seed)
{
  THCRNGState* rng_state = THCState_getRngState(state);
  int currentDevice;
  THCudaCheck(cudaGetDevice(&currentDevice));
  for (int i = 0; i < rng_state->num_devices; ++i) {
    THCudaCheck(cudaSetDevice(i));
    THCRandom_manualSeed(state, seed);
  }
  THCudaCheck(cudaSetDevice(currentDevice));
}

/* Get the initial seed */
uint64_t THCRandom_initialSeed(THCState* state)
{
  return THCRandom_getGenerator(state)->initial_seed;
}
