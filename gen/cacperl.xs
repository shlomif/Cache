// (c) 2001 - 2004 by St. Traby <stefan@hello-penguin.com>
// this contains an interface to the basic low-level call-in function
// and some high-level interfaces.
// users should not mix low-level and high-level interface unless
// they know the side-effects.
// low-level interface routines start with "_" and are not exported
// by default. ("_" means private)
//

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <ccallin.h>

#include <string.h>
#include <limits.h>
#include <cache_fix.h>

extern char *kwc_cache_home;

static void cache_croak(int ecode, char *msg)
{
   CACHE_ASTR a;
   char *p = 0;
   
    a.len = CACHE_MAXSTRLEN-1;
    if(CacheErrxlateA(ecode, &a)) {
      // ok, it was not a standard error, lets see
      // if it was a Callin Error...
      switch(ecode) {
        case -1: 
          p = "#define CACHE_FAILURE      -1  (ask Intersystems)\n";
          break;
        case -2:
          p = "#define CACHE_ALREADYCON   -2  (ask Intersystems)\n";
          break;
        case -3:
          p = "#define CACHE_STRTOOLONG   -3   /* A string argument is too long */\n";
          break;
        case -4:
          p = "#define CACHE_CONBROKEN    -4   /* We broke the connection */\n";
          break;
        case -6:
          p = "#define CACHE_INTERRUPT    -6   /* Failed due to CTRL/C (special case of CacheError() */\n";
          break;
        case -7:
          p = "#define CACHE_NOCON        -7   /* not connected to Cache */\n";
          break;
        case -8:
          p = "#define CACHE_RETTOOSMALL  -8   /* return buffer too small, nothing returned */\n";
          break;
        case -9:
          p = "#define CACHE_ERUNKNOWN    -9   /* Unknown error code in persave */\n";
          break;
        case -10:
          p = "#define CACHE_RETTRUNC    -10   /* The return buffer was too small so only part of the requested item was returned */\n";
          break;
        case -11:
          p = "#define CACHE_NOTINCACHE  -11   /* Returned from CacheAbort() if the process wasn't executing on the Cache side */\n";
          break;
        case -12:
          p = "#define CACHE_BADARG      -12   /* A function was called with an argument that was out of range or otherwise invalid */\n";
          break;
        case -13:
          p = "#define CACHE_NORES       -13   /* CacheConvert() was called to get a result but there's no result to return */\n";
          break;
      }
      if(p)
        strcpy(a.str, p);
      else 
        sprintf(a.str, "got an error while trying to resolve Cache error code rc=%d\nThis should not happen :(\n", ecode);
    }
    strcat(a.str, "\n");
    strcat(a.str, msg);
    strcat(a.str, "\n");
    croak(a.str);
}

#define CACHE_CROAK(code, msg) do { if(code) cache_croak(code, msg); } while(0)

static inline void CacheSVPush(SV *sv)
{
   int rc;

   switch (SvTYPE(sv)) {
     case SVt_IV:
     // case Svt_PVIV:
        {
          IV i = SvIV(sv);
#if defined USE_64_BIT_INT
          if(i < (IV) INT_MIN || i > (IV) INT_MAX) {
            // ok, storing large integer as string.
            char *p;
            int l;
            p = SvPV(sv, l);
            rc = CachePushStr(l, p);
            CACHE_CROAK(rc, "CacheSVPush: CachePushStr");
            return;
          }
#endif
          rc = CachePushInt(i);
          CACHE_CROAK(rc, "CacheSVPush: CachePushInt");
          break;
        }
     case SVt_NV:
        rc = CachePushDbl(SvNV(sv));
        CACHE_CROAK(rc, "CacheSVPush: CachePushDbl");
        break;
     default:
       {
        char *p;
        int l;
        if(0 && !SvPOK(sv)) {
           sv_dump(sv);
           croak("CacheSVPush: Not prepared to push non-scalar values.");
        }
        p = SvPV(sv, l);
        if(l > CACHE_MAXSTRLEN -1)
          croak("CacheSVPush: string too long");
        rc = CachePushStr(l, p);
        CACHE_CROAK(rc, "CacheSVPush: CachePushStr");
       }
       break;
   }
}

