/* { dg-do run { target { riscv_v } } } */
/* { dg-additional-options "-std=c99 --param=gpr2vr-cost=0" } */

#include "vx_binary.h"
#include "vx_binary_data.h"

#define T          uint32_t
#define NAME       min
#define FUNC       MIN_FUNC_0_WARP(T)
#define TEST_DATA  TEST_BINARY_DATA_WRAP(T, NAME)

DEF_VX_BINARY_CASE_2_WRAP(T, FUNC, NAME)

#define TEST_RUN(T, NAME, out, in, x, n) \
  RUN_VX_BINARY_CASE_2_WRAP(T, NAME, FUNC, out, in, x, n)

#include "vx_binary_run.h"
