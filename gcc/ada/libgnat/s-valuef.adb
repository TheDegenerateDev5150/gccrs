------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                       S Y S T E M . V A L U E _ F                        --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2020-2025, Free Software Foundation, Inc.       --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

with System.Unsigned_Types; use System.Unsigned_Types;
with System.Val_Util;       use System.Val_Util;
with System.Value_R;

package body System.Value_F is

   --  The prerequisite of the implementation is that the computation of the
   --  operands of the scaled divide does not unduly overflow, which means
   --  that the numerator and the denominator of the small must be both not
   --  larger than the smallest divide 2**(Int'Size - 1) / Base where Base
   --  ranges over the supported values for the base of the literal, except
   --  when the numerator is 1, in which case up to 2**(Int'Size - 1) is
   --  permitted for the denominator. Given that the largest supported base
   --  is 16, this gives a limit of 2**(Int'Size - 5) in the general case.

   pragma Assert (Int'Size <= Uns'Size);
   --  We need an unsigned type large enough to represent the mantissa

   package Impl is new Value_R (Uns, 1, 2**(Int'Size - 1));
   --  We use the Extra digits for ordinary fixed-point types

   function Integer_To_Fixed
     (Str    : String;
      Val    : Uns;
      Base   : Unsigned;
      ScaleB : Integer;
      Extra2 : Unsigned;
      Minus  : Boolean;
      Num    : Int;
      Den    : Int) return Int;
   --  Convert the real value from integer to fixed point representation

   --  The goal is to compute Val * (Base ** ScaleB) / (Num / Den) with correct
   --  rounding for all decimal values output by Typ'Image, that is to say up
   --  to Typ'Aft decimal digits. Unlike for the output, the RM does not say
   --  what the rounding must be for the input, but a reasonable exegesis of
   --  the intent is that Typ'Value o Typ'Image should be the identity, which
   --  is made possible because 'Aft is defined such that 'Image is injective.

   --  For a type with a mantissa of M bits including the sign, the number N1
   --  of decimal digits required to represent all the numbers is given by:

   --    N1 = ceil ((M - 1) * log 2 / log 10) [N1 = 10/19/39 for M = 32/64/128]

   --  but this mantissa can represent any set of contiguous numbers with only
   --  N2 different decimal digits where:

   --    N2 = floor ((M - 1) * log 2 / log 10) [N2 = 9/18/38 for M = 32/64/128]

   --  Of course N1 = N2 + 1 holds, which means both that Val may not contain
   --  enough significant bits to represent all the values of the type and that
   --  1 extra decimal digit contains the information for the missing bits. But
   --  in practice we need 2 extra decimal digits to avoid multiple roundings.

   --  Therefore the actual computation to be performed is

   --    V = (Val * Base ** 2 + Extra2) * (Base ** (ScaleB - 2)) / (Num / Den)

   --  using two steps of scaled divide if Extra2 is positive and ScaleB too

   --    (1a)  Val * (Den * (Base ** ScaleB)) = Q1 * Num + R1

   --    (2a)  Extra2 * (Den * (Base ** ScaleB)) = Q2 * Base ** 2 + R2

   --  which yields after dividing (1a) by Num and (2a) by Num * (Base ** 2)
   --  and summing

   --    V = Q1 + (Q2 + R1) / Num + R2 / (Num * (Base ** 2))

   --  but we get rid of the third term by using a rounding divide for (2a).

   --  This works only if Den * (Base ** ScaleB) does not overflow for inputs
   --  corresponding to 'Image. Let S = Num / Den, B = Base and N the scale in
   --  base B of S, i.e. the smallest integer such that B**N * S >= 1. Then,
   --  for X a positive of the mantissa, i.e. 1 <= X <= 2**(M-1), we have

   --    1/B <= X * S * B**(N-1) < 2**(M-1)

   --  which means that the inputs corresponding to the output of 'Image have a
   --  ScaleB equal either to 1 - N or (after multiplying the inequality by B)
   --  to -N, possibly after renormalizing X, i.e. multiplying it by a suitable
   --  power of B. Therefore

   --    Den * (Base ** ScaleB) <= Den * (B ** (1 - N)) < Num * B

   --  which means that the product does not overflow if Num <= 2**(M-1) / B.

   --  On the other hand, if Extra2 is positive and ScaleB negative, the above
   --  two steps are

   --   (1b)  Val * Den = Q1 * (Num * (Base ** -ScaleB)) + R1

   --   (2b)  Extra2 * Den = Q2 * Base ** 2 + R2

   --  which yields after dividing (1b) by Num * (Base ** -ScaleB) and (2b) by
   --  Num * (Base ** (2 - ScaleB)) and summing

   --    V = Q1 + (Q2 + R1) / (Num * (Base ** -ScaleB)) + R2 / (Num * (...))

   --  but we get rid of the third term by using a rounding divide for (2b).

   --  This works only if Num * (Base ** -ScaleB) does not overflow for inputs
   --  corresponding to 'Image. With the determination of ScaleB above, we have

   --    Num * (Base ** -ScaleB) <= Num * (B ** N) < Den * B

   --  which means that the product does not overflow if Den <= 2**(M-1) / B.
   --  Moreover, if 2**(M-1) / B < Den <= 2**(M-1), we can add 1 to ScaleB and
   --  divide Val by B while preserving the rightmost B-digit of Val in Extra2
   --  without changing the computation when Num = 1.

   ----------------------
   -- Integer_To_Fixed --
   ----------------------

   function Integer_To_Fixed
     (Str    : String;
      Val    : Uns;
      Base   : Unsigned;
      ScaleB : Integer;
      Extra2 : Unsigned;
      Minus  : Boolean;
      Num    : Int;
      Den    : Int) return Int
   is
      pragma Assert (Base in 2 .. 16);

      pragma Assert (Extra2 < Base ** 2);
      --  Accept only two extra digits after those used for Val

      pragma Assert (Num < 0 and then Den < 0);
      --  Accept only negative numbers to allow -2**(Int'Size - 1)

      pragma Unsuppress (Overflow_Check);
      --  Use overflow check to catch bad values

      function Safe_Expont
        (Base   : Int;
         Exp    : in out Natural;
         Factor : Int) return Int;
      --  Return (Base ** Exp) * Factor if the computation does not overflow,
      --  or else the number of the form (Base ** K) * Factor with the largest
      --  magnitude if the former computation overflows. In both cases, Exp is
      --  updated to contain the remaining power in the computation. Note that
      --  Factor is expected to be negative in this context.

      function To_Signed (Val : Uns) return Int;
      --  Convert an integer value from unsigned to signed representation

      -----------------
      -- Safe_Expont --
      -----------------

      function Safe_Expont
        (Base   : Int;
         Exp    : in out Natural;
         Factor : Int) return Int
      is
         pragma Assert (Base /= 0 and then Factor < 0);

         Min : constant Int := Int'First / Base;

         Result : Int := Factor;

      begin
         while Exp > 0 and then Result >= Min loop
            Result := Result * Base;
            Exp    := Exp - 1;
         end loop;

         return Result;
      end Safe_Expont;

      ---------------
      -- To_Signed --
      ---------------

      function To_Signed (Val : Uns) return Int is
      begin
         --  Deal with overflow cases, and also with largest negative number

         if Val > Uns (Int'Last) then
            if Minus and then Val = Uns (-(Int'First)) then
               return Int'First;
            else
               Bad_Value (Str);
            end if;

         --  Negative values

         elsif Minus then
            return -(Int (Val));

         --  Positive values

         else
            return Int (Val);
         end if;
      end To_Signed;

      --  Local variables

      B : constant Int := Int (Base);

      V : Uns      := Val;
      S : Integer  := ScaleB;
      E : Unsigned := Extra2;

      Y, Z, Q1, R1, Q2, R2 : Int;

   begin
      --  The implementation of Value_R uses fully symmetric arithmetics
      --  but here we cannot handle 2**(Int'Size - 1) if Minus is not set.

      if V = 2**(Int'Size - 1) and then not Minus then
         E := Unsigned (V rem Uns (Base)) * Base + E / Base;
         V := V / Uns (Base);
         S := S + 1;
      end if;

      --  We will use a scaled divide operation for which we must control the
      --  magnitude of operands so that an overflow exception is not unduly
      --  raised during the computation. The only real concern is the exponent.

      --  If S is too negative, then drop trailing digits, but preserve the
      --  last two dropped digits, until V saturates to 0.

      if S < 0 then
         declare
            LS : Integer := -S;

         begin
            Y := Den;
            Z := Safe_Expont (B, LS, Num);

            for J in 1 .. LS loop
               if V = 0 then
                  E := 0;
                  exit;
               end if;
               E := Unsigned (V rem Uns (Base)) * Base + E / Base;
               V := V / Uns (Base);
            end loop;
         end;

      --  If S is too positive, then scale V up, which may then overflow

      elsif S > 0 then
         declare
            LS : Integer := S;

         begin
            Y := Safe_Expont (B, LS, Den);
            Z := Num;

            for J in 1 .. LS loop
               if V <= (Uns'Last - Uns (E / Base)) / Uns (Base) then
                  V := V * Uns (Base) + Uns (E / Base);
                  E := (E rem Base) * Base;
               else
                  Bad_Value (Str);
               end if;
            end loop;
         end;

      --  If S is zero, then proceed directly

      else
         Y := Den;
         Z := Num;
      end if;

      --  Perform a scaled divide operation with final rounding to match Image
      --  using two steps if there is an extra digit available. The second and
      --  third operands are always negative so the sign of the quotient is the
      --  sign of the first operand and the sign of the remainder the opposite.

      if E > 0 then
         Scaled_Divide (To_Signed (V), Y, Z, Q1, R1, Round => False);
         Scaled_Divide (To_Signed (Uns (E)), Y, -B**2, Q2, R2, Round => True);

         --  Avoid an overflow during the subtraction. Note that Q2 is smaller
         --  than Y and R1 smaller than Z in magnitude, so it is safe to take
         --  their absolute value.

         if abs Q2 >= 2 ** (Int'Size - 2)
           or else abs R1 >= 2 ** (Int'Size - 2)
         then
            declare
               Bit : constant Int := Q2 rem 2;

            begin
               Q2 := (Q2 - Bit) / 2;
               R1 := (R1 - Bit) / 2;
               Y  := -2;
            end;

         else
            Y := -1;
         end if;

         Scaled_Divide (Q2 - R1, Y, Z, Q2, R2, Round => True);

         return Q1 + Q2;

      else
         Scaled_Divide (To_Signed (V), Y, Z, Q1, R1, Round => True);

         return Q1;
      end if;

   exception
      when Constraint_Error => Bad_Value (Str);
   end Integer_To_Fixed;

   ----------------
   -- Scan_Fixed --
   ----------------

   function Scan_Fixed
     (Str : String;
      Ptr : not null access Integer;
      Max : Integer;
      Num : Int;
      Den : Int) return Int
   is
      Bas    : Unsigned;
      Scl    : Impl.Scale_Array;
      Extra2 : Unsigned;
      Minus  : Boolean;
      Val    : Impl.Value_Array;

   begin
      Val := Impl.Scan_Raw_Real (Str, Ptr, Max, Bas, Scl, Extra2, Minus);

      return
        Integer_To_Fixed (Str, Val (1), Bas, Scl (1), Extra2, Minus, Num, Den);
   end Scan_Fixed;

   -----------------
   -- Value_Fixed --
   -----------------

   function Value_Fixed
     (Str : String;
      Num : Int;
      Den : Int) return Int
   is
      Bas    : Unsigned;
      Scl    : Impl.Scale_Array;
      Extra2 : Unsigned;
      Minus  : Boolean;
      Val    : Impl.Value_Array;

   begin
      Val := Impl.Value_Raw_Real (Str, Bas, Scl, Extra2, Minus);

      return
        Integer_To_Fixed (Str, Val (1), Bas, Scl (1), Extra2, Minus, Num, Den);
   end Value_Fixed;

end System.Value_F;