MODULE = Cache		PACKAGE = Cache

PROTOTYPES: ENABLE

BOOT:
        // my_init_cache(); // we can't delay because shmat will fail. IDIOTS

char *
CacheHome()
  CODE:
  	RETVAL=kwc_cache_home;
OUTPUT:
	RETVAL

void
_CacheCtrl(u)
  UV u;
PREINIT:
  int rc;
CODE:
  rc = CacheCtrl((unsigned long) u);
  CACHE_CROAK(rc, "_CacheCtrl");

void
_CacheCloseOref(i)
  IV i;
PREINIT:
  int rc;
CODE:
  rc = CacheCloseOref(i);
  CACHE_CROAK(rc, "_CacheCloseOref");

  
void
_CacheAbort(i)
  IV i;
ALIAS:
  _CacheSignal = 1
PREINIT:
  int rc;
CODE:
  rc = ix ? CacheSignal(i) : CacheAbort(i);
  CACHE_CROAK(rc, "_CacheAbort or _CacheSignal");

SV*
_CachePrompt()
PREINIT:
  int rc;
  CACHE_ASTR a;
CODE:
  a.len = CACHE_MAXSTRLEN -1;
  rc = CachePromptA(&a);
  CACHE_CROAK(rc, "_CachePrompt");
  RETVAL = newSVpvn(a.str, a.len);
OUTPUT:
  RETVAL
  
void
_CacheStart(flags, timeout, in, out)
  UV flags;
  IV timeout;
  SV *in;
  SV *out;
PREINIT:
  int rc;
  int in_len, out_len;
  char *in_p, *out_p;
  CACHE_ASTR ain, aout;
CODE:
  in_p =  SvPV(in, in_len);
  out_p = SvPV(out, out_len);
  if(in_len > CACHE_MAXSTRLEN -1 || out_len > CACHE_MAXSTRLEN -1)
     croak("_CacheStart called with too large parameters");
  if(in_len)
    memcpy(ain.str, in_p, in_len);
  ain.len = in_len;
  if(out_len)
    memcpy(aout.str, out_p, out_len);
  aout.len = out_len;
  rc = CacheStartA((unsigned long) flags, (int) timeout, &ain, &aout);
  CACHE_CROAK(rc, "_CacheStart");


  
  
IV
_CacheContext()
  CODE:
  RETVAL = CacheContext();
OUTPUT:
  RETVAL
 
SV *
_CacheCvtIn(sv_e, sv_t)
  SV *sv_e;
  SV *sv_t;
ALIAS:
  _CacheCvtOut = 1
PREINIT:
  CACHE_ASTR e, t, a; // ugly, 163840 on stack, don't kill me
  int el, tl;
  char *ep, *tp;
  int rc;
CODE:
  ep = SvPV(sv_e, el);
  tp = SvPV(sv_t, tl);
  if(el > CACHE_MAXSTRLEN -1 || tl > CACHE_MAXSTRLEN -1)
     croak("called _CacheCvt[In|Out]A with too large arguments");
  memcpy(e.str, ep, el);
  memcpy(t.str, tp, tl);
  e.len = el;
  t.len = tl;
  a.len = CACHE_MAXSTRLEN-1; 
  rc = ix ? CacheCvtOutA(&e, &t, &a) : CacheCvtInA(&e, &t, &a);
  CACHE_CROAK(rc, "_CacheCvt[In|Out]A");
  RETVAL = newSVpvn(a.str, a.len);
OUTPUT:
  RETVAL


void
_CacheEval(sv)
  SV *sv;
