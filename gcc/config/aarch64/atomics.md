;; Machine description for AArch64 processor synchronization primitives.
;; Copyright (C) 2009-2025 Free Software Foundation, Inc.
;; Contributed by ARM Ltd.
;;
;; This file is part of GCC.
;;
;; GCC is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; GCC is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GCC; see the file COPYING3.  If not see
;; <http://www.gnu.org/licenses/>.

;; Instruction patterns.

(define_expand "@atomic_compare_and_swap<mode>"
  [(match_operand:SI 0 "register_operand" "")			;; bool out
   (match_operand:ALLI_TI 1 "register_operand" "")		;; val out
   (match_operand:ALLI_TI 2 "aarch64_sync_memory_operand" "")	;; memory
   (match_operand:ALLI_TI 3 "nonmemory_operand" "")		;; expected
   (match_operand:ALLI_TI 4 "aarch64_reg_or_zero" "")		;; desired
   (match_operand:SI 5 "const_int_operand")			;; is_weak
   (match_operand:SI 6 "const_int_operand")			;; mod_s
   (match_operand:SI 7 "const_int_operand")]			;; mod_f
  ""
  {
    aarch64_expand_compare_and_swap (operands);
    DONE;
  }
)

(define_mode_attr cas_short_expected_pred
  [(QI "aarch64_reg_or_imm") (HI "aarch64_plushi_operand")])
(define_mode_attr cas_short_expected_imm
  [(QI "n") (HI "Uih")])

