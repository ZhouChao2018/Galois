/*
 * This file belongs to the Galois project, a C++ library for exploiting parallelism.
 * The code is being released under the terms of the 3-Clause BSD License (a
 * copy is located in LICENSE.txt at the top-level directory).
 *
 * Copyright (C) 2018, The University of Texas at Austin. All rights reserved.
 * UNIVERSITY EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES CONCERNING THIS
 * SOFTWARE AND DOCUMENTATION, INCLUDING ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR ANY PARTICULAR PURPOSE, NON-INFRINGEMENT AND WARRANTIES OF
 * PERFORMANCE, AND ANY WARRANTY THAT MIGHT OTHERWISE ARISE FROM COURSE OF
 * DEALING OR USAGE OF TRADE.  NO WARRANTY IS EITHER EXPRESS OR IMPLIED WITH
 * RESPECT TO THE USE OF THE SOFTWARE OR DOCUMENTATION. Under no circumstances
 * shall University be liable for incidental, special, indirect, direct or
 * consequential damages or loss of profits, interruption of business, or
 * related expenses which may arise from use of Software or Documentation,
 * including but not limited to those resulting from defects in Software and/or
 * Documentation, or loss or inaccuracy of data of any kind.
 */

/*  -*- mode: c++ -*-  */
#include "gg.h"
#include "ggcuda.h"
#include <cub/cub.cuh>
#include "cub/util_allocator.cuh"