PREINIT:
	CACHE_ASTR a;
        STRLEN l;
        char *p;
        int rc;
  CODE:
  	p = SvPV(sv, l);
        if(l)
		memcpy(a.str, p, l);
        a.len = l;
  	rc = CacheEvalA(&a);
        CACHE_CROAK(rc, "_CacheEval");

SV *
CacheEval(sv)
  SV *sv;
PREINIT:
	CACHE_ASTR a;
        STRLEN l;
        char *p;
        int rc;
  CODE:
  	p = SvPV(sv, l);
        if(l)
		memcpy(a.str, p, l);
        a.len = l;
        TTY_SAVE; SIGNAL_SAVE;
  	rc = CacheEvalA(&a);
        SIGNAL_RESTORE; TTY_RESTORE;
        CACHE_CROAK(rc, "CacheEval: CacheEvalA");
        a.len = sizeof(a.str);
        rc = CacheConvert(CACHE_ASTRING, (unsigned char *)&a);
        CACHE_CROAK(rc, "CacheEval: CacheConvert");
        RETVAL = newSVpvn(a.str, a.len);
OUTPUT:
        RETVAL

void
_CacheExecute(sv)
  SV *sv;
PREINIT:
	CACHE_ASTR a;
        STRLEN l;
        char *p;
        int rc;
  CODE:
  	p = SvPV(sv, l);
        if(l)
		memcpy(a.str, p, l);
        a.len = l;
  	rc = CacheExecuteA(&a);
        CACHE_CROAK(rc, "_CacheExecute");

void
CacheExecute(sv)
  SV *sv;
PREINIT:
	CACHE_ASTR a;
        STRLEN l;
        char *p;
        int rc;
  CODE:
  	p = SvPV(sv, l);
        if(l)
		memcpy(a.str, p, l);
        a.len = l;
        TTY_SAVE; SIGNAL_SAVE;
  	rc = CacheExecuteA(&a);
        SIGNAL_RESTORE; TTY_RESTORE;
        CACHE_CROAK(rc, "_CacheExecute");


IV
_CacheType()
  CODE:
  	RETVAL = CacheType();
  OUTPUT:
  	RETVAL
        
SV *
_CacheConvert()
  PREINIT:
  	int rc;
        CACHE_ASTR a;
   CODE:
   	a.len = CACHE_MAXSTRLEN-1;
        rc = CacheConvert(CACHE_ASTRING, (unsigned char *)&a);
        if(rc != CACHE_SUCCESS) {
          croak("CacheConvert, rc = %d", rc);
        }
	CacheOflush();
	RETVAL = newSVpvn(a.str, a.len);
   OUTPUT:
   	RETVAL
        

SV *
_CacheConvert2()
  PREINIT:
  	int rc;
   CODE:
   	switch((rc = CacheType())) {
          case CACHE_CONBROKEN:
          case CACHE_ERSYSTEM:
          case CACHE_NOCON:
            croak("_CacheConvert2: cache error %d", rc);
            break;
          case CACHE_NORES:
            croak("_CacheConvert2: no result to fetch !");
            break;
          case CACHE_DOUBLE:
             {
		double d;
                rc = CacheConvert(CACHE_DOUBLE, (unsigned char *)&d);
	        if(rc) {
                  croak("_CacheConvert2: error fetching double.");
                }
                RETVAL = newSVnv(d);
             }
            break;
          case CACHE_INT:
             {
              	int i;
                rc = CacheConvert(CACHE_INT, (unsigned char *)&i);
                if(rc) {
                  croak("_CacheConvert2: error fetching int.");
                }
                RETVAL = newSViv(i);
             }
	    break;
          default:
            // Assume/convert to ASTRING
             {
            	CACHE_ASTR a;
   		a.len = CACHE_MAXSTRLEN-1;
        	rc = CacheConvert(CACHE_ASTRING, (unsigned char *)&a);
        	if(rc != CACHE_SUCCESS) {
          		croak("CacheConvert2, error fetching astring");
                }
		RETVAL = newSVpvn(a.str, a.len);
             }
        }
   OUTPUT:
   	RETVAL
        