(define_insn_and_split "@aarch64_compare_and_swap<mode>"
  [(set (reg:CC CC_REGNUM)					;; bool out
    (unspec_volatile:CC [(const_int 0)] UNSPECV_ATOMIC_CMPSW))
   (set (match_operand:SI 0 "register_operand" "=&r")		;; val out
    (zero_extend:SI
      (match_operand:SHORT 1 "aarch64_sync_memory_operand" "+Q"))) ;; memory
   (set (match_dup 1)
    (unspec_volatile:SHORT
      [(match_operand:SHORT 2 "<cas_short_expected_pred>"
			      "r<cas_short_expected_imm>")	;; expected
       (match_operand:SHORT 3 "aarch64_reg_or_zero" "rZ")	;; desired
       (match_operand:SI 4 "const_int_operand")			;; is_weak
       (match_operand:SI 5 "const_int_operand")			;; mod_s
       (match_operand:SI 6 "const_int_operand")]		;; mod_f
      UNSPECV_ATOMIC_CMPSW))
   (clobber (match_scratch:SI 7 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_compare_and_swap (operands);
    DONE;
  }
)

(define_insn_and_split "@aarch64_compare_and_swap<mode>"
  [(set (reg:CC CC_REGNUM)					;; bool out
    (unspec_volatile:CC [(const_int 0)] UNSPECV_ATOMIC_CMPSW))
   (set (match_operand:GPI 0 "register_operand" "=&r")		;; val out
    (match_operand:GPI 1 "aarch64_sync_memory_operand" "+Q"))   ;; memory
   (set (match_dup 1)
    (unspec_volatile:GPI
      [(match_operand:GPI 2 "aarch64_plus_operand" "rIJ")	;; expect
       (match_operand:GPI 3 "aarch64_reg_or_zero" "rZ")		;; desired
       (match_operand:SI 4 "const_int_operand")			;; is_weak
       (match_operand:SI 5 "const_int_operand")			;; mod_s
       (match_operand:SI 6 "const_int_operand")]		;; mod_f
      UNSPECV_ATOMIC_CMPSW))
   (clobber (match_scratch:SI 7 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_compare_and_swap (operands);
    DONE;
  }
)

(define_insn_and_split "@aarch64_compare_and_swap<mode>"
  [(set (reg:CC CC_REGNUM)					;; bool out
    (unspec_volatile:CC [(const_int 0)] UNSPECV_ATOMIC_CMPSW))
   (set (match_operand:JUST_TI 0 "register_operand" "=&r")	;; val out
    (match_operand:JUST_TI 1 "aarch64_sync_memory_operand" "+Q")) ;; memory
   (set (match_dup 1)
    (unspec_volatile:JUST_TI
      [(match_operand:JUST_TI 2 "aarch64_reg_or_zero" "rZ")	;; expect
       (match_operand:JUST_TI 3 "aarch64_reg_or_zero" "rZ")	;; desired
       (match_operand:SI 4 "const_int_operand")			;; is_weak
       (match_operand:SI 5 "const_int_operand")			;; mod_s
       (match_operand:SI 6 "const_int_operand")]		;; mod_f
      UNSPECV_ATOMIC_CMPSW))
   (clobber (match_scratch:SI 7 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_compare_and_swap (operands);
    DONE;
  }
)

(define_insn "@aarch64_compare_and_swap<mode>_lse"
  [(set (match_operand:SI 0 "register_operand" "+r")		;; val out
    (zero_extend:SI
     (match_operand:SHORT 1 "aarch64_sync_memory_operand" "+Q"))) ;; memory
   (set (match_dup 1)
    (unspec_volatile:SHORT
      [(match_dup 0)						;; expected
       (match_operand:SHORT 2 "aarch64_reg_or_zero" "rZ")	;; desired
       (match_operand:SI 3 "const_int_operand")]		;; mod_s
      UNSPECV_ATOMIC_CMPSW))]
  "TARGET_LSE"
{
  enum memmodel model = memmodel_from_int (INTVAL (operands[3]));
  if (is_mm_relaxed (model))
    return "cas<atomic_sfx>\t%<w>0, %<w>2, %1";
  else if (is_mm_acquire (model) || is_mm_consume (model))
    return "casa<atomic_sfx>\t%<w>0, %<w>2, %1";
  else if (is_mm_release (model))
    return "casl<atomic_sfx>\t%<w>0, %<w>2, %1";
  else
    return "casal<atomic_sfx>\t%<w>0, %<w>2, %1";
})

(define_insn "@aarch64_compare_and_swap<mode>_lse"
  [(set (match_operand:GPI 0 "register_operand" "+r")		;; val out
    (match_operand:GPI 1 "aarch64_sync_memory_operand" "+Q"))   ;; memory
   (set (match_dup 1)
    (unspec_volatile:GPI
      [(match_dup 0)						;; expected
       (match_operand:GPI 2 "aarch64_reg_or_zero" "rZ")		;; desired
       (match_operand:SI 3 "const_int_operand")]		;; mod_s
      UNSPECV_ATOMIC_CMPSW))]
  "TARGET_LSE"
{
  enum memmodel model = memmodel_from_int (INTVAL (operands[3]));
  if (is_mm_relaxed (model))
    return "cas<atomic_sfx>\t%<w>0, %<w>2, %1";
  else if (is_mm_acquire (model) || is_mm_consume (model))
    return "casa<atomic_sfx>\t%<w>0, %<w>2, %1";
  else if (is_mm_release (model))
    return "casl<atomic_sfx>\t%<w>0, %<w>2, %1";
  else
    return "casal<atomic_sfx>\t%<w>0, %<w>2, %1";
})

(define_insn "@aarch64_compare_and_swap<mode>_lse"
  [(set (match_operand:JUST_TI 0 "register_operand" "+r")	;; val out
    (match_operand:JUST_TI 1 "aarch64_sync_memory_operand" "+Q")) ;; memory
   (set (match_dup 1)
    (unspec_volatile:JUST_TI
      [(match_dup 0)						;; expect
       (match_operand:JUST_TI 2 "register_operand" "r")		;; desired
       (match_operand:SI 3 "const_int_operand")]		;; mod_s
      UNSPECV_ATOMIC_CMPSW))]
  "TARGET_LSE"
{
  enum memmodel model = memmodel_from_int (INTVAL (operands[3]));
  if (is_mm_relaxed (model))
    return "casp\t%0, %R0, %2, %R2, %1";
  else if (is_mm_acquire (model) || is_mm_consume (model))
    return "caspa\t%0, %R0, %2, %R2, %1";
  else if (is_mm_release (model))
    return "caspl\t%0, %R0, %2, %R2, %1";
  else
    return "caspal\t%0, %R0, %2, %R2, %1";
})

(define_expand "atomic_exchange<mode>"
 [(match_operand:ALLI 0 "register_operand")
  (match_operand:ALLI 1 "aarch64_sync_memory_operand")
  (match_operand:ALLI 2 "aarch64_reg_or_zero")
  (match_operand:SI 3 "const_int_operand")]
  ""
  {
    /* Use an atomic SWP when available.  */
    if (TARGET_LSE)
      {
	emit_insn (gen_aarch64_atomic_exchange<mode>_lse
		   (operands[0], operands[1], operands[2], operands[3]));
      }
    else if (TARGET_OUTLINE_ATOMICS)
      {
	machine_mode mode = <MODE>mode;
	rtx func = aarch64_atomic_ool_func (mode, operands[3],
					    &aarch64_ool_swp_names);
	rtx rval = emit_library_call_value (func, operands[0], LCT_NORMAL,
					    mode, operands[2], mode,
					    XEXP (operands[1], 0), Pmode);
        emit_move_insn (operands[0], rval);
      }
    else
      {
	emit_insn (gen_aarch64_atomic_exchange<mode>
		   (operands[0], operands[1], operands[2], operands[3]));
      }
    DONE;
  }
)

(define_insn_and_split "aarch64_atomic_exchange<mode>"
  [(set (match_operand:ALLI 0 "register_operand" "=&r")		;; output
    (match_operand:ALLI 1 "aarch64_sync_memory_operand" "+Q"))	;; memory
   (set (match_dup 1)
    (unspec_volatile:ALLI
      [(match_operand:ALLI 2 "aarch64_reg_or_zero" "rZ")	;; input
       (match_operand:SI 3 "const_int_operand" "")]		;; model
      UNSPECV_ATOMIC_EXCHG))
   (clobber (reg:CC CC_REGNUM))
   (clobber (match_scratch:SI 4 "=&r"))]
  "!TARGET_LSE"
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_atomic_op (SET, operands[0], NULL, operands[1],
			     operands[2], operands[3], operands[4]);
    DONE;
  }
)

(define_insn "aarch64_atomic_exchange<mode>_lse"
  [(set (match_operand:ALLI 0 "register_operand" "=r")
    (match_operand:ALLI 1 "aarch64_sync_memory_operand" "+Q"))
   (set (match_dup 1)
    (unspec_volatile:ALLI
      [(match_operand:ALLI 2 "aarch64_reg_or_zero" "rZ")
       (match_operand:SI 3 "const_int_operand" "")]
      UNSPECV_ATOMIC_EXCHG))]
  "TARGET_LSE"
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[3]));
    if (is_mm_relaxed (model))
      return "swp<atomic_sfx>\t%<w>2, %<w>0, %1";
    else if (is_mm_acquire (model) || is_mm_consume (model))
      return "swpa<atomic_sfx>\t%<w>2, %<w>0, %1";
    else if (is_mm_release (model))
      return "swpl<atomic_sfx>\t%<w>2, %<w>0, %1";
    else
      return "swpal<atomic_sfx>\t%<w>2, %<w>0, %1";
  }
)

(define_expand "atomic_<atomic_optab><mode>"
 [(match_operand:ALLI 0 "aarch64_sync_memory_operand")
  (atomic_op:ALLI
   (match_operand:ALLI 1 "<atomic_op_operand>")
   (match_operand:SI 2 "const_int_operand"))]
  ""
  {
    rtx (*gen) (rtx, rtx, rtx);

    /* Use an atomic load-operate instruction when possible.  */
    if (TARGET_LSE)
      {
	switch (<CODE>)
	  {
	  case MINUS:
	    operands[1] = expand_simple_unop (<MODE>mode, NEG, operands[1],
					      NULL, 1);
	    /* fallthru */
	  case PLUS:
	    gen = gen_aarch64_atomic_add<mode>_lse;
	    break;
	  case IOR:
	    gen = gen_aarch64_atomic_ior<mode>_lse;
	    break;
	  case XOR:
	    gen = gen_aarch64_atomic_xor<mode>_lse;
	    break;
	  case AND:
	    operands[1] = expand_simple_unop (<MODE>mode, NOT, operands[1],
					      NULL, 1);
	    gen = gen_aarch64_atomic_bic<mode>_lse;
	    break;
	  default:
	    gcc_unreachable ();
	  }
	operands[1] = force_reg (<MODE>mode, operands[1]);
      }
    else if (TARGET_OUTLINE_ATOMICS)
      {
        const atomic_ool_names *names;
	switch (<CODE>)
	  {
	  case MINUS:
	    operands[1] = expand_simple_unop (<MODE>mode, NEG, operands[1],
					      NULL, 1);
	    /* fallthru */
	  case PLUS:
	    names = &aarch64_ool_ldadd_names;
	    break;
	  case IOR:
	    names = &aarch64_ool_ldset_names;
	    break;
	  case XOR:
	    names = &aarch64_ool_ldeor_names;
	    break;
	  case AND:
	    operands[1] = expand_simple_unop (<MODE>mode, NOT, operands[1],
					      NULL, 1);
	    names = &aarch64_ool_ldclr_names;
	    break;
	  default:
	    gcc_unreachable ();
	  }
        machine_mode mode = <MODE>mode;
	rtx func = aarch64_atomic_ool_func (mode, operands[2], names);
	emit_library_call_value (func, NULL_RTX, LCT_NORMAL, mode,
				 operands[1], mode,
				 XEXP (operands[0], 0), Pmode);
        DONE;
      }
    else
      gen = gen_aarch64_atomic_<atomic_optab><mode>;

    emit_insn (gen (operands[0], operands[1], operands[2]));
    DONE;
  }
)

(define_insn_and_split "aarch64_atomic_<atomic_optab><mode>"
 [(set (match_operand:ALLI 0 "aarch64_sync_memory_operand" "+Q")
   (unspec_volatile:ALLI
    [(atomic_op:ALLI (match_dup 0)
      (match_operand:ALLI 1 "<atomic_op_operand>" "r<const_atomic>"))
     (match_operand:SI 2 "const_int_operand")]
    UNSPECV_ATOMIC_OP))
  (clobber (reg:CC CC_REGNUM))
  (clobber (match_scratch:ALLI 3 "=&r"))
  (clobber (match_scratch:SI 4 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_atomic_op (<CODE>, NULL, operands[3], operands[0],
			     operands[1], operands[2], operands[4]);
    DONE;
  }
)

;; It is tempting to want to use ST<OP> for relaxed and release
;; memory models here.  However, that is incompatible with the
;; C++ memory model for the following case:
;;
;;	atomic_fetch_add(ptr, 1, memory_order_relaxed);
;;	atomic_thread_fence(memory_order_acquire);
;;
;; The problem is that the architecture says that ST<OP> (and LD<OP>
;; insns where the destination is XZR) are not regarded as a read.
;; However we also implement the acquire memory barrier with DMB LD,
;; and so the ST<OP> is not blocked by the barrier.

(define_insn "aarch64_atomic_<atomic_ldoptab><mode>_lse"
  [(set (match_operand:ALLI 0 "aarch64_sync_memory_operand" "+Q")
	(unspec_volatile:ALLI
	  [(match_dup 0)
	   (match_operand:ALLI 1 "register_operand" "r")
	   (match_operand:SI 2 "const_int_operand")]
      ATOMIC_LDOP))
   (clobber (match_scratch:ALLI 3 "=r"))]
  "TARGET_LSE"
  {
   enum memmodel model = memmodel_from_int (INTVAL (operands[2]));
   if (is_mm_relaxed (model))
     return "ld<atomic_ldop><atomic_sfx>\t%<w>1, %<w>3, %0";
   else if (is_mm_release (model))
     return "ld<atomic_ldop>l<atomic_sfx>\t%<w>1, %<w>3, %0";
   else if (is_mm_acquire (model) || is_mm_consume (model))
     return "ld<atomic_ldop>a<atomic_sfx>\t%<w>1, %<w>3, %0";
   else
     return "ld<atomic_ldop>al<atomic_sfx>\t%<w>1, %<w>3, %0";
  }
)

(define_insn_and_split "atomic_nand<mode>"
  [(set (match_operand:ALLI 0 "aarch64_sync_memory_operand" "+Q")
    (unspec_volatile:ALLI
      [(not:ALLI
	(and:ALLI (match_dup 0)
	  (match_operand:ALLI 1 "aarch64_logical_operand" "r<lconst_atomic>")))
       (match_operand:SI 2 "const_int_operand")]		;; model
      UNSPECV_ATOMIC_OP))
   (clobber (reg:CC CC_REGNUM))
   (clobber (match_scratch:ALLI 3 "=&r"))
   (clobber (match_scratch:SI 4 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
     aarch64_split_atomic_op (NOT, NULL, operands[3], operands[0],
			     operands[1], operands[2], operands[4]);
     DONE;
  }
)

;; Load-operate-store, returning the original memory data.

(define_expand "atomic_fetch_<atomic_optab><mode>"
 [(match_operand:ALLI 0 "register_operand")
  (match_operand:ALLI 1 "aarch64_sync_memory_operand")
  (atomic_op:ALLI
   (match_operand:ALLI 2 "<atomic_op_operand>")
   (match_operand:SI 3 "const_int_operand"))]
 ""
{
  rtx (*gen) (rtx, rtx, rtx, rtx);

  /* Use an atomic load-operate instruction when possible.  */
  if (TARGET_LSE)
    {
      switch (<CODE>)
        {
	case MINUS:
	  operands[2] = expand_simple_unop (<MODE>mode, NEG, operands[2],
					    NULL, 1);
	  /* fallthru */
	case PLUS:
	  gen = gen_aarch64_atomic_fetch_add<mode>_lse;
	  break;
	case IOR:
	  gen = gen_aarch64_atomic_fetch_ior<mode>_lse;
	  break;
	case XOR:
	  gen = gen_aarch64_atomic_fetch_xor<mode>_lse;
	  break;
	case AND:
	  operands[2] = expand_simple_unop (<MODE>mode, NOT, operands[2],
					    NULL, 1);
	  gen = gen_aarch64_atomic_fetch_bic<mode>_lse;
	  break;
	default:
	  gcc_unreachable ();
	}
      operands[2] = force_reg (<MODE>mode, operands[2]);
    }
  else if (TARGET_OUTLINE_ATOMICS)
    {
      const atomic_ool_names *names;
      switch (<CODE>)
	{
	case MINUS:
	  operands[2] = expand_simple_unop (<MODE>mode, NEG, operands[2],
					    NULL, 1);
	  /* fallthru */
	case PLUS:
	  names = &aarch64_ool_ldadd_names;
	  break;
	case IOR:
	  names = &aarch64_ool_ldset_names;
	  break;
	case XOR:
	  names = &aarch64_ool_ldeor_names;
	  break;
	case AND:
	  operands[2] = expand_simple_unop (<MODE>mode, NOT, operands[2],
					    NULL, 1);
	  names = &aarch64_ool_ldclr_names;
	  break;
	default:
	  gcc_unreachable ();
	}
      machine_mode mode = <MODE>mode;
      rtx func = aarch64_atomic_ool_func (mode, operands[3], names);
      rtx rval = emit_library_call_value (func, operands[0], LCT_NORMAL, mode,
					  operands[2], mode,
					  XEXP (operands[1], 0), Pmode);
      emit_move_insn (operands[0], rval);
      DONE;
    }
  else
    gen = gen_aarch64_atomic_fetch_<atomic_optab><mode>;

  emit_insn (gen (operands[0], operands[1], operands[2], operands[3]));
  DONE;
})

(define_insn_and_split "aarch64_atomic_fetch_<atomic_optab><mode>"
  [(set (match_operand:ALLI 0 "register_operand" "=&r")
    (match_operand:ALLI 1 "aarch64_sync_memory_operand" "+Q"))
   (set (match_dup 1)
    (unspec_volatile:ALLI
      [(atomic_op:ALLI (match_dup 1)
	(match_operand:ALLI 2 "<atomic_op_operand>" "r<const_atomic>"))
       (match_operand:SI 3 "const_int_operand")]		;; model
      UNSPECV_ATOMIC_OP))
   (clobber (reg:CC CC_REGNUM))
   (clobber (match_scratch:ALLI 4 "=&r"))
   (clobber (match_scratch:SI 5 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_atomic_op (<CODE>, operands[0], operands[4], operands[1],
			     operands[2], operands[3], operands[5]);
    DONE;
  }
)

(define_insn "aarch64_atomic_fetch_<atomic_ldoptab><mode>_lse"
  [(set (match_operand:ALLI 0 "register_operand" "=r")
	(match_operand:ALLI 1 "aarch64_sync_memory_operand" "+Q"))
   (set (match_dup 1)
	(unspec_volatile:ALLI
	  [(match_dup 1)
	   (match_operand:ALLI 2 "register_operand" "r")
	   (match_operand:SI 3 "const_int_operand")]
	  ATOMIC_LDOP))]
  "TARGET_LSE"
  {
   enum memmodel model = memmodel_from_int (INTVAL (operands[3]));
   if (is_mm_relaxed (model))
     return "ld<atomic_ldop><atomic_sfx>\t%<w>2, %<w>0, %1";
   else if (is_mm_acquire (model) || is_mm_consume (model))
     return "ld<atomic_ldop>a<atomic_sfx>\t%<w>2, %<w>0, %1";
   else if (is_mm_release (model))
     return "ld<atomic_ldop>l<atomic_sfx>\t%<w>2, %<w>0, %1";
   else
     return "ld<atomic_ldop>al<atomic_sfx>\t%<w>2, %<w>0, %1";
  }
)

(define_insn_and_split "atomic_fetch_nand<mode>"
  [(set (match_operand:ALLI 0 "register_operand" "=&r")
    (match_operand:ALLI 1 "aarch64_sync_memory_operand" "+Q"))
   (set (match_dup 1)
    (unspec_volatile:ALLI
      [(not:ALLI
	 (and:ALLI (match_dup 1)
	   (match_operand:ALLI 2 "aarch64_logical_operand" "r<lconst_atomic>")))
       (match_operand:SI 3 "const_int_operand")]		;; model
      UNSPECV_ATOMIC_OP))
   (clobber (reg:CC CC_REGNUM))
   (clobber (match_scratch:ALLI 4 "=&r"))
   (clobber (match_scratch:SI 5 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_atomic_op (NOT, operands[0], operands[4], operands[1],
			    operands[2], operands[3], operands[5]);
    DONE;
  }
)

;; Load-operate-store, returning the updated memory data.

(define_expand "atomic_<atomic_optab>_fetch<mode>"
 [(match_operand:ALLI 0 "register_operand")
  (atomic_op:ALLI
   (match_operand:ALLI 1 "aarch64_sync_memory_operand")
   (match_operand:ALLI 2 "<atomic_op_operand>"))
  (match_operand:SI 3 "const_int_operand")]
 ""
{
  /* Use an atomic load-operate instruction when possible.  In this case
     we will re-compute the result from the original mem value. */
  if (TARGET_LSE || TARGET_OUTLINE_ATOMICS)
    {
      rtx tmp = gen_reg_rtx (<MODE>mode);
      operands[2] = force_reg (<MODE>mode, operands[2]);
      emit_insn (gen_atomic_fetch_<atomic_optab><mode>
                 (tmp, operands[1], operands[2], operands[3]));
      tmp = expand_simple_binop (<MODE>mode, <CODE>, tmp, operands[2],
				 operands[0], 1, OPTAB_WIDEN);
      emit_move_insn (operands[0], tmp);
    }
  else
    {
      emit_insn (gen_aarch64_atomic_<atomic_optab>_fetch<mode>
                 (operands[0], operands[1], operands[2], operands[3]));
    }
  DONE;
})

(define_insn_and_split "aarch64_atomic_<atomic_optab>_fetch<mode>"
  [(set (match_operand:ALLI 0 "register_operand" "=&r")
    (atomic_op:ALLI
      (match_operand:ALLI 1 "aarch64_sync_memory_operand" "+Q")
      (match_operand:ALLI 2 "<atomic_op_operand>" "r<const_atomic>")))
   (set (match_dup 1)
    (unspec_volatile:ALLI
      [(match_dup 1) (match_dup 2)
       (match_operand:SI 3 "const_int_operand")]		;; model
      UNSPECV_ATOMIC_OP))
    (clobber (reg:CC CC_REGNUM))
   (clobber (match_scratch:SI 4 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_atomic_op (<CODE>, NULL, operands[0], operands[1],
			     operands[2], operands[3], operands[4]);
    DONE;
  }
)

(define_insn_and_split "atomic_nand_fetch<mode>"
  [(set (match_operand:ALLI 0 "register_operand" "=&r")
    (not:ALLI
      (and:ALLI
	(match_operand:ALLI 1 "aarch64_sync_memory_operand" "+Q")
	(match_operand:ALLI 2 "aarch64_logical_operand" "r<lconst_atomic>"))))
   (set (match_dup 1)
    (unspec_volatile:ALLI
      [(match_dup 1) (match_dup 2)
       (match_operand:SI 3 "const_int_operand")]		;; model
      UNSPECV_ATOMIC_OP))
   (clobber (reg:CC CC_REGNUM))
   (clobber (match_scratch:SI 4 "=&r"))]
  ""
  "#"
  "&& epilogue_completed"
  [(const_int 0)]
  {
    aarch64_split_atomic_op (NOT, NULL, operands[0], operands[1],
			    operands[2], operands[3], operands[4]);
    DONE;
  }
)

(define_insn "*atomic_load<ALLX:mode>_zext<SD_HSDI:mode>"
  [(set (match_operand:SD_HSDI 0 "register_operand" "=r")
	(zero_extend:SD_HSDI
	  (unspec_volatile:ALLX
	    [(match_operand:ALLX 1 "aarch64_sync_memory_operand" "Q")
	     (match_operand:SI 2 "const_int_operand")]			;; model
	   UNSPECV_LDA)))]
  "GET_MODE_SIZE (<SD_HSDI:MODE>mode) > GET_MODE_SIZE (<ALLX:MODE>mode)"
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[2]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_release (model))
      return "ldr<ALLX:atomic_sfx>\t%<ALLX:w>0, %1";
    else
      return "ldar<ALLX:atomic_sfx>\t%<ALLX:w>0, %1";
  }
)

(define_expand "atomic_load<mode>"
  [(match_operand:ALLI 0 "register_operand" "=r")
   (match_operand:ALLI 1 "aarch64_sync_memory_operand" "Q")
   (match_operand:SI   2 "const_int_operand")]
  ""
  {
    /* If TARGET_RCPC and this is an ACQUIRE load, then expand to a pattern
       using UNSPECV_LDAP.  */
    enum memmodel model = memmodel_from_int (INTVAL (operands[2]));
    if (TARGET_RCPC
	&& (is_mm_acquire (model)
	    || is_mm_acq_rel (model)))
      emit_insn (gen_aarch64_atomic_load<mode>_rcpc (operands[0], operands[1],
						     operands[2]));
    else
      emit_insn (gen_aarch64_atomic_load<mode> (operands[0], operands[1],
						operands[2]));
    DONE;
  }
)

(define_insn "aarch64_atomic_load<mode>_rcpc"
  [(set (match_operand:ALLI 0 "register_operand")
    (unspec_volatile:ALLI
      [(match_operand:ALLI 1 "aarch64_rcpc_memory_operand")
       (match_operand:SI 2 "const_int_operand")]			;; model
      UNSPECV_LDAP))]
  "TARGET_RCPC"
  {@ [ cons: =0 , 1   ; attrs: enable_ldapur  ]
     [ r        , Q   ; any                   ] ldapr<atomic_sfx>\t%<w>0, %1
     [ r        , Ust ; yes                   ] ldapur<atomic_sfx>\t%<w>0, %1
  }
)

(define_insn "aarch64_atomic_load<mode>"
  [(set (match_operand:ALLI 0 "register_operand" "=r")
    (unspec_volatile:ALLI
      [(match_operand:ALLI 1 "aarch64_sync_memory_operand" "Q")
       (match_operand:SI 2 "const_int_operand")]			;; model
      UNSPECV_LDA))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[2]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_release (model))
      return "ldr<atomic_sfx>\t%<w>0, %1";
    else
      return "ldar<atomic_sfx>\t%<w>0, %1";
  }
)

(define_insn "*aarch64_atomic_load<ALLX:mode>_rcpc_zext"
  [(set (match_operand:SD_HSDI 0 "register_operand")
    (zero_extend:SD_HSDI
      (unspec_volatile:ALLX
        [(match_operand:ALLX 1 "aarch64_rcpc_memory_operand")
         (match_operand:SI 2 "const_int_operand")]			;; model
       UNSPECV_LDAP)))]
  "TARGET_RCPC && (<SD_HSDI:sizen> > <ALLX:sizen>)"
  {@ [ cons: =0 , 1   ; attrs: enable_ldapur ]
     [ r        , Q   ; any                  ] ldapr<ALLX:atomic_sfx>\t%w0, %1
     [ r        , Ust ; yes                  ] ldapur<ALLX:atomic_sfx>\t%w0, %1
  }
)

(define_insn "*aarch64_atomic_load<ALLX:mode>_rcpc_sext"
  [(set (match_operand:GPI  0 "register_operand" "=r")
    (sign_extend:GPI
      (unspec_volatile:ALLX
        [(match_operand:ALLX 1 "aarch64_rcpc_memory_operand" "Ust")
         (match_operand:SI 2 "const_int_operand")]			;; model
       UNSPECV_LDAP)))]
  "TARGET_RCPC2 && (<GPI:sizen> > <ALLX:sizen>)"
  "ldapurs<ALLX:size>\t%<GPI:w>0, %1"
)

(define_insn "atomic_store<mode>"
  [(set (match_operand:ALLI 0 "aarch64_rcpc_memory_operand" "=Q,Ust")
    (unspec_volatile:ALLI
      [(match_operand:ALLI 1 "general_operand" "rZ,rZ")
       (match_operand:SI 2 "const_int_operand")]			;; model
      UNSPECV_STL))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[2]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_acquire (model))
      return "str<atomic_sfx>\t%<w>1, %0";
    else if (which_alternative == 0)
      return "stlr<atomic_sfx>\t%<w>1, %0";
    else
      return "stlur<atomic_sfx>\t%<w>1, %0";
  }
  [(set_attr "arch" "*,rcpc8_4")]
)

(define_insn "@aarch64_load_exclusive<mode>"
  [(set (match_operand:SI 0 "register_operand" "=r")
    (zero_extend:SI
      (unspec_volatile:SHORT
	[(match_operand:SHORT 1 "aarch64_sync_memory_operand" "Q")
	 (match_operand:SI 2 "const_int_operand")]
	UNSPECV_LX)))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[2]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_release (model))
      return "ldxr<atomic_sfx>\t%w0, %1";
    else
      return "ldaxr<atomic_sfx>\t%w0, %1";
  }
)

(define_insn "@aarch64_load_exclusive<mode>"
  [(set (match_operand:GPI 0 "register_operand" "=r")
    (unspec_volatile:GPI
      [(match_operand:GPI 1 "aarch64_sync_memory_operand" "Q")
       (match_operand:SI 2 "const_int_operand")]
      UNSPECV_LX))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[2]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_release (model))
      return "ldxr\t%<w>0, %1";
    else
      return "ldaxr\t%<w>0, %1";
  }
)

(define_insn "aarch64_load_exclusive_pair"
  [(set (match_operand:DI 0 "register_operand" "=r")
	(unspec_volatile:DI
	  [(match_operand:TI 2 "aarch64_sync_memory_operand" "Q")
	   (match_operand:SI 3 "const_int_operand")]
	  UNSPECV_LX))
   (set (match_operand:DI 1 "register_operand" "=r")
	(unspec_volatile:DI [(match_dup 2) (match_dup 3)] UNSPECV_LX))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[3]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_release (model))
      return "ldxp\t%0, %1, %2";
    else
      return "ldaxp\t%0, %1, %2";
  }
)

(define_insn "@aarch64_store_exclusive<mode>"
  [(set (match_operand:SI 0 "register_operand" "=&r")
    (unspec_volatile:SI [(const_int 0)] UNSPECV_SX))
   (set (match_operand:ALLI 1 "aarch64_sync_memory_operand" "=Q")
    (unspec_volatile:ALLI
      [(match_operand:ALLI 2 "aarch64_reg_or_zero" "rZ")
       (match_operand:SI 3 "const_int_operand")]
      UNSPECV_SX))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[3]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_acquire (model))
      return "stxr<atomic_sfx>\t%w0, %<w>2, %1";
    else
      return "stlxr<atomic_sfx>\t%w0, %<w>2, %1";
  }
)

(define_insn "aarch64_store_exclusive_pair"
  [(set (match_operand:SI 0 "register_operand" "=&r")
	(unspec_volatile:SI [(const_int 0)] UNSPECV_SX))
   (set (match_operand:TI 1 "aarch64_sync_memory_operand" "=Q")
	(unspec_volatile:TI
	  [(match_operand:DI 2 "aarch64_reg_or_zero" "rZ")
	   (match_operand:DI 3 "aarch64_reg_or_zero" "rZ")
	   (match_operand:SI 4 "const_int_operand")]
	  UNSPECV_SX))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[4]));
    if (is_mm_relaxed (model) || is_mm_consume (model) || is_mm_acquire (model))
      return "stxp\t%w0, %x2, %x3, %1";
    else
      return "stlxp\t%w0, %x2, %x3, %1";
  }
)

(define_expand "mem_thread_fence"
  [(match_operand:SI 0 "const_int_operand")]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[0]));
    if (!(is_mm_relaxed (model) || is_mm_consume (model)))
      emit_insn (gen_dmb (operands[0]));
    DONE;
  }
)

(define_expand "dmb"
  [(set (match_dup 1)
    (unspec:BLK [(match_dup 1) (match_operand:SI 0 "const_int_operand")]
     UNSPEC_MB))]
   ""
   {
    operands[1] = gen_rtx_MEM (BLKmode, gen_rtx_SCRATCH (Pmode));
    MEM_VOLATILE_P (operands[1]) = 1;
  }
)

(define_insn "*dmb"
  [(set (match_operand:BLK 0 "" "")
    (unspec:BLK [(match_dup 0) (match_operand:SI 1 "const_int_operand")]
     UNSPEC_MB))]
  ""
  {
    enum memmodel model = memmodel_from_int (INTVAL (operands[1]));
    if (is_mm_acquire (model))
      return "dmb\\tishld";
    else
      return "dmb\\tish";
  }
)