void kernel_sizing(CSRGraph &, dim3 &, dim3 &);
#define TB_SIZE 256
const char *GGC_OPTIONS = "coop_conv=False $ outline_iterate_gb=False $ backoff_blocking_factor=4 $ parcomb=True $ np_schedulers=set(['fg', 'tb', 'wp']) $ cc_disable=set([]) $ hacks=set([]) $ np_factor=8 $ instrument=set([]) $ unroll=[] $ instrument_mode=None $ read_props=None $ outline_iterate=True $ ignore_nested_errors=False $ np=True $ write_props=None $ quiet_cgen=True $ retry_backoff=True $ cuda.graph_type=basic $ cuda.use_worklist_slots=True $ cuda.worklist_type=basic";
#include "kernels/reduce.cuh"
#include "bfs_push_lb_cuda.cuh"
static const int __tb_FirstItr_BFS = TB_SIZE;
static const int __tb_BFS = TB_SIZE;
__global__ void InitializeGraph(CSRGraph graph, unsigned int __begin, unsigned int __end, const uint32_t  local_infinity, unsigned long long local_src_node, uint32_t * p_dist_current, uint32_t * p_dist_old)
{
  unsigned tid = TID_1D;
  unsigned nthreads = TOTAL_THREADS_1D;

  const unsigned __kernel_tb_size = TB_SIZE;
  index_type src_end;
  // FP: "1 -> 2;
  src_end = __end;
  for (index_type src = __begin + tid; src < src_end; src += nthreads)
  {
    bool pop  = src < __end;
    if (pop)
    {
      p_dist_current[src] = (graph.node_data[src] == local_src_node) ? 0 : local_infinity;
      p_dist_old[src] = (graph.node_data[src] == local_src_node) ? 0 : local_infinity;
    }
  }
  // FP: "8 -> 9;
}
__global__ void FirstItr_BFS(CSRGraph graph, unsigned int __begin, unsigned int __end, uint32_t * p_dist_current, uint32_t * p_dist_old, DynamicBitset& bitset_dist_current)
{
  unsigned tid = TID_1D;
  unsigned nthreads = TOTAL_THREADS_1D;

  const unsigned __kernel_tb_size = __tb_FirstItr_BFS;
  index_type src_end;
  index_type src_rup;
  // FP: "1 -> 2;
  const int _NP_CROSSOVER_WP = 32;
  const int _NP_CROSSOVER_TB = __kernel_tb_size;
  // FP: "2 -> 3;
  const int BLKSIZE = __kernel_tb_size;
  const int ITSIZE = BLKSIZE * 8;
  // FP: "3 -> 4;

  typedef cub::BlockScan<multiple_sum<2, index_type>, BLKSIZE> BlockScan;
  typedef union np_shared<BlockScan::TempStorage, index_type, struct tb_np, struct warp_np<__kernel_tb_size/32>, struct fg_np<ITSIZE> > npsTy;

  // FP: "4 -> 5;
  __shared__ npsTy nps ;
  // FP: "5 -> 6;
  src_end = __end;
  src_rup = ((__begin) + roundup(((__end) - (__begin)), (blockDim.x)));
  for (index_type src = __begin + tid; src < src_rup; src += nthreads)
  {
    multiple_sum<2, index_type> _np_mps;
    multiple_sum<2, index_type> _np_mps_total;
    // FP: "6 -> 7;
    bool pop  = (src < __end) && ((graph).getOutDegree(src) < nthreads);
    // FP: "7 -> 8;
    if (pop)
    {
      p_dist_old[src] = p_dist_current[src];
    }
    // FP: "10 -> 11;
    // FP: "13 -> 14;
    struct NPInspector1 _np = {0,0,0,0,0,0};
    // FP: "14 -> 15;
    __shared__ struct { index_type src; } _np_closure [TB_SIZE];
    // FP: "15 -> 16;
    _np_closure[threadIdx.x].src = src;
    // FP: "16 -> 17;
    if (pop)
    {
      _np.size = (graph).getOutDegree(src);
      _np.start = (graph).getFirstEdge(src);
    }
    // FP: "19 -> 20;
    // FP: "20 -> 21;
    _np_mps.el[0] = _np.size >= _NP_CROSSOVER_WP ? _np.size : 0;
    _np_mps.el[1] = _np.size < _NP_CROSSOVER_WP ? _np.size : 0;
    // FP: "21 -> 22;
    BlockScan(nps.temp_storage).ExclusiveSum(_np_mps, _np_mps, _np_mps_total);
    // FP: "22 -> 23;
    if (threadIdx.x == 0)
    {
      nps.tb.owner = MAX_TB_SIZE + 1;
    }
    // FP: "25 -> 26;
    __syncthreads();
    // FP: "26 -> 27;
    while (true)
    {
      // FP: "27 -> 28;
      if (_np.size >= _NP_CROSSOVER_TB)
      {
        nps.tb.owner = threadIdx.x;
      }
      // FP: "30 -> 31;
      __syncthreads();
      // FP: "31 -> 32;
      if (nps.tb.owner == MAX_TB_SIZE + 1)
      {
        // FP: "32 -> 33;
        __syncthreads();
        // FP: "33 -> 34;
        break;
      }
      // FP: "35 -> 36;
      if (nps.tb.owner == threadIdx.x)
      {
        nps.tb.start = _np.start;
        nps.tb.size = _np.size;
        nps.tb.src = threadIdx.x;
        _np.start = 0;
        _np.size = 0;
      }
      // FP: "38 -> 39;
      __syncthreads();
      // FP: "39 -> 40;
      int ns = nps.tb.start;
      int ne = nps.tb.size;
      // FP: "40 -> 41;
      if (nps.tb.src == threadIdx.x)
      {
        nps.tb.owner = MAX_TB_SIZE + 1;
      }
      // FP: "43 -> 44;
      assert(nps.tb.src < __kernel_tb_size);
      src = _np_closure[nps.tb.src].src;
      // FP: "44 -> 45;
      for (int _np_j = threadIdx.x; _np_j < ne; _np_j += BLKSIZE)
      {
        index_type jj;
        jj = ns +_np_j;
        {
          index_type dst;
          uint32_t new_dist;
          uint32_t old_dist;
          dst = graph.getAbsDestination(jj);
          new_dist = 1 + p_dist_current[src];
          old_dist = atomicTestMin(&p_dist_current[dst], new_dist);
          if (old_dist > new_dist)
          {
            bitset_dist_current.set(dst);
          }
        }
      }
      // FP: "57 -> 58;
      __syncthreads();
    }
    // FP: "59 -> 60;

    // FP: "60 -> 61;
    {
      const int warpid = threadIdx.x / 32;
      // FP: "61 -> 62;
      const int _np_laneid = cub::LaneId();
      // FP: "62 -> 63;
      while (__any(_np.size >= _NP_CROSSOVER_WP && _np.size < _NP_CROSSOVER_TB))
      {
        if (_np.size >= _NP_CROSSOVER_WP && _np.size < _NP_CROSSOVER_TB)
        {
          nps.warp.owner[warpid] = _np_laneid;
        }
        if (nps.warp.owner[warpid] == _np_laneid)
        {
          nps.warp.start[warpid] = _np.start;
          nps.warp.size[warpid] = _np.size;
          nps.warp.src[warpid] = threadIdx.x;
          _np.start = 0;
          _np.size = 0;
        }
        index_type _np_w_start = nps.warp.start[warpid];
        index_type _np_w_size = nps.warp.size[warpid];
        assert(nps.warp.src[warpid] < __kernel_tb_size);
        src = _np_closure[nps.warp.src[warpid]].src;
        for (int _np_ii = _np_laneid; _np_ii < _np_w_size; _np_ii += 32)
        {
          index_type jj;
          jj = _np_w_start +_np_ii;
          {
            index_type dst;
            uint32_t new_dist;
            uint32_t old_dist;
            dst = graph.getAbsDestination(jj);
            new_dist = 1 + p_dist_current[src];
            old_dist = atomicTestMin(&p_dist_current[dst], new_dist);
            if (old_dist > new_dist)
            {
              bitset_dist_current.set(dst);
            }
          }
        }
      }
      // FP: "85 -> 86;
      __syncthreads();
      // FP: "86 -> 87;
    }

    // FP: "87 -> 88;
    __syncthreads();
    // FP: "88 -> 89;
    _np.total = _np_mps_total.el[1];
    _np.offset = _np_mps.el[1];
    // FP: "89 -> 90;
    while (_np.work())
    {
      // FP: "90 -> 91;
      int _np_i =0;
      // FP: "91 -> 92;
      _np.inspect2(nps.fg.itvalue, nps.fg.src, ITSIZE, threadIdx.x);
      // FP: "92 -> 93;
      __syncthreads();
      // FP: "93 -> 94;

      // FP: "94 -> 95;
      for (_np_i = threadIdx.x; _np_i < ITSIZE && _np.valid(_np_i); _np_i += BLKSIZE)
      {
        index_type jj;
        assert(nps.fg.src[_np_i] < __kernel_tb_size);
        src = _np_closure[nps.fg.src[_np_i]].src;
        jj= nps.fg.itvalue[_np_i];
        {
          index_type dst;
          uint32_t new_dist;
          uint32_t old_dist;
          dst = graph.getAbsDestination(jj);
          new_dist = 1 + p_dist_current[src];
          old_dist = atomicTestMin(&p_dist_current[dst], new_dist);
          if (old_dist > new_dist)
          {
            bitset_dist_current.set(dst);
          }
        }
      }
      // FP: "108 -> 109;
      _np.execute_round_done(ITSIZE);
      // FP: "109 -> 110;
      __syncthreads();
    }
    // FP: "111 -> 112;
    assert(threadIdx.x < __kernel_tb_size);
    src = _np_closure[threadIdx.x].src;
  }
  // FP: "113 -> 114;
}
__global__ void Inspect_FirstItr_BFS(CSRGraph graph, unsigned int __begin, unsigned int __end, uint32_t * p_dist_current, uint32_t * p_dist_old,
		PipeContextT<Worklist2> thread_work_wl, PipeContextT<Worklist2> thread_src_wl)
{
	  unsigned tid = TID_1D;
	  unsigned nthreads = TOTAL_THREADS_1D;

	  index_type src_rup;
	  // FP: "5 -> 6;
	  src_rup = ((__begin) + roundup(((__end) - (__begin)), (blockDim.x)));
	  for (index_type src = __begin + tid; src < src_rup; src += nthreads)
	  {
		multiple_sum<2, index_type> _np_mps;
		multiple_sum<2, index_type> _np_mps_total;
		// FP: "6 -> 7;
		bool pop  = (src < __end) && ((graph).getOutDegree(src) >= nthreads);
		// FP: "7 -> 8;
		if (pop)
		{
		  p_dist_old[src] = p_dist_current[src];
		  thread_work_wl.in_wl().push((graph).getOutDegree(src));
		  thread_src_wl.in_wl().push(src);
		}
	  }
}
__global__ void Inspect_BFS(CSRGraph graph, unsigned int __begin, unsigned int __end, const uint32_t local_priority, uint32_t * p_dist_current, uint32_t * p_dist_old,
		DynamicBitset& bitset_dist_current, HGAccumulator<unsigned int> DGAccumulator_accum, HGAccumulator<unsigned int> work_items,
		PipeContextT<Worklist2> thread_work_wl, PipeContextT<Worklist2> thread_src_wl)
{
	  unsigned tid = TID_1D;
	  unsigned nthreads = TOTAL_THREADS_1D;

	  __shared__ cub::BlockReduce<unsigned int, TB_SIZE>::TempStorage DGAccumulator_accum_ts;
	  __shared__ cub::BlockReduce<unsigned int, TB_SIZE>::TempStorage work_items_ts;
	  index_type src_rup;
	  // FP: "1 -> 2;
	  // FP: "2 -> 3;
	  DGAccumulator_accum.thread_entry();
	  work_items.thread_entry();
	  // FP: "7 -> 8;
	  src_rup = ((__begin) + roundup(((__end) - (__begin)), (blockDim.x)));
	  for (index_type src = __begin + tid; src < src_rup; src += nthreads)
	  {
	    multiple_sum<2, index_type> _np_mps;
	    multiple_sum<2, index_type> _np_mps_total;
	    // FP: "8 -> 9;
	    bool pop  = (src < __end) && ((graph).getOutDegree(src) >= nthreads);
	    // FP: "9 -> 10;
	    if (pop)
	    {
	      if (p_dist_old[src] > p_dist_current[src])
	      {
	        DGAccumulator_accum.reduce( 1);
	        if (local_priority > p_dist_current[src])
	        {
	          p_dist_old[src] = p_dist_current[src];
	          work_items.reduce( 1);
	        }
	        else
	        {
	          pop = false;
	        }
	      }
	      else
	      {
	        pop = false;
	      }
	    }
	    if (pop)
	    {
	    	int index = thread_work_wl.in_wl().push_range(1);
	    	thread_src_wl.in_wl().push_range(1);
	    	thread_work_wl.in_wl().dwl[index] = (graph).getOutDegree(src);
	    	thread_src_wl.in_wl().dwl[index] = src;
	    }
	  }
	  DGAccumulator_accum.thread_exit<cub::BlockReduce<unsigned int, TB_SIZE> >(DGAccumulator_accum_ts);
	  work_items.thread_exit<cub::BlockReduce<unsigned int, TB_SIZE> >(work_items_ts);
}