SV *
_CacheErrxlate(i)
  IV i;
PREINIT:
	CACHE_ASTR a;
CODE:
   	a.len = CACHE_MAXSTRLEN-1;
        if(CacheErrxlateA(i, &a)) {
          	RETVAL = &PL_sv_undef;
        } else {
	 	RETVAL = newSVpvn(a.str, a.len);
        }
OUTPUT:
	RETVAL


void
_CachePushInt(i)
  IV i;
PREINIT:
  int rc;
CODE:
        rc = CachePushInt((int) i);
        CACHE_CROAK(rc, "_CachePushInt");

void
_CachePushDbl(d)
  NV d;
PREINIT:
  int rc;
CODE:
        rc = CachePushDbl(d);
        CACHE_CROAK(rc, "_CachePushDbl");
        
void
_CachePushOref(o)
 UV o;
PREINIT:
  int rc;
CODE:
        rc = CachePushOref((unsigned) o);
        CACHE_CROAK(rc, "_CachePushOref");

void
_CachePushProperty(o,prop)
 UV o;
 SV *prop;
PREINIT:
 int rc;
 int prop_len;
 char *prop_ptr;
CODE:
 prop_ptr = SvPV(prop, prop_len);
 if(prop_len > CACHE_MAXSTRLEN -1)
  croak("_CachePushProperty: Property too long");
 rc = CachePushProperty((unsigned) o, prop_len, prop_ptr);
 CACHE_CROAK(rc, "_CachePushProperty");

void
_CachePushStr(s)
  SV *s
ALIAS:
        _CachePushGlobal = 1
        _CachePushList = 2
        _CachePushPtr = 3
PREINIT:
        int l;
        unsigned char *p;
        int rc;
CODE:
  	p = SvPV(s, l);
        switch(ix) {
          case 0:
                rc = CachePushStr(l, p);
                CACHE_CROAK(rc, "_CachePushStr");
                break;
          case 1:
                rc = CachePushGlobal(l, p);
                CACHE_CROAK(rc, "_CachePushGlobal");
                break;
          case 2:
                rc = CachePushList(l, p);
                CACHE_CROAK(rc, "_CachePushList");
                break;
          case 3:
                rc = CachePushPtr(p);
                CACHE_CROAK(rc, "_CachePushPtr");
                break;
        }

void
_CachePushMethod(oref, method, flag=0)
  UV oref;
  SV *method;
  IV flag;
PREINIT:
  int rc;
  int m_len;
  char *m_ptr;
CODE:
  m_ptr = SvPV(method, m_len);
  if(m_len > CACHE_MAXSTRLEN -1)
        croak("_CachePushMethod: method name too long");
  rc = CachePushMethod((unsigned) oref, m_len, m_ptr, (int) flag);
  CACHE_CROAK(rc, "_CachePushMethod");

void
_CacheUnPop()
ALIAS:
   _CacheEnd = 1
   _CacheGetProperty = 2
   _CacheSetProperty = 3
PREINIT:
  int rc;
CODE:
        switch(ix) {
          case 0:
            rc = CacheUnPop();
            CACHE_CROAK(rc, "_CacheUnPop");
            break;
          case 1:
            rc = CacheEnd();
            CACHE_CROAK(rc, "_CacheEnd");
            break;
          case 2:
            rc = CacheGetProperty();
            CACHE_CROAK(rc, "_CacheGetProperty");
            break;
          case 3:
            rc = CacheSetProperty();
            CACHE_CROAK(rc, "_CacheSetProperty");
            break;
        }


IV
_CachePopInt()
PREINIT:
        int i;
        int rc;
CODE:
        rc = CachePopInt(&i);
        CACHE_CROAK(rc, "_CachePopInt");
        RETVAL = i;
