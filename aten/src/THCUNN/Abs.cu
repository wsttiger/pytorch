#include "THCUNN.h"
#include "THCHalf.h"
#include "THCHalfAutoNumerics.cuh"
#include <THC/THCApply.cuh>

template <typename T>
struct absupdateOutput_functor
{
  __device__ void operator()(T* output, const T* input) const
  {
#ifdef __HIP_PLATFORM_HCC__
    *output = fabsf(*input);
#else
    *output = abs(*input);
#endif
  }
};

template <typename T>
struct absupdateGradInput_functor
{
#ifdef __HIP_PLATFORM_HCC__
  __host__ __device__
  absupdateGradInput_functor() = default;

  __host__ __device__
  ~absupdateGradInput_functor() {}
#endif

  __device__ void operator()(T* gradInput, const T* input, const T* gradOutput) const
  {
    *gradInput = *input < 0 ? - *gradOutput : *gradOutput;
  }
};

#include "generic/Abs.cu"
#include "THCGenerateFloatTypes.h"
