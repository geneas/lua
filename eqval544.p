diff -ru lua-5.4.4/src/lobject.h lua-5.4.4.mod/src/lobject.h
--- lua-5.4.4/src/lobject.h	2022-01-13 22:24:42.000000000 +1100
+++ lua-5.4.4.mod/src/lobject.h	2022-02-07 13:01:08.695948515 +1100
@@ -118,6 +118,12 @@
           io1->value_ = io2->value_; settt_(io1, io2->tt_); \
 	  checkliveness(L,io1); lua_assert(!isnonstrictnil(io1)); }
 
+/* main macro to copy values (from 'obj2' to 'obj1') */
+#define setobjint(L,obj1,x) \
+	{ TValue *io1=(obj1); \
+          io1->value_.i=(x); settt_(io, LUA_VNUMINT); \
+	  checkliveness(L,io1); lua_assert(!isnonstrictnil(io1)); }
+
 /*
 ** Different types of assignments, according to source and destination.
 ** (They are mostly equal now, but may be different in the future.)
diff -ru lua-5.4.4/src/ltm.c lua-5.4.4.mod/src/ltm.c
--- lua-5.4.4/src/ltm.c	2022-01-13 22:24:42.000000000 +1100
+++ lua-5.4.4.mod/src/ltm.c	2022-02-10 19:11:19.883633723 +1100
@@ -38,7 +38,7 @@
 void luaT_init (lua_State *L) {
   static const char *const luaT_eventname[] = {  /* ORDER TM */
     "__index", "__newindex",
-    "__gc", "__mode", "__len", "__eq",
+    "__gc", "__mode", "__len", "__eqval", "__eq",
     "__add", "__sub", "__mul", "__mod", "__pow",
     "__div", "__idiv",
     "__band", "__bor", "__bxor", "__shl", "__shr",
@@ -126,6 +126,24 @@
   L->top += 3;
   /* metamethod may yield only when called from Lua code */
   if (isLuacode(L->ci))
+    luaD_call(L, func, 1);
+  else
+    luaD_callnoyield(L, func, 1);
+  res = restorestack(L, result);
+  setobjs2s(L, res, --L->top);  /* move result to its place */
+}
+
+
+void luaT_callTMresI (lua_State *L, const TValue *f, const TValue *p1,
+                     int n, StkId res) {
+  ptrdiff_t result = savestack(L, res);
+  StkId func = L->top;
+  setobj2s(L, func, f);  /* push function (assume EXTRA_STACK) */
+  setobj2s(L, func + 1, p1);  /* 1st argument */
+  setivalue(s2v(func + 2), n);
+  L->top += 3;
+  /* metamethod may yield only when called from Lua code */
+  if (isLuacode(L->ci))
     luaD_call(L, func, 1);
   else
     luaD_callnoyield(L, func, 1);
diff -ru lua-5.4.4/src/ltm.h lua-5.4.4.mod/src/ltm.h
--- lua-5.4.4/src/ltm.h	2022-01-13 22:24:42.000000000 +1100
+++ lua-5.4.4.mod/src/ltm.h	2022-02-07 13:03:33.127729428 +1100
@@ -21,6 +21,7 @@
   TM_GC,
   TM_MODE,
   TM_LEN,
+  TM_EQVAL,
   TM_EQ,  /* last tag method with fast access */
   TM_ADD,
   TM_SUB,
@@ -82,6 +83,8 @@
                             const TValue *p2, const TValue *p3);
 LUAI_FUNC void luaT_callTMres (lua_State *L, const TValue *f,
                             const TValue *p1, const TValue *p2, StkId p3);
+LUAI_FUNC void luaT_callTMresI (lua_State *L, const TValue *f,
+                            const TValue *p1, int n, StkId p3);
 LUAI_FUNC void luaT_trybinTM (lua_State *L, const TValue *p1, const TValue *p2,
                               StkId res, TMS event);
 LUAI_FUNC void luaT_tryconcatTM (lua_State *L);
diff -ru lua-5.4.4/src/lvm.c lua-5.4.4.mod/src/lvm.c
--- lua-5.4.4/src/lvm.c	2022-01-13 22:24:43.000000000 +1100
+++ lua-5.4.4.mod/src/lvm.c	2022-02-10 21:52:39.414740259 +1100
@@ -558,6 +558,42 @@
 }
 
 