OUTPUT:
        RETVAL

NV
_CachePopDbl()
PREINIT:
        int rc;
CODE:
        rc = CachePopDbl(&RETVAL);
        CACHE_CROAK(rc, "_CachePopDbl");
OUTPUT:
        RETVAL

UV
_CachePopOref()
PREINIT:
   unsigned uv;
   int rc;
CODE:
        rc = CachePopOref(&uv);
        CACHE_CROAK(rc, "_CachePopOref");
        RETVAL = uv;
OUTPUT:
        RETVAL

SV *
_CachePopStr()
PREINIT:
        unsigned char *p;
        int l;
        int rc;
CODE:
        rc = CachePopStr(&l, &p);
        CACHE_CROAK(rc, "_CachePopStr");
	RETVAL = newSVpvn(p, l);
OUTPUT:
        RETVAL

void
_CacheSetVar(v)
  SV *v;
ALIAS:
    _CacheGetVar = 1
PREINIT:
        STRLEN l;
        unsigned char *p;
        int rc;
CODE:
        p = SvPV(v, l);
        switch(ix) {
          case 0:
             rc = CacheSetVar(l, p);
             CACHE_CROAK(rc, "_CacheSetVar");
             break;
          case 1:
             rc = CacheGetVar(l, p);
             CACHE_CROAK(rc, "_CacheGetVar");
             break;
        }
  
void
_CacheDoRtn(u,i)
  UV u;
  IV i;
PREINIT:
        int rc;
ALIAS:
  _CacheDoFun = 1
  _CacheExtFun = 2
  _CacheGlobalGet = 3
CODE:
        switch(ix) {
          case 0:
                rc = CacheDoRtn((unsigned) u, (int) i);
                CACHE_CROAK(rc, "_CacheDoRtn");
                break;
          case 1:
                rc = CacheDoFun((unsigned) u, (int) i);
                CACHE_CROAK(rc, "_CacheDoFun");
                break;
          case 2:
                rc = CacheExtFun((unsigned) u, (int) i);
                CACHE_CROAK(rc, "_CacheExtFun");
                break;
          case 3:
                rc = CacheGlobalGet((unsigned) u, (int) i);
                CACHE_CROAK(rc, "_CacheGlobalGet");
                break;

        }

void
_CachePushGlobalX(t, n)
  SV *t;
  SV *n;
PREINIT:
  int rc;
  char *tp, *np;
  int tl, nl;
CODE:
  tp = SvPV(t, tl);
  np = SvPV(n, nl);
  if(tl > CACHE_MAXSTRLEN -1 || nl > CACHE_MAXSTRLEN -1)
     croak("global or namespace name way to long");
  rc = CachePushGlobalX(tl, tp, nl, np);
  CACHE_CROAK(rc, "_CachePushGlobalX");

  
IV
_CachePushFunc(tag, routine)
  SV *tag;
  SV *routine;
ALIAS:
        _CachePushRtn = 1
PREINIT:
  int rc;
  unsigned rflags;
  char *tag_ptr;
  char *routine_ptr;
  int tag_len;
  int routine_len;
CODE:
  tag_ptr = SvPV(tag, tag_len);
  routine_ptr = SvPV(routine, routine_len);
  if(tag_len > CACHE_MAXSTRLEN -1 || routine_len > CACHE_MAXSTRLEN -1)
      croak("label or routine name way too long.");
  switch(ix) {
    case 0:
        rc = CachePushFunc(&rflags, tag_len, tag_ptr, routine_len, routine_ptr);
        CACHE_CROAK(rc, "_CachePushFunc");
        break;
    case 1:
        rc = CachePushRtn(&rflags, tag_len, tag_ptr, routine_len, routine_ptr);
        CACHE_CROAK(rc, "_CachePushRtn");
        break;
    default:
        rflags = 0; /* never get there */
  }
  RETVAL = rflags;
