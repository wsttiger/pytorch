#include "THCTensorMath.h"
#include "THCGeneral.h"
#include "THCHalf.h"
#include "THCTensorCopy.h"
#include "THCApply.cuh"
#include "THCNumerics.cuh"
#include "THCTensorMathCompareT.cuh"

template <typename T>
struct TensorAddConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
#endif
  TensorAddConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in + val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v += val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  ~TensorAddConstantOp() {}
#endif

  const T val;
};

#ifdef CUDA_HALF_TENSOR
template <>
struct TensorAddConstantOp<half> {
#if defined (UDA_HALF_INSTRUCTIONS)|| defined (__HIP_PLATFORM_HCC__)
  #if defined(__HIP_PLATFORM_HCC__)
    __host__ __device__
    explicit
  #endif
  TensorAddConstantOp(half v) : val(v) {}
#else
  TensorAddConstantOp(half v) : fval(THC_half2float(v)) {}
#endif

  __device__ __forceinline__ void operator()(half* out, half* in) {
#if defined (__HIP_PLATFORM_HCC__)
    *out = *in + val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *out = __hadd(*in, val);
#else
    float fin = __half2float(*in);
    float fout = fin + fval;
    *out = __float2half(fout);
#endif
  }

  __device__ __forceinline__ void operator()(half* v) {
#if defined (__HIP_PLATFORM_HCC__)
    *v += val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *v = __hadd(*v, val);
#else
    float fv = __half2float(*v);
    fv += fval;
    *v = __float2half(fv);
#endif
  }

#if defined(CUDA_HALF_INSTRUCTIONS) || defined(__HIP_PLATFORM_HCC__)
  const half val;
#else
  const float fval;
#endif
};
#endif // CUDA_HALF_TENSOR


template <typename T>
struct TensorSubConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
#endif
  TensorSubConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in - val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v -= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  ~TensorSubConstantOp() {}
#endif

  const T val;
};


#ifdef CUDA_HALF_TENSOR
template <>
struct TensorSubConstantOp<half> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
  TensorSubConstantOp(half v) : val{v} {}
#elif defined(CUDA_HALF_INSTRUCTIONS)
  TensorSubConstantOp(half v): val(THC_float2half(-(THC_half2float(v)))) {}
#else
  TensorSubConstantOp(half v): fval(-(THC_half2float(v))) {}
#endif

  __device__ __forceinline__ void operator()(half* out, half* in) {
#if defined(__HIP_PLATFORM_HCC__)
  *out = *in + val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *out = __hadd(*in, val);
#else
    float fin = __half2float(*in);
    float fout = fin + fval;
    *out = __float2half(fout);
#endif
  }

  __device__ __forceinline__ void operator()(half* v) {
#if defined(__HIP_PLATFORM_HCC__)
    *v += val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *v = __hadd(*v, val);
#else
    float fv = __half2float(*v);
    fv += fval;
    *v = __float2half(fv);
#endif
  }

#if defined(CUDA_HALF_INSTRUCTIONS) || defined(__HIP_PLATFORM_HCC__)
  const half val;
#else
  const float fval;
#endif
};
#endif // CUDA_HALF_TENSOR


template <typename T>
struct TensorMulConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
#endif
  TensorMulConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in * val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v *= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  ~TensorMulConstantOp() {}
#endif
  const T val;
};

#ifdef CUDA_HALF_TENSOR
template <>
struct TensorMulConstantOp<half> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
  TensorMulConstantOp(half v) : val(v) {}
#elif defined(CUDA_HALF_INSTRUCTIONS)
  TensorMulConstantOp(half v) : val(v) {}
#else
  TensorMulConstantOp(half v) : fval(THC_half2float(v)) {}
#endif

  __device__ __forceinline__ void operator()(half* out, half* in) {
#if defined(__HIP_PLATFORM_HCC__)
    *out = *in * val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *out = __hmul(*in, val);
#else
    float fin = __half2float(*in);
    float fout = fin * fval;
    *out = __float2half(fout);
#endif
  }

  __device__ __forceinline__ void operator()(half* v) {
#if defined(__HIP_PLATFORM_HCC__)
    *v = *v * val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *v = __hmul(*v, val);
#else
    float fv = __half2float(*v);
    fv *= fval;
    *v = __float2half(fv);
#endif
  }

