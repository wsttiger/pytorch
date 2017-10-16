#ifndef THC_GENERIC_FILE
#define THC_GENERIC_FILE "generic/VolumetricFullConvolution.cu"
#else

void THNN_(VolumetricFullConvolution_updateOutput)(
       THCState *state,
       THCTensor  *input,
       THCTensor  *output,
       THCTensor  *weight,
       THCTensor  *bias,
       THCTensor  *finput,
       THCTensor  *fgradInput,
       int dT, int dW, int dH,
       int padT, int padW, int padH,
       int adjT, int adjW, int adjH)
{
#if !defined(__HIP_PLATFORM_HCC__)
  THNN_(VolumetricFullDilatedConvolution_updateOutput)(
       state, input, output, weight, bias, finput, fgradInput,
       dT, dW, dH, padT, padW, padH, 1, 1, 1, adjT, adjW, adjH);
#endif
}

void THNN_(VolumetricFullConvolution_updateGradInput)(
       THCState *state,
       THCTensor  *input,
       THCTensor  *gradOutput,
       THCTensor  *gradInput,
       THCTensor  *weight,
       THCTensor  *finput,
       THCTensor  *fgradInput,
       int dT, int dW, int dH,
       int padT, int padW, int padH,
       int adjT, int adjW, int adjH)
{
#if !defined(__HIP_PLATFORM_HCC__)
  THNN_(VolumetricFullDilatedConvolution_updateGradInput)(
       state, input, gradOutput, gradInput, weight, finput, fgradInput,
       dT, dW, dH, padT, padW, padH, 1, 1, 1, adjT, adjW, adjH);
#endif
}


void THNN_(VolumetricFullConvolution_accGradParameters)(
           THCState *state,
           THCTensor  *input,
           THCTensor  *gradOutput,
           THCTensor  *gradWeight,
           THCTensor  *gradBias,
           THCTensor  *finput,
           THCTensor  *fgradInput,
           int dT, int dW, int dH,
           int padT, int padW, int padH,
           int adjT, int adjW, int adjH,
           accreal scale_)
{
#if !defined(__HIP_PLATFORM_HCC__)
  THNN_(VolumetricFullDilatedConvolution_accGradParameters)(
       state, input, gradOutput, gradWeight, gradBias, finput, fgradInput,
       dT, dW, dH, padT, padW, padH, 1, 1, 1, adjT, adjW, adjH, scale_);
#endif
}

#endif