OUTPUT:
  RETVAL

IV
_CachePushFuncX(tag, offset, env, routine)
  SV *tag;
  IV offset;
  SV *env;
  SV *routine;
ALIAS:
        _CachePushRtnX = 1
PREINIT:
  int rc;
  unsigned rflags;
  char *tag_ptr;
  char *env_ptr;
  char *routine_ptr;
  int tag_len;
  int env_len;
  int routine_len;
CODE:
  tag_ptr = SvPV(tag, tag_len);
  env_ptr = SvPV(env, env_len);
  routine_ptr = SvPV(routine, routine_len);
  if(tag_len > CACHE_MAXSTRLEN -1 || env_len > CACHE_MAXSTRLEN -1 || routine_len > CACHE_MAXSTRLEN -1)
      croak("label, environment or routine name way too long.");
  switch(ix) {
    case 0:
        rc = CachePushFuncX(&rflags, tag_len, tag_ptr, (int) offset, env_len, env_ptr, routine_len, routine_ptr);
        CACHE_CROAK(rc, "_CachePushFuncX");
        break;
    case 1:
        rc = CachePushRtnX(&rflags, tag_len, tag_ptr, (int) offset, env_len, env_ptr, routine_len, routine_ptr);
        CACHE_CROAK(rc, "_CachePushRtnX");
        break;
    default:
        rflags = 0; /* notreached */
  }
  RETVAL = rflags;
OUTPUT:
  RETVAL



void
_CacheGlobalSet(i)
  IV i;
ALIAS:
  _CacheGlobalIncrement = 1
  _CacheIncrementCountOref = 2
  _CacheInvokeClassMethod = 3
  _CacheInvokeMethod = 4
PREINIT:
  int rc;
CODE:
        switch(ix) {
          case 0:
            rc = CacheGlobalSet((int) i);
            CACHE_CROAK(rc, "_CacheGlobalSet");
            break;
          case 1:
            rc = CacheGlobalIncrement((int) i);
            CACHE_CROAK(rc, "_CacheGlobalIncement");
            break;
          case 2:
            rc = CacheIncrementCountOref((unsigned) i);
            CACHE_CROAK(rc, "_CacheIncrementCountOref");
            break;
          case 3:
            rc = CacheInvokeClassMethod((unsigned) i);
            CACHE_CROAK(rc, "_CacheInvokeClassMethod");
            break;
          case 4:
            rc = CacheInvokeMethod((unsigned) i);
            CACHE_CROAK(rc, "_CacheInvokeMethod");
            break;

        }
        
SV *
_CacheError()
  PREINIT:
	CACHE_ASTR emsg,sline;
        int i, rc;
CODE:
   	emsg.len = CACHE_MAXSTRLEN-1;
   	sline.len = CACHE_MAXSTRLEN-1;
	if((rc =CacheError(&emsg, &sline, &i)))
  		croak("_CacheError rc = %d", rc);
         RETVAL = newSVpv("Error: ",0);
         sv_catpvn(RETVAL, emsg.str, emsg.len);
         sv_catpv(RETVAL, "\nIn Line: <<<");
         sv_catpvn(RETVAL, sline.str, sline.len);
         sv_catpv(RETVAL, ">>>\nAt offset: ");
         sv_catpvf(RETVAL, "%d", i);
OUTPUT:
	RETVAL
         

void
_CachePushClassMethod(c, m, flag=0)
  SV *c;
  SV *m;
  IV flag;
PREINIT:
  int rc;
  char *cp, *mp;
  int cl, ml;
CODE:
  cp = SvPV(c, cl);
  mp = SvPV(m, ml);
  if(cl > CACHE_MAXSTRLEN -1 || ml > CACHE_MAXSTRLEN -1)
        croak("class or method name far too long.");
  rc = CachePushClassMethod(cl, cp, ml, mp, flag);
  CACHE_CROAK(rc, "_CachePushClassMethod");