#if defined(CUDA_HALF_INSTRUCTIONS) || defined(__HIP_PLATFORM_HCC__)
  const half val;
#else
  const float fval;
#endif
};
#endif // CUDA_HALF_TENSOR

template <typename T>
struct TensorDivConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
#endif
  TensorDivConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in / val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v /= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  ~TensorDivConstantOp() {}
#endif

  const T val;
};

#if !defined(__HIP_PLATFORM_HCC__)
template <>
struct TensorDivConstantOp<float> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
#endif
  TensorDivConstantOp(float v) : val(1.f / v) {}
  __device__ __forceinline__ void operator()(float* out, float* in) {
    *out = *in * val;
  }

  __device__ __forceinline__ void operator()(float* v) {
    *v *= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  ~TensorDivConstantOp() {}
#endif

  const float val;
};

template <>
struct TensorDivConstantOp<double> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
#endif
  TensorDivConstantOp(double v) : val(1. / v) {}
  __device__ __forceinline__ void operator()(double* out, double* in) {
    *out = *in * val;
  }

  __device__ __forceinline__ void operator()(double* v) {
    *v *= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  ~TensorDivConstantOp() {}
#endif

  const double val;
};
#endif

#ifdef CUDA_HALF_TENSOR
template <>
struct TensorDivConstantOp<half> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  explicit
  TensorDivConstantOp(half v) : val(ScalarInv<half>::to(v)) {}
#elif defined(CUDA_HALF_INSTRUCTIONS)
  TensorDivConstantOp(half v) : val(ScalarInv<half>::to(v)) {}
#else
  TensorDivConstantOp(half v) : fval(1.f / THC_half2float(v)) {}
#endif
  __device__ __forceinline__ void operator()(half* out, half* in) {
#if defined(__HIP_PLATFORM_HCC__)
    *out = *in * val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *out = __hmul(*in, val);
#else
    float fin = __half2float(*in);
    float fout = fin * fval;
    *out = __float2half(fout);
#endif
  }

  __device__ __forceinline__ void operator()(half* v) {
#if defined(__HIP_PLATFORM_HCC__)
    *v = *v * val;
#elif defined(CUDA_HALF_INSTRUCTIONS)
    *v = __hmul(*v, val);
#else
    float fv = __half2float(*v);
    fv *= fval;
    *v = __float2half(fv);
#endif
  }

#if defined(CUDA_HALF_INSTRUCTIONS) || defined(__HIP_PLATFORM_HCC__)
  const half val;
#else
  const float fval;
#endif
};
#endif // CUDA_HALF_TENSOR

template <typename T>
struct TensorRemainderOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorRemainderOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in % val;
    if ((*out * val) < 0){
      *out += val;
    }
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v = *v % val;
    if ((*v * val) < 0){
      *v += val;
    }
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  ~TensorRemainderOp() {}  
#endif

  const T val;
};

template <>
struct TensorRemainderOp<float> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorRemainderOp(float v) : val(v) {}
  __device__ __forceinline__ void operator()(float* out, float* in) {
    *out = *in - val * floorf(*in / val);
  }

  __device__ __forceinline__ void operator()(float* v) {
    *v = *v - val * floorf(*v / val);
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__ ~TensorRemainderOp() {};
#endif

  const float val;
};

template <>
struct TensorRemainderOp<double> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorRemainderOp(double v) : val(v) {}
  __device__ __forceinline__ void operator()(double* out, double* in) {
    *out = *in - val * floor(*in / val);
  }

  __device__ __forceinline__ void operator()(double* v) {
    *v = *v - val * floor(*v / val);
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__ ~TensorRemainderOp() {};
#endif

  const double val;
};

#ifdef CUDA_HALF_TENSOR
template <>
struct TensorRemainderOp<half> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  TensorRemainderOp(half v) : val(v) {}
#elif defined(CUDA_HALF_INSTRUCTIONS)
#else
  TensorRemainderOp(half v): fval(THC_half2float(v)) {}