+
+/*
+** Equality of Lua values of differing type variants; return 't1 == t2'.
+*/
+static int luaV_EQval (lua_State *L, const TValue *t1, const TValue *t2) {
+  const TValue *tm = NULL;
+  switch (ttypetag(t1)) {
+    case LUA_VUSERDATA:
+      tm = fasttm(L, uvalue(t1)->metatable, TM_EQVAL);
+      break;  /* will try TM */
+    case LUA_VTABLE:
+      tm = fasttm(L, hvalue(t1)->metatable, TM_EQVAL);
+      break;  /* will try TM */
+    default:
+      break;
+  }
+  if (tm == NULL) {
+    switch (ttypetag(t2)) {
+      case LUA_VUSERDATA:
+        tm = fasttm(L, uvalue(t2)->metatable, TM_EQVAL);
+        break;  /* will try TM */
+      case LUA_VTABLE:
+        tm = fasttm(L, hvalue(t2)->metatable, TM_EQVAL);
+        break;  /* will try TM */
+      default:
+        return 0;
+    }
+  }
+  if (tm == NULL)  /* no TM? */
+    return 0;  /* objects are different */
+    
+  luaT_callTMres(L, tm, t1, t2, L->top);  /* call TM */
+  return !l_isfalse(s2v(L->top));
+}
+
+
 /*
 ** Main operation for equality of Lua values; return 't1 == t2'.
 ** L == NULL means raw equality (no metamethods)
@@ -565,8 +601,10 @@
 int luaV_equalobj (lua_State *L, const TValue *t1, const TValue *t2) {
   const TValue *tm;
   if (ttypetag(t1) != ttypetag(t2)) {  /* not the same variant? */
-    if (ttype(t1) != ttype(t2) || ttype(t1) != LUA_TNUMBER)
+    if (ttype(t1) != ttype(t2) || ttype(t1) != LUA_TNUMBER) {
+      if (L != NULL) return luaV_EQval(L, t1, t2);
       return 0;  /* only numbers can be equal with different variants */
+    }
     else {  /* two numbers with different variants */
       /* One of them is an integer. If the other does not have an
          integer value, they cannot be equal; otherwise, compare their
@@ -614,6 +652,29 @@
 }
 
 
+/*
+** Compare non-number Lua value with integer constant; return 't1 == n'.
+*/
+int luaV_equalI (lua_State *L, const TValue *t1, int n) {
+  const TValue *tm;
+  switch (ttypetag(t1)) {
+    case LUA_VUSERDATA:
+      tm = fasttm(L, uvalue(t1)->metatable, TM_EQVAL);
+      break;  /* will try TM */
+    case LUA_VTABLE:
+      tm = fasttm(L, hvalue(t1)->metatable, TM_EQVAL);
+      break;  /* will try TM */
+    default:
+      return 0;	/* other types cannot be equal to a number */
+  }
+  if (tm == NULL)  /* no TM? */
+    return 0;  /* objects are different */
+  
+  luaT_callTMresI(L, tm, t1, n, L->top);  /* call TM */
+  return !l_isfalse(s2v(L->top));
+}
+
+
 /* macro used by 'luaV_concat' to ensure that element at 'o' is a string */
 #define tostring(L,o)  \
 	(ttisstring(o) || (cvt2str(o) && (luaO_tostring(L, o), 1)))
@@ -1577,8 +1638,15 @@
       }
       vmcase(OP_EQK) {
         TValue *rb = KB(i);
-        /* basic types do not use '__eq'; we can use raw equality */
-        int cond = luaV_rawequalobj(s2v(ra), rb);
+        int cond;
+        int tt = ttypetag(s2v(ra));
+        if (tt == LUA_VUSERDATA || tt == LUA_VTABLE) {
+          Protect(cond = luaV_equalobj(L, s2v(ra), rb));
+        }
+        else {
+	  /* basic types do not use '__eq'; we can use raw equality */
+	  cond = luaV_rawequalobj(s2v(ra), rb);
+	}
         docondjump();
         vmbreak;
       }
@@ -1590,7 +1658,7 @@
         else if (ttisfloat(s2v(ra)))
           cond = luai_numeq(fltvalue(s2v(ra)), cast_num(im));
         else
-          cond = 0;  /* other types cannot be equal to a number */
+          Protect(cond = luaV_equalI(L, s2v(ra), im));
         docondjump();
         vmbreak;
       }
