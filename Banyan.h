//
//  Banyan.h
//  Thingumy
//
//  Created by Ben on 23/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#ifndef __Banyan_h
#define __Banyan_h

//#define __BANYAN_DISABLE_THROWS 1

#ifdef __BANYAN_DISABLE_THROWS
	#define _bnyn_throw(x) do { printf(x); NodeDef::exc_thrown(true, true); } while (0)
#else
	#define _bnyn_throw(x) throw std::runtime_error(x)
#endif

#include "BT_Def.h"
#include "BT_Inst.h"

#endif
