#
# Vadd
#
# Element wise addition of two vectors (c = a + b)
# Asks the user to select a device at runtime
#
# History: C version written by Tim Mattson, December 2009
#          C version Updated by Tom Deakin and Simon McIntosh-Smith, October 2012
#          Ported to Python by Tom Deakin, July 2013
#          Ported to Julia by Jake Bolewski, Nov 2013

import OpenCL
const cl = OpenCL

include("deviceinfo.jl")

# tolerance used in floating point comparisons
TOL = 1e-3

# length of vectors a, b, c
LENGTH = 1024

# Kernel: vadd
#
# To compute the elementwise sum c = a + b
#
# Input: a and b float vectors of length count
# Output c float vector of length count holding the sum a + b

kernelsource = "
__kernel void vadd(
    __global float* a,
    __global float* b,
    __global float* c,
    const unsigned int count)
{
    unsigned int i = get_global_id(0);
    if (i < count)
        c[i] = a[i] + b[i];
}
"

# create a compute context

# this selects the fastest opencl device available
# and creates a context and queue for using the
# the selected device
device, ctx, queue = cl.create_compute_context()

output_device_info(device)

# create the compute program and build it
program = cl.Program(ctx, source=kernelsource) |> cl.build!

#create a and b vectors and fill with random float values 
h_a = rand(Float32, LENGTH)
h_b = rand(Float32, LENGTH)

# create the input (a,b,e,g) arrays in device memory and copy data from the host

# buffers can be passed memory flags: 
# {:r = readonly, :w = writeonly, :rw = read_write (default)}

# buffers can also be passed flags for allocation:
# {:use (use host buffer), :alloc (alloc pinned memory), :copy (default)}

# Create the input (a, b, e, g) arrays in device memory and copy data from host
d_a = cl.Buffer(Float32, ctx, (:r, :copy), hostbuf=h_a)
d_b = cl.Buffer(Float32, ctx, (:r, :copy), hostbuf=h_b)
# Create the output (c, d, f) array in device memory
d_c = cl.Buffer(Float32, ctx, :w, LENGTH)

# create the kernel
vadd = cl.Kernel(program, "vadd")

# execute the kernel over the entire range of 1d, input
# cl.call is blocking, it accepts a queue, the kernel, global / local work sizes,
# the the kernel's arguments. 

# here we call the kernel with work size set to the number of elements and a local
# work size of nothing. This enables the opencl runtime to optimize the local size
# for simple kernels
cl.call(queue, vadd, size(h_a), nothing, d_a, d_b, d_c, uint32(LENGTH))

# read back the results from the compute device
h_c = cl.read(queue, d_c)

# test the results
correct = 0
for i in 1:LENGTH
    tmp = h_a[i] + h_b[i]
    tmp -= h_c[i]
    if tmp^2 < TOL^2 
        correct += 1
    else
        println("tmp $tmp h_a $(h_a[i]) h_b $(h_b[i]) h_c $(h_c[i])")
    end
end

# summarize results
println("3 vector adds to find F=A+B+E+G: $correct out of $LENGTH results were correct")