void computePrefixSum(unsigned int __begin, unsigned int __end, struct CUDA_Context*  ctx) {

	cub::CachingDeviceAllocator g_allocator(true);  // Caching allocator for device memory
	// Determine temporary device storage requirements for inclusive prefix sum
	void     *d_temp_storage = NULL;
	size_t   temp_storage_bytes = 0;

	cub::DeviceScan::InclusiveSum(d_temp_storage, temp_storage_bytes, ctx->stats.thread_work_wl.in_wl().dwl,
			ctx->stats.thread_prefix_work_wl.gpu_wr_ptr(), ctx->stats.thread_work_wl.in_wl().nitems());
	// Allocate temporary storage for inclusive prefix sum
	CubDebugExit(g_allocator.DeviceAllocate(&d_temp_storage, temp_storage_bytes));
	// Run inclusive prefix sum
	cub::DeviceScan::InclusiveSum(d_temp_storage, temp_storage_bytes, ctx->stats.thread_work_wl.in_wl().dwl,
			ctx->stats.thread_prefix_work_wl.gpu_wr_ptr(), ctx->stats.thread_work_wl.in_wl().nitems());
}

__device__ unsigned compute_src_and_offset(unsigned first, unsigned last, unsigned index, uint32_t * thread_prefix_work_wl, unsigned num_items, unsigned int &offset,
	PipeContextT<Worklist2> thread_src_wl) {

	unsigned middle = (first + last)/2;

	if( index <= thread_prefix_work_wl[first] ) {
		if(first == 0 ) {
			offset =  index -1 ;
			return first;
		}
		else {
			offset =  index - thread_prefix_work_wl[first-1] -1 ;
			return first;
		}
	}
	while (first + 1 != last)
	{
	   middle = (first + last)/2;
	   if(index > thread_prefix_work_wl[middle])
	   {
		   first = middle ;
	   }
	   else {
		   last = middle;
	   }
	}
	offset =  index - thread_prefix_work_wl[first] - 1 ;
	return last;
}

