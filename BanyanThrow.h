/*
 * BanyanThrow.h
 *
 */

#ifndef __BanyanThrow_h
#define __BanyanThrow_h

#ifdef __BANYAN_DISABLE_THROWS
	#define _bnyn_throw(x) do { printf(x); NodeDef::exc_thrown(true, true); } while (0)
#else
	#define _bnyn_throw(x) throw std::runtime_error(x)
#endif

#endif