#endif

  __device__ __forceinline__ void operator()(half* out, half* in) {
#if defined(CUDA_HALF_INSTRUCTIONS) 
    *out = __hsub(*in,  __hmul(val, hfloor(__hdiv(*in,  val))));
#elif defined(__HIP_PLATFORM_HCC__)
    *out = __hsub(*in,  __hmul(val, hfloor(hdiv(*in,  val))));
#else
    float fin = __half2float(*in);
    float fout = fin - fval * floorf(fin / fval);
    *out = __float2half(fout);
#endif
  }

  __device__ __forceinline__ void operator()(half* v) {
#if defined(CUDA_HALF_INSTRUCTIONS)
    *v = __hsub(*v, __hmul(val, hfloor(__hdiv(*v, val))));
#elif defined(__HIP_PLATFORM_HCC__)
    *v = __hsub(*v, __hmul(val, hfloor(hdiv(*v, val))));
#else
    float fv = __half2float(*v);
    fv = fv - fval * floorf(fv / fval);
    *v = __float2half(fv);
#endif
  }

#if defined(CUDA_HALF_INSTRUCTIONS) || defined(__HIP_PLATFORM_HCC__)
  const half val;
#else
  const float fval;
#endif
};
#endif // CUDA_HALF_TENSOR

template <typename T>
struct TensorFmodOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorFmodOp(T v) : val((float)v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = (T) fmodf((float) *in, val);
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v = (T) fmodf((float) *v, val);
  }

  const float val;
};

template <>
struct TensorFmodOp<double> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorFmodOp(double v) : val(v) {}
  __device__ __forceinline__ void operator()(double* out, double* in) {
    *out = fmod(*in, val);
  }

  __device__ __forceinline__ void operator()(double* v) {
    *v = fmod(*v, val);
  }

  const double val;
};

#ifdef CUDA_HALF_TENSOR
template <>
struct TensorFmodOp<half> {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
  TensorFmodOp(half v): fval(v) {}
#else
  TensorFmodOp(half v): fval(THC_half2float(v)) {}
#endif

  __device__ __forceinline__ void operator()(half* out, half* in) {
    *out = __float2half(fmodf(__half2float(*in), fval));
  }

  __device__ __forceinline__ void operator()(half* v) {
    *v = __float2half(fmodf(__half2float(*v), fval));
  }

  const float fval;
};
#endif // CUDA_HALF_TENSOR

template <typename T, int Upper>
struct TensorTriOp {
  TensorTriOp(T *start_, int64_t stride0_, int64_t stride1_, int64_t k_)
    : start(start_), stride0(stride0_), stride1(stride1_), k(k_) {}

  __device__ __forceinline__ int mask(T *in) {
    ptrdiff_t n = in - start;
    int64_t row, col;
    if (stride0 > stride1)
    {
      row = (int64_t) (n / stride0);
      col = (int64_t) ((n % stride0) / stride1);
    }
    else
    {
      row = (int64_t) ((n % stride1) / stride0);
      col = (int64_t) (n / stride1);
    }

    return Upper ? (col - row >= k) : (col - row <= k);
  }

  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = mask(in) ? *in : ScalarConvert<int, T>::to(0);
  }

  __device__ __forceinline__ void operator()(T* v) {
    if (!mask(v))
      *v = ScalarConvert<int, T>::to(0);
  }

  const T *start;
  const int64_t stride0, stride1, k;
};

template <typename T>
struct TensorLShiftConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorLShiftConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in << val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v <<= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__ ~TensorLShiftConstantOp() {};
#endif

  const T val;
};

template <typename T>
struct TensorRShiftConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorRShiftConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in >> val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v >>= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__ ~TensorRShiftConstantOp() {};
#endif
  const T val;
};

template <typename T>
struct TensorBitAndConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorBitAndConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in & val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v &= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__ ~TensorBitAndConstantOp() {}
#endif
  const T val;
};

template <typename T>
struct TensorBitOrConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorBitOrConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in | val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v |= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__ ~TensorBitOrConstantOp() {}
#endif

  const T val;
};

template <typename T>
struct TensorBitXorConstantOp {
#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__
#endif
  TensorBitXorConstantOp(T v) : val(v) {}
  __device__ __forceinline__ void operator()(T* out, T* in) {
    *out = *in ^ val;
  }

  __device__ __forceinline__ void operator()(T* v) {
    *v ^= val;
  }

#if defined(__HIP_PLATFORM_HCC__)
  __host__ __device__ ~TensorBitXorConstantOp() {}
#endif

  const T val;
};

#include "generic/THCTensorMathPairwise.cu"
#include "THCGenerateAllTypes.h"
