/* { dg-do run { target { rv32 || rv64 } } } */
/* { dg-additional-options "-std=c99" } */

#include "sat_arith.h"

#define T              uint64_t
#define RUN_SAT_BINARY RUN_SAT_U_SUB_FMT_1

DEF_SAT_U_SUB_FMT_1(T)

T test_data[][3] = {
  /*                arg_0,                 arg_1,                 expect */
  {                     0,                     0,                      0, },
  {                     0,                     1,                      0, },
  {                     1,                     1,                      0, },
  { 18446744073709551615u, 18446744073709551614u,                      1, },
  { 18446744073709551615u, 18446744073709551615u,                      0, },
  { 18446744073709551614u, 18446744073709551615u,                      0, },
  { 18446744073709551613u, 18446744073709551614u,                      0, },
  {                     0, 18446744073709551615u,                      0, },
  {                     1, 18446744073709551615u,                      0, },
  {                    43,                    11,                     32, },
};

#include "scalar_sat_binary.h"