MODULE = Cache           PACKAGE = Cache::Routine

PROTOTYPES: ENABLE

void
Do(tag, routine, ...)
  SV *tag;
  SV *routine;
PREINIT:
  int rflags;
  int rc;
  char *tag_ptr, *routine_ptr;
  int tag_len, routine_len;
  int i;
CODE:
  tag_ptr = SvPV(tag, tag_len);
  routine_ptr = SvPV(routine, routine_len);
  if(tag_len > CACHE_MAXSTRLEN -1 || routine_len > CACHE_MAXSTRLEN -1)
    croak("Do: tag or routine name too long");
  rc = CachePushRtn(&rflags, tag_len, tag_ptr, routine_len, routine_ptr);
  CACHE_CROAK(rc, "Do: CachePushRtn");
  for(i = 2; i < items; i++) {
    CacheSVPush(ST(i));
  }
  rc = CacheDoRtn(rflags, items - 2);
  CACHE_CROAK(rc, "Do: CacheDoRtn");

SV *
Call(tag, routine, ...)
  SV *tag;
  SV *routine;
PREINIT:
  int rflags;
  int rc;
  unsigned char *tag_ptr, *routine_ptr, *ptr;
  int tag_len, routine_len, len;
  int i;
CODE:
  tag_ptr = SvPV(tag, tag_len);
  routine_ptr = SvPV(routine, routine_len);
  if(tag_len > CACHE_MAXSTRLEN -1 || routine_len > CACHE_MAXSTRLEN -1)
    croak("Call: tag or routine name too long");
  rc = CachePushFunc(&rflags, tag_len, tag_ptr, routine_len, routine_ptr);
  CACHE_CROAK(rc, "Call: CachePushFunc");
  for(i = 2; i < items; i++) {
    CacheSVPush(ST(i));
  }
  rc = CacheExtFun(rflags, items - 2);
  CACHE_CROAK(rc, "Call: CacheExtFun");
  rc = CachePopStr(&len, &ptr);
  CACHE_CROAK(rc, "Call: CachePopStr");
  RETVAL = newSVpvn(ptr, len);
OUTPUT:
  RETVAL


MODULE = Cache              PACKAGE = Cache::Global

PROTOTYPES: ENABLE

void
Gset(global, ...)
  SV *global
ALIAS:
  Ginc = 1
PREINIT:
    int rc;
    char *ptr;
    int len;
    int i;
CODE:
    if(items < 2)
       croak("Gset: need at least two args");
    ptr = SvPV(global, len);  
    if(len > CACHE_MAXSTRLEN -1)
       croak("Gset: global length way too long");
    rc = CachePushGlobal(len, ptr);
    CACHE_CROAK(rc, "Gset: CachePushGlobal");
    for(i = 1; i < items; i++) {
      CacheSVPush(ST(i));
    }
    rc = (ix ? CacheGlobalIncrement : CacheGlobalSet)(items - 2);
    CACHE_CROAK(rc, "Gset: CacheGlobalSet");

void
GsetA(global, ...)
  SV *global
ALIAS:
  GincA = 1
PREINIT:
    int rc;
    char *ptr;
    int len;
    int i;
    int idx;
    int limit;
    AV *av;
CODE:
    if(items < 2)
       croak("GsetA: need at least two args");
    if(!SvROK(ST(items-1)) || SvTYPE(SvRV(ST(items-1))) != SVt_PVAV)
       croak("GsetA: last argument must be an array reference");
    av = (AV*) SvRV(ST(items-1));
    limit = av_len(av);
    for(idx = 0; idx <= limit; idx++) {
       SV **value = av_fetch(av, idx, 0);
       if(value && SvOK(*value)) {
         ptr = SvPV(global, len);  
         if(len > CACHE_MAXSTRLEN -1)
            croak("GsetA: global length way too long");
         rc = CachePushGlobal(len, ptr);
         CACHE_CROAK(rc, "GsetA: CachePushGlobal");
         for(i = 1; i < items-1; i++) {
             CacheSVPush(ST(i));
         }
         rc = CachePushInt(idx);
         CACHE_CROAK(rc, "GsetA: CachePushInt");
         CacheSVPush(*value);
        rc = (ix ? CacheGlobalIncrement : CacheGlobalSet)(items - 1);
        CACHE_CROAK(rc, "GsetA: CacheGlobalSet");
       }
    }

