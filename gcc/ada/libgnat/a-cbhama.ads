------------------------------------------------------------------------------
--                                                                          --
--                         GNAT LIBRARY COMPONENTS                          --
--                                                                          --
--   A D A . C O N T A I N E R S . B O U N D E D _ H A S H E D _ M A P S    --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--          Copyright (C) 2004-2025, Free Software Foundation, Inc.         --
--                                                                          --
-- This specification is derived from the Ada Reference Manual for use with --
-- GNAT. The copyright notice above, and the license provisions that follow --
-- apply solely to the  contents of the part following the private keyword. --
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
-- This unit was originally developed by Matthew J Heaney.                  --
------------------------------------------------------------------------------

with Ada.Iterator_Interfaces;

private with Ada.Containers.Hash_Tables;
private with Ada.Streams;
private with Ada.Finalization;
private with Ada.Strings.Text_Buffers;

generic
   type Key_Type is private;
   type Element_Type is private;

   with function Hash (Key : Key_Type) return Hash_Type;
   with function Equivalent_Keys (Left, Right : Key_Type) return Boolean;
   with function "=" (Left, Right : Element_Type) return Boolean is <>;

package Ada.Containers.Bounded_Hashed_Maps with
  SPARK_Mode => Off
is
   pragma Annotate (CodePeer, Skip_Analysis);
   pragma Pure;
   pragma Remote_Types;

   type Map (Capacity : Count_Type; Modulus : Hash_Type) is tagged private with
      Constant_Indexing => Constant_Reference,
      Variable_Indexing => Reference,
      Default_Iterator  => Iterate,
      Iterator_Element  => Element_Type,
      Aggregate         => (Empty     => Empty,
                            Add_Named => Insert),
      Preelaborable_Initialization
                        => Element_Type'Preelaborable_Initialization
                             and
                           Key_Type'Preelaborable_Initialization;

   type Cursor is private with Preelaborable_Initialization;

   Empty_Map : constant Map;
   --  Map objects declared without an initialization expression are
   --  initialized to the value Empty_Map.

   function Empty (Capacity : Count_Type := 10) return Map;

   No_Element : constant Cursor;
   --  Cursor objects declared without an initialization expression are
   --  initialized to the value No_Element.

   function Has_Element (Position : Cursor) return Boolean;
   --  Equivalent to Position /= No_Element

   package Map_Iterator_Interfaces is new
     Ada.Iterator_Interfaces (Cursor, Has_Element);

   function "=" (Left, Right : Map) return Boolean;
   --  For each key/element pair in Left, equality attempts to find the key in
   --  Right; if a search fails the equality returns False. The search works by
   --  calling Hash to find the bucket in the Right map that corresponds to the
   --  Left key. If bucket is non-empty, then equality calls Equivalent_Keys
   --  to compare the key (in Left) to the key of each node in the bucket (in
   --  Right); if the keys are equivalent, then the equality test for this
   --  key/element pair (in Left) completes by calling the element equality
   --  operator to compare the element (in Left) to the element of the node
   --  (in Right) whose key matched.

   function Capacity (Container : Map) return Count_Type;
   --  Returns the current capacity of the map. Capacity is the maximum length
   --  before which rehashing in guaranteed not to occur.

   procedure Reserve_Capacity (Container : in out Map; Capacity : Count_Type);
   --  If the value of the Capacity actual parameter is less or equal to
   --  Container.Capacity, then the operation has no effect.  Otherwise it
   --  raises Capacity_Error (as no expansion of capacity is possible for a
   --  bounded form).

   function Default_Modulus (Capacity : Count_Type) return Hash_Type;
   --  Returns a modulus value (hash table size) which is optimal for the
   --  specified capacity (which corresponds to the maximum number of items).

   function Length (Container : Map) return Count_Type;
   --  Returns the number of items in the map

   function Is_Empty (Container : Map) return Boolean;
   --  Equivalent to Length (Container) = 0

   procedure Clear (Container : in out Map);
   --  Removes all of the items from the map. This will deallocate all memory
   --  associated with this map.

   function Key (Position : Cursor) return Key_Type;
   --  Returns the key of the node designated by the cursor

   function Element (Position : Cursor) return Element_Type;
   --  Returns the element of the node designated by the cursor

   procedure Replace_Element
     (Container : in out Map;
      Position  : Cursor;
      New_Item  : Element_Type);
   --  Assigns the value New_Item to the element designated by the cursor

   procedure Query_Element
     (Position : Cursor;
      Process  : not null access
                   procedure (Key : Key_Type; Element : Element_Type));
   --  Calls Process with the key and element (both having only a constant
   --  view) of the node designed by the cursor.

   procedure Update_Element
     (Container : in out Map;
      Position  : Cursor;
      Process   : not null access
                    procedure (Key : Key_Type; Element : in out Element_Type));
   --  Calls Process with the key (with only a constant view) and element (with
   --  a variable view) of the node designed by the cursor.

   type Constant_Reference_Type
      (Element : not null access constant Element_Type) is
   private
   with
      Implicit_Dereference => Element;

   type Reference_Type (Element : not null access Element_Type) is private
   with
      Implicit_Dereference => Element;

   function Constant_Reference
     (Container : aliased Map;
      Position  : Cursor) return Constant_Reference_Type;

   function Reference
     (Container : aliased in out Map;
      Position  : Cursor) return Reference_Type;

   function Constant_Reference
     (Container : aliased Map;
      Key       : Key_Type) return Constant_Reference_Type;

   function Reference
     (Container : aliased in out Map;
      Key       : Key_Type) return Reference_Type;

   procedure Assign (Target : in out Map; Source : Map);
   --  If Target denotes the same object as Source, then the operation has no
   --  effect. If the Target capacity is less than the Source length, then
   --  Assign raises Capacity_Error.  Otherwise, Assign clears Target and then
   --  copies the (active) elements from Source to Target.

   function Copy
     (Source   : Map;
      Capacity : Count_Type := 0;
      Modulus  : Hash_Type := 0) return Map;
   --  Constructs a new set object whose elements correspond to Source.  If the
   --  Capacity parameter is 0, then the capacity of the result is the same as
   --  the length of Source. If the Capacity parameter is equal or greater than
   --  the length of Source, then the capacity of the result is the specified
   --  value. Otherwise, Copy raises Capacity_Error. If the Modulus parameter
   --  is 0, then the modulus of the result is the value returned by a call to
   --  Default_Modulus with the capacity parameter determined as above;
   --  otherwise the modulus of the result is the specified value.

   procedure Move (Target : in out Map; Source : in out Map);
   --  Clears Target (if it's not empty), and then moves (not copies) the
   --  buckets array and nodes from Source to Target.

   procedure Insert
     (Container : in out Map;
      Key       : Key_Type;
      New_Item  : Element_Type;
      Position  : out Cursor;
      Inserted  : out Boolean);
   --  Conditionally inserts New_Item into the map. If Key is already in the
   --  map, then Inserted returns False and Position designates the node
   --  containing the existing key/element pair (neither of which is modified).
   --  If Key is not already in the map, the Inserted returns True and Position
   --  designates the newly-inserted node container Key and New_Item. The
   --  search for the key works as follows. Hash is called to determine Key's
   --  bucket; if the bucket is non-empty, then Equivalent_Keys is called to
   --  compare Key to each node in that bucket. If the bucket is empty, or
   --  there were no matching keys in the bucket, the search "fails" and the
   --  key/item pair is inserted in the map (and Inserted returns True);
   --  otherwise, the search "succeeds" (and Inserted returns False).

   procedure Insert
     (Container : in out Map;
      Key       : Key_Type;
      Position  : out Cursor;
      Inserted  : out Boolean);
   --  The same as the (conditional) Insert that accepts an element parameter,
   --  with the difference that if Inserted returns True, then the element of
   --  the newly-inserted node is initialized to its default value.

   procedure Insert
     (Container : in out Map;
      Key       : Key_Type;
      New_Item  : Element_Type);
   --  Attempts to insert Key into the map, performing the usual search (which
   --  involves calling both Hash and Equivalent_Keys); if the search succeeds
   --  (because Key is already in the map), then it raises Constraint_Error.
   --  (This version of Insert is similar to Replace, but having the opposite
   --  exception behavior. It is intended for use when you want to assert that
   --  Key is not already in the map.)

   procedure Include
     (Container : in out Map;
      Key       : Key_Type;
      New_Item  : Element_Type);
   --  Attempts to insert Key into the map. If Key is already in the map, then
   --  both the existing key and element are assigned the values of Key and
   --  New_Item, respectively. (This version of Insert only raises an exception
   --  if cursor tampering occurs. It is intended for use when you want to
   --  insert the key/element pair in the map, and you don't care whether Key
   --  is already present.)

   procedure Replace
     (Container : in out Map;
      Key       : Key_Type;
      New_Item  : Element_Type);
   --  Searches for Key in the map; if the search fails (because Key was not in
   --  the map), then it raises Constraint_Error. Otherwise, both the existing
   --  key and element are assigned the values of Key and New_Item rsp. (This
   --  is similar to Insert, but with the opposite exception behavior. It is to
   --  be used when you want to assert that Key is already in the map.)

   procedure Exclude (Container : in out Map; Key : Key_Type);
   --  Searches for Key in the map, and if found, removes its node from the map
   --  and then deallocates it. The search works as follows. The operation
   --  calls Hash to determine the key's bucket; if the bucket is not empty, it
   --  calls Equivalent_Keys to compare Key to each key in the bucket. (This is
   --  the deletion analog of Include. It is intended for use when you want to
   --  remove the item from the map, but don't care whether the key is already
   --  in the map.)

   procedure Delete (Container : in out Map; Key : Key_Type);
   --  Searches for Key in the map (which involves calling both Hash and
   --  Equivalent_Keys). If the search fails, then the operation raises
   --  Constraint_Error. Otherwise it removes the node from the map and then
   --  deallocates it. (This is the deletion analog of non-conditional
   --  Insert. It is intended for use when you want to assert that the item is
   --  already in the map.)

   procedure Delete (Container : in out Map; Position : in out Cursor);
   --  Removes the node designated by Position from the map, and then
   --  deallocates the node. The operation calls Hash to determine the bucket,
   --  and then compares Position to each node in the bucket until there's a
   --  match (it does not call Equivalent_Keys).

   function First (Container : Map) return Cursor;
   --  Returns a cursor that designates the first non-empty bucket, by
   --  searching from the beginning of the buckets array.

   function Next (Position : Cursor) return Cursor;
   --  Returns a cursor that designates the node that follows the current one
   --  designated by Position. If Position designates the last node in its
   --  bucket, the operation calls Hash to compute the index of this bucket,
   --  and searches the buckets array for the first non-empty bucket, starting
   --  from that index; otherwise, it simply follows the link to the next node
   --  in the same bucket.

   procedure Next (Position : in out Cursor);
   --  Equivalent to Position := Next (Position)

   function Find (Container : Map; Key : Key_Type) return Cursor;
   --  Searches for Key in the map. Find calls Hash to determine the key's
   --  bucket; if the bucket is not empty, it calls Equivalent_Keys to compare
   --  Key to each key in the bucket. If the search succeeds, Find returns a
   --  cursor designating the matching node; otherwise, it returns No_Element.

   function Contains (Container : Map; Key : Key_Type) return Boolean;
   --  Equivalent to Find (Container, Key) /= No_Element

   function Element (Container : Map; Key : Key_Type) return Element_Type;
   --  Equivalent to Element (Find (Container, Key))

   function Equivalent_Keys (Left, Right : Cursor) return Boolean;
   --  Returns the result of calling Equivalent_Keys with the keys of the nodes
   --  designated by cursors Left and Right.

   function Equivalent_Keys (Left : Cursor; Right : Key_Type) return Boolean;
   --  Returns the result of calling Equivalent_Keys with key of the node
   --  designated by Left and key Right.

   function Equivalent_Keys (Left : Key_Type; Right : Cursor) return Boolean;
   --  Returns the result of calling Equivalent_Keys with key Left and the node
   --  designated by Right.

   procedure Iterate
     (Container : Map;
      Process   : not null access procedure (Position : Cursor));
   --  Calls Process for each node in the map

   function Iterate (Container : Map)
      return Map_Iterator_Interfaces.Forward_Iterator'class;

private
   pragma Inline (Length);
   pragma Inline (Is_Empty);
   pragma Inline (Clear);
   pragma Inline (Key);
   pragma Inline (Element);
   pragma Inline (Move);
   pragma Inline (Contains);
   pragma Inline (Capacity);
   pragma Inline (Reserve_Capacity);
   pragma Inline (Has_Element);
   pragma Inline (Next);

   type Node_Type is record
      Key     : Key_Type;
      Element : aliased Element_Type;
      Next    : Count_Type;
   end record;

   package HT_Types is
     new Hash_Tables.Generic_Bounded_Hash_Table_Types (Node_Type);

   type Map (Capacity : Count_Type; Modulus : Hash_Type) is
      new HT_Types.Hash_Table_Type (Capacity, Modulus)
      with null record with Put_Image => Put_Image;

   procedure Put_Image
     (S : in out Ada.Strings.Text_Buffers.Root_Buffer_Type'Class; V : Map);

   use HT_Types, HT_Types.Implementation;
   use Ada.Streams;
   use Ada.Finalization;

   procedure Write
     (Stream    : not null access Root_Stream_Type'Class;
      Container : Map);

   for Map'Write use Write;

   procedure Read
     (Stream    : not null access Root_Stream_Type'Class;
      Container : out Map);

   for Map'Read use Read;

   type Map_Access is access all Map;
   for Map_Access'Storage_Size use 0;

   --  Note: If a Cursor object has no explicit initialization expression,
   --  it must default initialize to the same value as constant No_Element.
   --  The Node component of type Cursor has scalar type Count_Type, so it
   --  requires an explicit initialization expression of its own declaration,
   --  in order for objects of record type Cursor to properly initialize.

   type Cursor is record
      Container : Map_Access;
      Node      : Count_Type := 0;
   end record;

   procedure Read
     (Stream : not null access Root_Stream_Type'Class;
      Item   : out Cursor);

   for Cursor'Read use Read;

   procedure Write
     (Stream : not null access Root_Stream_Type'Class;
      Item   : Cursor);

   for Cursor'Write use Write;

   subtype Reference_Control_Type is Implementation.Reference_Control_Type;
   --  It is necessary to rename this here, so that the compiler can find it

   type Constant_Reference_Type
     (Element : not null access constant Element_Type) is
      record
         Control : Reference_Control_Type :=
           raise Program_Error with "uninitialized reference";
         --  The RM says, "The default initialization of an object of
         --  type Constant_Reference_Type or Reference_Type propagates
         --  Program_Error."
      end record;

   procedure Write
     (Stream : not null access Root_Stream_Type'Class;
      Item   : Constant_Reference_Type);

   for Constant_Reference_Type'Write use Write;

   procedure Read
     (Stream : not null access Root_Stream_Type'Class;
      Item   : out Constant_Reference_Type);

   for Constant_Reference_Type'Read use Read;

   type Reference_Type (Element : not null access Element_Type) is record
      Control : Reference_Control_Type :=
        raise Program_Error with "uninitialized reference";
      --  The RM says, "The default initialization of an object of
      --  type Constant_Reference_Type or Reference_Type propagates
      --  Program_Error."
   end record;

   procedure Write
     (Stream : not null access Root_Stream_Type'Class;
      Item   : Reference_Type);

   for Reference_Type'Write use Write;

   procedure Read
     (Stream : not null access Root_Stream_Type'Class;
      Item   : out Reference_Type);

   for Reference_Type'Read use Read;

   --  See Ada.Containers.Vectors for documentation on the following

   procedure _Next (Position : in out Cursor) renames Next;

   function Pseudo_Reference
     (Container : aliased Map'Class) return Reference_Control_Type;
   pragma Inline (Pseudo_Reference);
   --  Creates an object of type Reference_Control_Type pointing to the
   --  container, and increments the Lock. Finalization of this object will
   --  decrement the Lock.

   type Element_Access is access all Element_Type with
     Storage_Size => 0;

   function Get_Element_Access
     (Position : Cursor) return not null Element_Access;
   --  Returns a pointer to the element designated by Position.

   Empty_Map : constant Map :=
                 (Hash_Table_Type with Capacity => 0, Modulus => 0);

   No_Element : constant Cursor := (Container => null, Node => 0);

   type Iterator is new Limited_Controlled and
     Map_Iterator_Interfaces.Forward_Iterator with
   record
      Container : Map_Access;
   end record
     with Disable_Controlled => not T_Check;

   overriding procedure Finalize (Object : in out Iterator);

   overriding function First (Object : Iterator) return Cursor;

   overriding function Next
     (Object   : Iterator;
      Position : Cursor) return Cursor;

end Ada.Containers.Bounded_Hashed_Maps;