__global__ void BFS_TB_LB(CSRGraph graph, unsigned int __begin, unsigned int __end, uint32_t * p_dist_current, uint32_t * p_dist_old,
		DynamicBitset& bitset_dist_current, uint32_t * thread_prefix_work_wl,  unsigned int num_items, PipeContextT<Worklist2> thread_src_wl)
{
	unsigned tid = TID_1D;
	unsigned nthreads = TOTAL_THREADS_1D;
	const unsigned __kernel_tb_size = __tb_BFS;
	__shared__ unsigned int total_work;
	__shared__ unsigned block_start_src_index, block_end_src_index;
	unsigned my_work, src;
	unsigned int offset, current_work;

	total_work = thread_prefix_work_wl[num_items-1];
	my_work =  ceilf((float)(total_work) /(float) nthreads);

	__syncthreads();

	 if(my_work != 0 ) {
		 current_work = tid;
		for (unsigned i = 0; i < my_work; i++)
		{
			unsigned block_start_work, block_end_work;
			if(threadIdx.x == 0) {
				if(current_work < total_work ) {
					block_start_work = current_work;

					block_end_work = current_work + blockDim.x - 1;
					if(block_end_work >= total_work) {
							block_end_work = total_work - 1;
					}
					block_start_src_index = compute_src_and_offset(0, num_items - 1, block_start_work+1, thread_prefix_work_wl, num_items, offset, thread_src_wl);
					block_end_src_index = compute_src_and_offset(0, num_items - 1, block_end_work+1, thread_prefix_work_wl, num_items, offset, thread_src_wl);
				}
			}
			__syncthreads();

			if(current_work < total_work) {

				unsigned src_index = compute_src_and_offset(block_start_src_index, block_end_src_index, current_work+1, thread_prefix_work_wl,
										num_items, offset, thread_src_wl);
				src = thread_src_wl.in_wl().dwl[src_index];

				index_type jj;
				jj = (graph).getFirstEdge(src) + offset;
				{
					  index_type dst;
					  uint32_t new_dist;
					  uint32_t old_dist;

					  dst = graph.getAbsDestination(jj);
					  new_dist = 1 + p_dist_current[src];
					  old_dist = atomicTestMin(&p_dist_current[dst], new_dist);
					  if (old_dist > new_dist)
					  {
						bitset_dist_current.set(dst);
					  }
				}
				current_work = current_work + nthreads;
			}
		}
	}
}
__global__ void BFS(CSRGraph graph, unsigned int __begin, unsigned int __end, const uint32_t local_priority, uint32_t * p_dist_current, uint32_t * p_dist_old, DynamicBitset& bitset_dist_current, HGAccumulator<unsigned int> DGAccumulator_accum, HGAccumulator<unsigned int> work_items)
{
  unsigned tid = TID_1D;
  unsigned nthreads = TOTAL_THREADS_1D;

  const unsigned __kernel_tb_size = __tb_BFS;
  __shared__ cub::BlockReduce<unsigned int, TB_SIZE>::TempStorage DGAccumulator_accum_ts;
  __shared__ cub::BlockReduce<unsigned int, TB_SIZE>::TempStorage work_items_ts;
  index_type src_end;
  index_type src_rup;
  // FP: "1 -> 2;
  const int _NP_CROSSOVER_WP = 32;
  const int _NP_CROSSOVER_TB = __kernel_tb_size;
  // FP: "2 -> 3;
  const int BLKSIZE = __kernel_tb_size;
  const int ITSIZE = BLKSIZE * 8;
  // FP: "3 -> 4;

  typedef cub::BlockScan<multiple_sum<2, index_type>, BLKSIZE> BlockScan;
  typedef union np_shared<BlockScan::TempStorage, index_type, struct tb_np, struct warp_np<__kernel_tb_size/32>, struct fg_np<ITSIZE> > npsTy;

  // FP: "4 -> 5;
  __shared__ npsTy nps ;
  // FP: "5 -> 6;
  // FP: "6 -> 7;
  DGAccumulator_accum.thread_entry();
  work_items.thread_entry();
  // FP: "7 -> 8;
  src_end = __end;
  src_rup = ((__begin) + roundup(((__end) - (__begin)), (blockDim.x)));
  for (index_type src = __begin + tid; src < src_rup; src += nthreads)
  {
    multiple_sum<2, index_type> _np_mps;
    multiple_sum<2, index_type> _np_mps_total;
    // FP: "8 -> 9;
    bool pop  = (src < __end) && ((graph).getOutDegree(src) < nthreads);
    // FP: "9 -> 10;
    if (pop)
    {
      if (p_dist_old[src] > p_dist_current[src])
      {
        DGAccumulator_accum.reduce( 1);
        if (local_priority > p_dist_current[src])
        {
          p_dist_old[src] = p_dist_current[src];
          work_items.reduce( 1);
        }
        else
        {
          pop = false;
        }
      }
      else
      {
        pop = false;
      }
    }
    // FP: "15 -> 16;
    // FP: "18 -> 19;
    struct NPInspector1 _np = {0,0,0,0,0,0};
    // FP: "19 -> 20;
    __shared__ struct { index_type src; } _np_closure [TB_SIZE];
    // FP: "20 -> 21;
    _np_closure[threadIdx.x].src = src;
    // FP: "21 -> 22;
    if (pop)
    {
      _np.size = (graph).getOutDegree(src);
      _np.start = (graph).getFirstEdge(src);
    }
    // FP: "24 -> 25;
    // FP: "25 -> 26;
    _np_mps.el[0] = _np.size >= _NP_CROSSOVER_WP ? _np.size : 0;
    _np_mps.el[1] = _np.size < _NP_CROSSOVER_WP ? _np.size : 0;
    // FP: "26 -> 27;
    BlockScan(nps.temp_storage).ExclusiveSum(_np_mps, _np_mps, _np_mps_total);
    // FP: "27 -> 28;
    if (threadIdx.x == 0)
    {
      nps.tb.owner = MAX_TB_SIZE + 1;
    }
    // FP: "30 -> 31;
    __syncthreads();
    // FP: "31 -> 32;
    while (true)
    {
      // FP: "32 -> 33;
      if (_np.size >= _NP_CROSSOVER_TB)
      {
        nps.tb.owner = threadIdx.x;
      }
      // FP: "35 -> 36;
      __syncthreads();
      // FP: "36 -> 37;
      if (nps.tb.owner == MAX_TB_SIZE + 1)
      {
        // FP: "37 -> 38;
        __syncthreads();
        // FP: "38 -> 39;
        break;
      }
      // FP: "40 -> 41;
      if (nps.tb.owner == threadIdx.x)
      {
        nps.tb.start = _np.start;
        nps.tb.size = _np.size;
        nps.tb.src = threadIdx.x;
        _np.start = 0;
        _np.size = 0;
      }
      // FP: "43 -> 44;
      __syncthreads();
      // FP: "44 -> 45;
      int ns = nps.tb.start;
      int ne = nps.tb.size;
      // FP: "45 -> 46;
      if (nps.tb.src == threadIdx.x)
      {
        nps.tb.owner = MAX_TB_SIZE + 1;
      }
      // FP: "48 -> 49;
      assert(nps.tb.src < __kernel_tb_size);
      src = _np_closure[nps.tb.src].src;
      // FP: "49 -> 50;
      for (int _np_j = threadIdx.x; _np_j < ne; _np_j += BLKSIZE)
      {
        index_type jj;
        jj = ns +_np_j;
        {
          index_type dst;
          uint32_t new_dist;
          uint32_t old_dist;
          dst = graph.getAbsDestination(jj);
          new_dist = 1 + p_dist_current[src];
          old_dist = atomicTestMin(&p_dist_current[dst], new_dist);
          if (old_dist > new_dist)
          {
            bitset_dist_current.set(dst);
          }
        }
      }
      // FP: "62 -> 63;
      __syncthreads();
    }
    // FP: "64 -> 65;

    // FP: "65 -> 66;
    {
      const int warpid = threadIdx.x / 32;
      // FP: "66 -> 67;
      const int _np_laneid = cub::LaneId();
      // FP: "67 -> 68;
      while (__any(_np.size >= _NP_CROSSOVER_WP && _np.size < _NP_CROSSOVER_TB))
      {
        if (_np.size >= _NP_CROSSOVER_WP && _np.size < _NP_CROSSOVER_TB)
        {
          nps.warp.owner[warpid] = _np_laneid;
        }
        if (nps.warp.owner[warpid] == _np_laneid)
        {
          nps.warp.start[warpid] = _np.start;
          nps.warp.size[warpid] = _np.size;
          nps.warp.src[warpid] = threadIdx.x;
          _np.start = 0;
          _np.size = 0;
        }
        index_type _np_w_start = nps.warp.start[warpid];
        index_type _np_w_size = nps.warp.size[warpid];
        assert(nps.warp.src[warpid] < __kernel_tb_size);
        src = _np_closure[nps.warp.src[warpid]].src;
        for (int _np_ii = _np_laneid; _np_ii < _np_w_size; _np_ii += 32)
        {
          index_type jj;
          jj = _np_w_start +_np_ii;
          {
            index_type dst;
            uint32_t new_dist;
            uint32_t old_dist;
            dst = graph.getAbsDestination(jj);
            new_dist = 1 + p_dist_current[src];
            old_dist = atomicTestMin(&p_dist_current[dst], new_dist);
            if (old_dist > new_dist)
            {
              bitset_dist_current.set(dst);
            }
          }
        }
      }
      // FP: "90 -> 91;
      __syncthreads();
      // FP: "91 -> 92;
    }

    // FP: "92 -> 93;
    __syncthreads();
    // FP: "93 -> 94;
    _np.total = _np_mps_total.el[1];
    _np.offset = _np_mps.el[1];
    // FP: "94 -> 95;
    while (_np.work())
    {
      // FP: "95 -> 96;
      int _np_i =0;
      // FP: "96 -> 97;
      _np.inspect2(nps.fg.itvalue, nps.fg.src, ITSIZE, threadIdx.x);
      // FP: "97 -> 98;
      __syncthreads();
      // FP: "98 -> 99;

      // FP: "99 -> 100;
      for (_np_i = threadIdx.x; _np_i < ITSIZE && _np.valid(_np_i); _np_i += BLKSIZE)
      {
        index_type jj;
        assert(nps.fg.src[_np_i] < __kernel_tb_size);
        src = _np_closure[nps.fg.src[_np_i]].src;
        jj= nps.fg.itvalue[_np_i];
        {
          index_type dst;
          uint32_t new_dist;
          uint32_t old_dist;
          dst = graph.getAbsDestination(jj);
          new_dist = 1 + p_dist_current[src];
          old_dist = atomicTestMin(&p_dist_current[dst], new_dist);
          if (old_dist > new_dist)
          {
            bitset_dist_current.set(dst);
          }
        }
      }
      // FP: "113 -> 114;
      _np.execute_round_done(ITSIZE);
      // FP: "114 -> 115;
      __syncthreads();
    }
    // FP: "116 -> 117;
    assert(threadIdx.x < __kernel_tb_size);
    src = _np_closure[threadIdx.x].src;
  }
  // FP: "119 -> 120;
  DGAccumulator_accum.thread_exit<cub::BlockReduce<unsigned int, TB_SIZE> >(DGAccumulator_accum_ts);
  work_items.thread_exit<cub::BlockReduce<unsigned int, TB_SIZE> >(work_items_ts);
  // FP: "120 -> 121;
}
__global__ void BFSSanityCheck(CSRGraph graph, unsigned int __begin, unsigned int __end, const uint32_t  local_infinity, uint32_t * p_dist_current, HGAccumulator<uint64_t> DGAccumulator_sum, HGReduceMax<uint32_t> DGMax)
{
  unsigned tid = TID_1D;
  unsigned nthreads = TOTAL_THREADS_1D;

  const unsigned __kernel_tb_size = TB_SIZE;
  __shared__ cub::BlockReduce<uint64_t, TB_SIZE>::TempStorage DGAccumulator_sum_ts;
  __shared__ cub::BlockReduce<uint32_t, TB_SIZE>::TempStorage DGMax_ts;
  index_type src_end;
  // FP: "1 -> 2;
  // FP: "2 -> 3;
  DGAccumulator_sum.thread_entry();
  // FP: "3 -> 4;
  // FP: "4 -> 5;
  DGMax.thread_entry();
  // FP: "5 -> 6;
  src_end = __end;
  for (index_type src = __begin + tid; src < src_end; src += nthreads)
  {
    bool pop  = src < __end;
    if (pop)
    {
      if (p_dist_current[src] < local_infinity)
      {
        DGAccumulator_sum.reduce( 1);
        DGMax.reduce(p_dist_current[src]);
      }
    }
  }
  // FP: "14 -> 15;
  DGAccumulator_sum.thread_exit<cub::BlockReduce<uint64_t, TB_SIZE> >(DGAccumulator_sum_ts);
  // FP: "15 -> 16;
  DGMax.thread_exit<cub::BlockReduce<uint32_t, TB_SIZE> >(DGMax_ts);
  // FP: "16 -> 17;
}
void InitializeGraph_cuda(unsigned int  __begin, unsigned int  __end, const uint32_t & local_infinity, unsigned long long local_src_node, struct CUDA_Context*  ctx)
{
  dim3 blocks;
  dim3 threads;
  // FP: "1 -> 2;
  // FP: "2 -> 3;
  // FP: "3 -> 4;
  kernel_sizing(blocks, threads);
  // FP: "4 -> 5;
  InitializeGraph <<<blocks, threads>>>(ctx->gg, __begin, __end, local_infinity, local_src_node, ctx->dist_current.data.gpu_wr_ptr(), ctx->dist_old.data.gpu_wr_ptr());
  // FP: "5 -> 6;
  check_cuda_kernel;
  // FP: "6 -> 7;
}
void InitializeGraph_allNodes_cuda(const uint32_t & local_infinity, unsigned long long local_src_node, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  InitializeGraph_cuda(0, ctx->gg.nnodes, local_infinity, local_src_node, ctx);
  // FP: "2 -> 3;
}
void InitializeGraph_masterNodes_cuda(const uint32_t & local_infinity, unsigned long long local_src_node, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  InitializeGraph_cuda(ctx->beginMaster, ctx->beginMaster + ctx->numOwned, local_infinity, local_src_node, ctx);
  // FP: "2 -> 3;
}
void InitializeGraph_nodesWithEdges_cuda(const uint32_t & local_infinity, unsigned long long local_src_node, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  InitializeGraph_cuda(0, ctx->numNodesWithEdges, local_infinity, local_src_node, ctx);
  // FP: "2 -> 3;
}
void reset_counters(struct CUDA_Context*  ctx) {

	ctx->stats.thread_prefix_work_wl.zero_gpu();
	ctx->stats.thread_work_wl.in_wl().reset();
	ctx->stats.thread_src_wl.in_wl().reset();
}
void FirstItr_BFS_cuda(unsigned int  __begin, unsigned int  __end, struct CUDA_Context*  ctx)
{
	dim3 blocks;
	dim3 threads;
	// FP: "1 -> 2;
	// FP: "2 -> 3;
	// FP: "3 -> 4;
	kernel_sizing(blocks, threads);
	reset_counters(ctx);

	Inspect_FirstItr_BFS <<<blocks, __tb_FirstItr_BFS>>>(ctx->gg, __begin, __end, ctx->dist_current.data.gpu_wr_ptr(), ctx->dist_old.data.gpu_wr_ptr(),
			ctx->stats.thread_work_wl, ctx->stats.thread_src_wl);
	check_cuda_kernel;

	int num_items = ctx->stats.thread_work_wl.in_wl().nitems();
	if(num_items != 0) {
		computePrefixSum(__begin, __end, ctx);
		check_cuda_kernel;

		BFS_TB_LB <<<blocks, __tb_BFS>>>(ctx->gg, __begin, __end, ctx->dist_current.data.gpu_wr_ptr(),
				  ctx->dist_old.data.gpu_wr_ptr(), *(ctx->dist_current.is_updated.gpu_rd_ptr()),
				  ctx->stats.thread_prefix_work_wl.gpu_wr_ptr(), num_items, ctx->stats.thread_src_wl
				  );
	}
	else {
		FirstItr_BFS <<<blocks, __tb_FirstItr_BFS>>>(ctx->gg, __begin, __end, ctx->dist_current.data.gpu_wr_ptr(), ctx->dist_old.data.gpu_wr_ptr(),
					*(ctx->dist_current.is_updated.gpu_rd_ptr()));
	}
	check_cuda_kernel;
}
void FirstItr_BFS_allNodes_cuda(struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  FirstItr_BFS_cuda(0, ctx->gg.nnodes, ctx);
  // FP: "2 -> 3;
}
void FirstItr_BFS_masterNodes_cuda(struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  FirstItr_BFS_cuda(ctx->beginMaster, ctx->beginMaster + ctx->numOwned, ctx);
  // FP: "2 -> 3;
}
void FirstItr_BFS_nodesWithEdges_cuda(struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  FirstItr_BFS_cuda(0, ctx->numNodesWithEdges, ctx);
  // FP: "2 -> 3;
}
void BFS_cuda(unsigned int  __begin, unsigned int  __end, unsigned int & DGAccumulator_accum, unsigned int & work_items, const uint32_t local_priority, struct CUDA_Context*  ctx)
{
	dim3 blocks;
	dim3 threads;
	HGAccumulator<unsigned int> _DGAccumulator_accum;
	HGAccumulator<unsigned int> _work_items;
	// FP: "1 -> 2;
	// FP: "2 -> 3;
	// FP: "3 -> 4;
	kernel_sizing(blocks, threads);
	// FP: "4 -> 5;
	Shared<unsigned int> DGAccumulator_accumval  = Shared<unsigned int>(1);
	// FP: "5 -> 6;
	// FP: "6 -> 7;
	*(DGAccumulator_accumval.cpu_wr_ptr()) = 0;
	// FP: "7 -> 8;
	_DGAccumulator_accum.rv = DGAccumulator_accumval.gpu_wr_ptr();
	// FP: "8 -> 9;
	Shared<unsigned int> work_itemsval  = Shared<unsigned int>(1);

	*(work_itemsval.cpu_wr_ptr()) = 0;
	_work_items.rv = work_itemsval.gpu_wr_ptr();

	reset_counters(ctx);
	Inspect_BFS <<<blocks, __tb_FirstItr_BFS>>>(ctx->gg, __begin, __end, local_priority, ctx->dist_current.data.gpu_wr_ptr(), ctx->dist_old.data.gpu_wr_ptr(),
			*(ctx->dist_current.is_updated.gpu_rd_ptr()), _DGAccumulator_accum, _work_items,
			ctx->stats.thread_work_wl, ctx->stats.thread_src_wl
			);

	check_cuda_kernel;

	int num_items = ctx->stats.thread_work_wl.in_wl().nitems();

	if(num_items != 0) {
		computePrefixSum(__begin, __end, ctx);
		check_cuda_kernel;

		BFS_TB_LB <<<blocks, __tb_BFS>>>(ctx->gg, __begin, __end, ctx->dist_current.data.gpu_wr_ptr(),
			  ctx->dist_old.data.gpu_wr_ptr(), *(ctx->dist_current.is_updated.gpu_rd_ptr()), ctx->stats.thread_prefix_work_wl.gpu_wr_ptr(),
			  num_items, ctx->stats.thread_src_wl);

		check_cuda_kernel;
		DGAccumulator_accum = *(DGAccumulator_accumval.cpu_rd_ptr());
	}
	BFS <<<blocks, __tb_BFS>>>(ctx->gg, __begin, __end, local_priority, ctx->dist_current.data.gpu_wr_ptr(), ctx->dist_old.data.gpu_wr_ptr(),
			*(ctx->dist_current.is_updated.gpu_rd_ptr()), _DGAccumulator_accum, _work_items);

	check_cuda_kernel;
	// FP: "9 -> 10;
	// FP: "10 -> 11;
	DGAccumulator_accum += *(DGAccumulator_accumval.cpu_rd_ptr());
	work_items = *(work_itemsval.cpu_rd_ptr());
	// FP: "11 -> 12;
}
void BFS_allNodes_cuda(unsigned int & DGAccumulator_accum, unsigned int & work_items, const uint32_t local_priority, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  BFS_cuda(0, ctx->gg.nnodes, DGAccumulator_accum, work_items, local_priority, ctx);
  // FP: "2 -> 3;
}
void BFS_masterNodes_cuda(unsigned int & DGAccumulator_accum, unsigned int & work_items, const uint32_t local_priority, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  BFS_cuda(ctx->beginMaster, ctx->beginMaster + ctx->numOwned, DGAccumulator_accum, work_items, local_priority, ctx);
  // FP: "2 -> 3;
}
void BFS_nodesWithEdges_cuda(unsigned int & DGAccumulator_accum, unsigned int & work_items, const uint32_t local_priority, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  BFS_cuda(0, ctx->numNodesWithEdges, DGAccumulator_accum, work_items, local_priority, ctx);
  // FP: "2 -> 3;
}
void BFSSanityCheck_cuda(unsigned int  __begin, unsigned int  __end, uint64_t & DGAccumulator_sum, uint32_t & DGMax, const uint32_t & local_infinity, struct CUDA_Context*  ctx)
{
  dim3 blocks;
  dim3 threads;
  HGAccumulator<uint64_t> _DGAccumulator_sum;
  HGReduceMax<uint32_t> _DGMax;
  // FP: "1 -> 2;
  // FP: "2 -> 3;
  // FP: "3 -> 4;
  kernel_sizing(blocks, threads);
  // FP: "4 -> 5;
  Shared<uint64_t> DGAccumulator_sumval  = Shared<uint64_t>(1);
  // FP: "5 -> 6;
  // FP: "6 -> 7;
  *(DGAccumulator_sumval.cpu_wr_ptr()) = 0;
  // FP: "7 -> 8;
  _DGAccumulator_sum.rv = DGAccumulator_sumval.gpu_wr_ptr();
  // FP: "8 -> 9;
  Shared<uint32_t> DGMaxval  = Shared<uint32_t>(1);
  // FP: "9 -> 10;
  // FP: "10 -> 11;
  *(DGMaxval.cpu_wr_ptr()) = 0;
  // FP: "11 -> 12;
  _DGMax.rv = DGMaxval.gpu_wr_ptr();
  // FP: "12 -> 13;
  BFSSanityCheck <<<blocks, threads>>>(ctx->gg, __begin, __end, local_infinity, ctx->dist_current.data.gpu_wr_ptr(), _DGAccumulator_sum, _DGMax);
  // FP: "13 -> 14;
  check_cuda_kernel;
  // FP: "14 -> 15;
  DGAccumulator_sum = *(DGAccumulator_sumval.cpu_rd_ptr());
  // FP: "15 -> 16;
  DGMax = *(DGMaxval.cpu_rd_ptr());
  // FP: "16 -> 17;
}
void BFSSanityCheck_allNodes_cuda(uint64_t & DGAccumulator_sum, uint32_t & DGMax, const uint32_t & local_infinity, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  BFSSanityCheck_cuda(0, ctx->gg.nnodes, DGAccumulator_sum, DGMax, local_infinity, ctx);
  // FP: "2 -> 3;
}
void BFSSanityCheck_masterNodes_cuda(uint64_t & DGAccumulator_sum, uint32_t & DGMax, const uint32_t & local_infinity, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  BFSSanityCheck_cuda(ctx->beginMaster, ctx->beginMaster + ctx->numOwned, DGAccumulator_sum, DGMax, local_infinity, ctx);
  // FP: "2 -> 3;
}
void BFSSanityCheck_nodesWithEdges_cuda(uint64_t & DGAccumulator_sum, uint32_t & DGMax, const uint32_t & local_infinity, struct CUDA_Context*  ctx)
{
  // FP: "1 -> 2;
  BFSSanityCheck_cuda(0, ctx->numNodesWithEdges, DGAccumulator_sum, DGMax, local_infinity, ctx);
  // FP: "2 -> 3;
}