void
GsetH(global, ...)
  SV *global
ALIAS:
  GincH = 1
PREINIT:
    int rc;
    char *ptr;
    int len;
    int i;
    int idx;
    int count;
    HV *hv;
CODE:
    if(items < 2)
       croak("GsetH: need at least two args");
    if(!SvROK(ST(items-1)) || SvTYPE(SvRV(ST(items-1))) != SVt_PVHV)
       croak("GsetH: last argument must be a hash reference");
    hv = (HV*) SvRV(ST(items-1));
    count = hv_iterinit(hv);
    for(idx = 0; idx < count; idx++) {
       HE *he = hv_iternext(hv);
       SV *key = HeSVKEY_force(he);
       SV *val = HeVAL(he);
       if(SvOK(key) && SvOK(val)) {
         ptr = SvPV(global, len);  
         if(len > CACHE_MAXSTRLEN -1)
            croak("GsetH: global length way too long");
         rc = CachePushGlobal(len, ptr);
         CACHE_CROAK(rc, "GsetH: CachePushGlobal");
         for(i = 1; i < items-1; i++) {
             CacheSVPush(ST(i));
         }
         CacheSVPush(key);
         CacheSVPush(val);
        rc = (ix ? CacheGlobalIncrement : CacheGlobalSet)(items - 1);
        CACHE_CROAK(rc, "GsetH: CacheGlobalSet");
       }
    }
 
IV
Gseq(global, ...)
  SV *global
PREINIT:
  int len;
  char *ptr;
  int i;
  int count;
  int rc;
CODE:
  ptr = SvPV(global, len);
  if(len > CACHE_MAXSTRLEN -1)
    croak("Gseq: global length way too long");
  rc = CachePushGlobal(len, ptr);
  CACHE_CROAK(rc, "Gseq: CachePushGlobal");
  for(i = 1; i < items; i++)
     CacheSVPush(ST(i));
  rc = CachePushInt(1);
  CACHE_CROAK(rc, "Gseq: CachePushInt");
  rc = CacheGlobalIncrement(items - 1);
  CACHE_CROAK(rc, "Gseq: CacheGlobalIncrement");
  rc = CachePopInt(&count);
  CACHE_CROAK(rc, "CachePopInt");
  RETVAL = count;
OUTPUT:
  RETVAL



SV *
Gget(global, ...)       
  SV *global
ALIAS:
  GgetRaise = 1
PREINIT:
  int rc;
  unsigned char *ptr;
  int len = 0;
  int i;
CODE:
  ptr = SvPV(global, len);
  if (len > CACHE_MAXSTRLEN -1)
     croak("Gget: global length too long");
  rc = CachePushGlobal(len, ptr);
  CACHE_CROAK(rc, "Gget: CachePushGlobal");
  for(i = 1; i < items; i++) { 
    CacheSVPush(ST(i));
  }
  rc = CacheGlobalGet(items - 1, 0);
  if(rc == CACHE_ERUNDEF) {
    if(ix) {
      croak("Gget: <UNDEF> referenced global does not exist.");
    } else {
      RETVAL = &PL_sv_undef;
    }
  } else {
    CACHE_CROAK(rc, "Gget: CacheGlobalGet");
    rc = CachePopStr(&len, &ptr);
    CACHE_CROAK(rc, "Gget: CachePopStr");
    RETVAL = newSVpvn(ptr, len);
  }
OUTPUT:
  RETVAL


