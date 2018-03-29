#!/usr/bin/python
from cuda_to_hip_mappings import CUDA_TO_HIP_MAPPINGS
import os
import constants
from functools import reduce
import shutil
import sys
import re


def updt_progress(total, progress):
    """
    Displays or updates a console progress bar.
    """
    barLength, status = 20, ""
    progress = float(progress) / float(total)
    if progress >= 1.:
        progress, status = 1, "\r\n"
    block = int(round(barLength * progress))
    text = "\r[{}] {:.0f}% {}".format(
        "#" * block + "-" * (barLength - block), round(progress * 100, 0),
        status)
    sys.stdout.write(text)
    sys.stdout.flush()


def walk_over_directory(path, func, extensions = [".cu", ".cuh", ".c", ".cpp", ".h"]):
    """ Walks over the entire directory and applies the function with signature on each file encountered.

    func (path as string): void
    """
    cur = 0
    total = sum([sum([reduce(lambda result, ext: filename.endswith(ext) or result, extensions, False) for filename in files]) for r, d, files in os.walk(path)])
    stats = {"unsupported_calls": [], "kernel_launches": []}

    for (dirpath, _dirnames, filenames) in os.walk(path):
        for filename in filenames:
            if reduce(
                lambda result, ext: filename.endswith(ext) or result,
                    extensions, False):
                filepath = os.sep.join([dirpath, filename])

                # Execute the preprocessor on the specified file.
                func(filepath, stats)

                # Update the progress
                print (os.path.join(dirpath, filename))
                updt_progress(total, cur)

                cur += 1

    print("Done")
    compute_stats(stats)


def compute_stats(stats):
    unsupported_calls = set(cuda_call for (cuda_call, _filepath) in stats["unsupported_calls"])

    # Print the number of unsupported calls
    print("Total number of unsupported CUDA function calls: %d" % (len(unsupported_calls)))

    # Print the list of unsupported calls
    print(", ".join(unsupported_calls))

    # Print the number of kernel launches
    print("\nTotal number of replaced kernel launches: %d" % (len(stats["kernel_launches"])))
    # print("\n".join(stats["kernel_launches"]))

    #for unsupported in stats["unsupported_calls"]:
    #    print("Detected an unsupported function %s in file %s" % unsupported)




def processKernelLaunches(string, stats):
    """ Replace the CUDA style Kernel launches with the HIP style kernel launches."""
    def create_hip_kernel(cuda_kernel):
        kernel_name = cuda_kernel.group(1)
        kernel_template = cuda_kernel.group(2)
        kernel_launch_params = cuda_kernel.group(3)
        kernel_arguments = cuda_kernel.group(4)

        # Clean kernel arguments
        kernel_arguments = kernel_arguments.replace("\n", "").replace("\\", "")
        kernel_arguments = re.sub(' +', ' ', kernel_arguments)
        kernel_arguments = kernel_arguments[1:-1]

        # Convert kernel launch params to list
        kernel_launch_params = kernel_launch_params.replace("<<<", "").replace(">>>", "").split(",")
        kernel_launch_params[0] = "dim3(%s)" % kernel_launch_params[0].strip()
        kernel_launch_params[1] = "dim3(%s)" % kernel_launch_params[1].strip()

        # Fill empty kernel params with 0s (sharedSize, stream)
        kernel_launch_params[len(kernel_launch_params):4] = ["0"] * (4 - len(kernel_launch_params))

        # Create the Hip Kernel Launch
        hip_kernel_launch = "".join("hipLaunchKernelGGL((%s%s), %s, %s)" % (kernel_name, kernel_template, ", ".join(kernel_launch_params), kernel_arguments))

        # Clean up syntax
        hip_kernel_launch = re.sub(' +', ' ', hip_kernel_launch)

        # Update stats
        stats["kernel_launches"].append(hip_kernel_launch)
        return hip_kernel_launch

    # Replace CUDA with HIP Kernel launch
    output_string = re.sub(r'([a-zA-Z_0-9]+)(<.*>)?[\\| |\n]*(<<<.*>>>)(\([\\| |\n|a-zA-Z|,|.|[|\]|_|<|>|(|)|0-9]*\))', create_hip_kernel, string)

    return output_string


def preprocessor(filepath, stats, show_replacements=False, show_unsupported=False):
    """ Executes the CUDA -> HIP conversion on the specified file. """
    with open(filepath, "r+") as fileobj:
        output_source = fileobj.read()

        # Perform type, method, constant replacements
        for mapping in CUDA_TO_HIP_MAPPINGS:
            for key, value in mapping.iteritems():
                # Extract relevant info
                cuda_type = key
                hip_type = value[0]
                meta_data = value[1:]

                if output_source.find(cuda_type) > -1:
                    # Check if supported
                    if constants.HIP_UNSUPPORTED in meta_data:
                        if show_unsupported:
                            print("Detected an unsupported function %s in file %s" % (cuda_type, filepath))

                        stats["unsupported_calls"].append((cuda_type, filepath))

                    # Show replacements
                    if show_replacements:
                        print("Replaced %s with %s" % (cuda_type, hip_type))

                # Replace all occurances
                output_source = output_source.replace(cuda_type, hip_type)

        # Perform Kernel Launch Replacements
        output_source = processKernelLaunches(output_source, stats)

        # Replace WITH_CUDA -> WITH_ROCM
        output_source = output_source.replace("WITH_CUDA", "WITH_ROCM")

        # Overwrite file contents
        fileobj.seek(0)
        fileobj.write(output_source)
        fileobj.truncate()
        fileobj.flush()

        # Flush to disk
        os.fsync(fileobj)


def main():
    # Clone the folder
    pytorch_directory = os.path.dirname(os.getcwd())
    amd_pytorch_directory = os.path.join(os.path.dirname(pytorch_directory), "amd_pytorch_build")

    # Delete AMD PyTorch directory if it already exists.
    if os.path.exists(amd_pytorch_directory):
        shutil.rmtree(amd_pytorch_directory)
    shutil.copytree(pytorch_directory, amd_pytorch_directory)

    # Start Preprocessor
    walk_over_directory(amd_pytorch_directory, preprocessor)


if __name__ == '__main__':
    main()
